extern crate strava;

// use anyhow::{Context, Result};
// use oauth2::basic::BasicClient;
// use oauth2::reqwest::async_http_client;
// use oauth2::{AuthUrl, ClientId, ClientSecret, Scope, TokenUrl};
// use std::path::Path;
// use std::{env, fs};
// use strava::activities::Activity;
// use strava::api::AccessToken;
// use strava::athletes::Athlete;

// #[macro_use]
// extern crate rocket;

// #[get("/")]
// fn index() -> &'static str {
//     "Hello, world!"
// }

// #[launch]
// fn rocket() -> _ {
//     rocket::build().mount("/", routes![index])
// }

// #[tokio::main]
// async fn main() -> Result<()> {
//     let client = BasicClient::new(
//         ClientId::new("38457".to_string()),
//         Some(ClientSecret::new(
//             "1fb09e3b762ba505e6ff0922c04ab2e0ff8bafb3".to_string(),
//         )),
//         AuthUrl::new("http://authorize".to_string())?,
//         Some(TokenUrl::new(
//             "https://www.strava.com/oauth/token".to_string(),
//         )?),
//     );

//     let _token_result = client
//         .exchange_client_credentials()
//         .add_scope(Scope::new("read".to_string()))
//         .request_async(async_http_client)
//         .await
//         .with_context(|| "Failed to get access token from Strava.")?;

//     let token = read_token().with_context(|| "Failed to read Strava access token.")?;

//     let athlete = Athlete::get_current(&token)
//         .await
//         .with_context(|| "Failed to get athlete from Strava.")?;

//     println!("{:?}", athlete);

//     let activities = Activity::athlete_activities(&token)
//         .await
//         .with_context(|| "Failed to get activities from Strava.")?;

//     println!("{:?}", activities);

//     Ok(())
// }

// fn read_token() -> Result<AccessToken> {
//     Ok(AccessToken::new(
//         fs::read_to_string(
//             Path::new(&env::var("HOME")?)
//                 .join(".segmentor")
//                 .join("access-token"),
//         )?
//         .trim()
//         .to_string(),
//     ))
// }

use axum::{
    extract::{Extension, Query},
    http::{Request, StatusCode},
    response::{IntoResponse, Redirect, Response},
    routing::{get, get_service, post},
    Json, Router,
};
use oauth2::{
    basic::BasicClient, reqwest::async_http_client, url::ParseError, AuthUrl, AuthorizationCode,
    Client, ClientId, ClientSecret, CsrfToken, PkceCodeChallenge, PkceCodeVerifier, RedirectUrl,
    Scope, TokenUrl,
};
use serde::{Deserialize, Serialize};
use serde_json::json;
use std::{env, net::SocketAddr, sync::Arc};
use strava::athletes::Athlete;
use tower_cookies::{Cookie, CookieManagerLayer, Cookies};
use tower_http::{
    services::{ServeDir, ServeFile},
    trace::TraceLayer,
};
use tracing::{debug, Level};
use tracing_subscriber::{EnvFilter, FmtSubscriber};

struct State {
    environment: Environment,
}

#[derive(Debug, Deserialize)]
struct StravaAuth {
    access_token: String,
    athlete: Athlete,
    expires_at: usize,
    refresh_token: String,
}

#[tokio::main]
async fn main() {
    // initialize tracing
    let subscriber = FmtSubscriber::builder()
        // all spans/events with a level higher than TRACE (e.g, debug, info, warn, etc.)
        // will be written to stdout.
        .with_max_level(Level::TRACE)
        // completes the builder.
        .finish();

    tracing::subscriber::set_global_default(subscriber).expect("setting default subscriber failed");

    let environment = get_environment();

    let (pkce_challenge, pkce_verifier) = PkceCodeChallenge::new_random_sha256();
    let shared_state = Arc::new(State { environment });

    let static_path = get_static_path(environment);

    // build our application with a route
    let app = Router::new()
        .route(
            "/",
            get_service(ServeFile::new(format!("{static_path}index.html"))).handle_error(
                |error: std::io::Error| async move {
                    (
                        StatusCode::INTERNAL_SERVER_ERROR,
                        format!("Unhandled internal error: {}", error),
                    )
                },
            ),
        )
        .layer(TraceLayer::new_for_http())
        .nest(
            "/static",
            get_service(ServeDir::new(static_path)).handle_error(
                |error: std::io::Error| async move {
                    (
                        StatusCode::INTERNAL_SERVER_ERROR,
                        format!("Unhandled internal error: {}", error),
                    )
                },
            ),
        )
        .layer(TraceLayer::new_for_http())
        .route("/callback", get(callback))
        .route("/login", get(login))
        .route("/users", post(create_user))
        .layer(Extension(shared_state))
        .layer(CookieManagerLayer::new());

    // run our app with hyper
    // `axum::Server` is a re-export of `hyper::Server`
    let addr = SocketAddr::from(([0, 0, 0, 0], 8088));
    debug!("listening on {}", addr);
    axum::Server::bind(&addr)
        .serve(app.into_make_service())
        .await
        .unwrap();
}

#[derive(Deserialize)]
struct AuthParams {
    state: String,
    code: String,
    scope: String,
}

async fn callback(
    Extension(state): Extension<Arc<State>>,
    auth: Query<AuthParams>,
    cookies: Cookies,
) -> String {
    let oauth_state = auth.state.as_str();
    let code = auth.code.as_str();
    let scope = auth.scope.as_str();

    let client = reqwest::Client::new();
    let params = [
        ("client_id", "38457"),
        ("client_secret", "1fb09e3b762ba505e6ff0922c04ab2e0ff8bafb3"),
        ("code", code),
    ];
    let token_result = client
        .post("https://www.strava.com/oauth/token")
        .form(&params)
        .send()
        .await;

    // let token_result = create_oauth_client(state.environment)
    //     .exchange_code(AuthorizationCode::new(auth.code.clone()))
    //     // Set the PKCE code verifier.
    //     //.set_pkce_verifier(state.clone().pkce_verifier)
    //     .request_async(async_http_client)
    //     .await;

    match token_result {
        Ok(response) => {
            // let body = response.json::<StravaAuth>().await.unwrap();
            let data = response.json::<StravaAuth>().await;

            match data {
                Ok(json) => {
                    cookies.add(Cookie::new(
                        "segmentor-access-token",
                        json.access_token.clone(),
                    ));
                    cookies.add(Cookie::new(
                        "segmentor-refresh-token",
                        json.refresh_token.clone(),
                    ));
                    format!("{:?}", json)
                }
                Err(error) => {
                    format!("{:?}", error)
                }
            }
        }
        Err(error) => format!("{:?}", error),
    }
}

async fn login(Extension(state): Extension<Arc<State>>) -> Result<Redirect, AppError> {
    let (auth_url, csrf_token) = create_oauth_client(state.environment)
        .authorize_url(CsrfToken::new_random)
        // Set the desired scopes.
        .add_scope(Scope::new("read".to_string()))
        // Set the PKCE code challenge.
        //.set_pkce_challenge(state.pkce_challenge)
        .url();

    Ok(Redirect::permanent(to_axum_url(auth_url)))
}

fn to_axum_url(url: oauth2::url::Url) -> axum::http::Uri {
    url.to_string().parse().unwrap()
}

async fn create_user(
    // this argument tells axum to parse the request body
    // as JSON into a `CreateUser` type
    Json(payload): Json<CreateUser>,
) -> impl IntoResponse {
    // insert your application logic here
    let user = User {
        id: 1337,
        username: payload.username,
    };

    // this will be converted into a JSON response
    // with a status code of `201 Created`
    (StatusCode::CREATED, Json(user))
}

// the input to our `create_user` handler
#[derive(Deserialize)]
struct CreateUser {
    username: String,
}

// the output to our `create_user` handler
#[derive(Serialize)]
struct User {
    id: u64,
    username: String,
}

enum AppError {
    /// Something went wrong when calling the user repo.
    UserRepo(UserRepoError),
    OAuthParse(ParseError),
}

#[derive(Debug)]
enum UserRepoError {
    #[allow(dead_code)]
    NotFound,
    #[allow(dead_code)]
    InvalidUsername,
}

impl From<ParseError> for AppError {
    fn from(inner: ParseError) -> Self {
        AppError::OAuthParse(inner)
    }
}

impl IntoResponse for AppError {
    fn into_response(self) -> Response {
        let (status, error_message) = match self {
            AppError::UserRepo(UserRepoError::NotFound) => {
                (StatusCode::NOT_FOUND, "User not found")
            }
            AppError::UserRepo(UserRepoError::InvalidUsername) => {
                (StatusCode::UNPROCESSABLE_ENTITY, "Invalid username")
            }
            AppError::OAuthParse(err) => {
                (StatusCode::INTERNAL_SERVER_ERROR, "OAuth2 parsing failure")
            }
        };

        let body = Json(json!({
            "error": error_message,
        }));

        (status, body).into_response()
    }
}

fn get_environment() -> Environment {
    match env::var("ENVIRONMENT")
        .unwrap_or_else(|_| "".into())
        .as_str()
    {
        "development" => Environment::Development,
        "production" => Environment::Production,
        _ => Environment::Undefined,
    }
}

fn create_oauth_client(environment: Environment) -> BasicClient {
    BasicClient::new(
        ClientId::new("38457".to_string()),
        Some(ClientSecret::new(
            "1fb09e3b762ba505e6ff0922c04ab2e0ff8bafb3".to_string(),
        )),
        AuthUrl::new("https://www.strava.com/oauth/authorize".to_string()).unwrap(),
        Some(TokenUrl::new("https://www.strava.com/oauth/token".to_string()).unwrap()),
    )
    .set_redirect_uri(RedirectUrl::new(get_redirect_url(environment).to_string()).unwrap())
}

fn get_redirect_url(environment: Environment) -> &'static str {
    match environment {
        Environment::Development => "http://localhost:8088/callback",
        Environment::Production => "https://segmentor.hovland.xyz/callback",
        _ => panic!("Undefined environment"),
    }
}

fn get_static_path(environment: Environment) -> &'static str {
    match environment {
        Environment::Development => "/workspaces/segmentor/static/",
        Environment::Production => "/usr/src/segmentor/static/",
        _ => panic!("Undefined environment"),
    }
}

#[derive(Clone, Copy)]
enum Environment {
    Development,
    Production,
    Undefined,
}
