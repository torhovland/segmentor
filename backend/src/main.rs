extern crate strava;

use anyhow::{bail, Context, Result};
use axum::{
    extract::{
        ws::{Message, WebSocket},
        Extension, Query, WebSocketUpgrade,
    },
    http::StatusCode,
    response::{IntoResponse, Redirect, Response},
    routing::{get, get_service, post},
    Json, Router,
};
use oauth2::{
    basic::BasicClient, url::ParseError, AuthUrl, ClientId, ClientSecret, CsrfToken, RedirectUrl,
    Scope, TokenUrl,
};
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use sqlx::types::chrono::{DateTime, Utc};
use sqlx::{
    postgres::{PgConnectOptions, PgPoolOptions},
    types::chrono::NaiveDateTime,
};
use std::{
    env,
    net::SocketAddr,
    path::PathBuf,
    sync::Arc,
    time::{SystemTime, UNIX_EPOCH},
};
use tower_cookies::{Cookie, CookieManagerLayer, Cookies};
use tower_http::{
    services::{ServeDir, ServeFile},
    trace::TraceLayer,
};
use tracing::{debug, error, info};
use tracing_subscriber::FmtSubscriber;

struct State {
    environment: Environment,
}

#[derive(Serialize)]
struct SocketError {
    error: String,
}

impl From<SocketError> for String {
    fn from(error: SocketError) -> String {
        serde_json::to_string(&error).unwrap()
    }
}

#[derive(Serialize)]
enum SocketMessage {
    Error(String),
    Foo(String),
}

impl From<SocketMessage> for String {
    fn from(message: SocketMessage) -> String {
        serde_json::to_string(&message).unwrap()
    }
}

#[derive(Debug, Deserialize)]
struct StravaAuth {
    access_token: String,
    athlete: strava::athletes::Athlete,
    expires_at: u32,
    refresh_token: String,
}

#[tokio::main]
async fn main() -> Result<()> {
    let subscriber = FmtSubscriber::builder()
        .with_env_filter("info,segmentor=trace")
        .finish();

    tracing::subscriber::set_global_default(subscriber).expect("setting default subscriber failed");

    let environment = get_environment();
    info!("Running on environment '{:?}'.", environment);

    let shared_state = Arc::new(State { environment });

    let static_path = get_static_path(environment)?;
    let html_file_name = get_html_file_name(environment);

    // build our application with a route
    let app = Router::new()
        .route(
            "/",
            get_service(ServeFile::new(static_path.join(html_file_name))).handle_error(
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
        .route("/sync", get(sync))
        .route("/activities", get(get_activities))
        .layer(Extension(shared_state))
        .layer(CookieManagerLayer::new());

    // run our app with hyper
    // `axum::Server` is a re-export of `hyper::Server`
    let addr = SocketAddr::from(([0, 0, 0, 0], 8088));
    debug!("listening on {}", addr);
    axum::Server::bind(&addr)
        .serve(app.into_make_service())
        .await
        .with_context(|| "Failed to start server.")?;

    Ok(())
}

#[derive(Deserialize)]
struct AuthParams {
    state: String,
    code: String,
    scope: String,
}

#[derive(Deserialize)]
struct Tokens {
    access_token: String,
    refresh_token: String,
}

async fn callback(auth: Query<AuthParams>, cookies: Cookies) -> Result<Redirect, AppError> {
    let _oauth_state = auth.state.as_str();
    let code = auth.code.as_str();
    let _scope = auth.scope.as_str();

    let client = reqwest::Client::new();
    let params = [
        ("client_id", "38457"),
        ("client_secret", "1fb09e3b762ba505e6ff0922c04ab2e0ff8bafb3"),
        ("code", code),
    ];
    debug!("Getting Strava token using {:?}", params);
    let token_result = client
        .post("https://www.strava.com/oauth/token")
        .form(&params)
        .send()
        .await?;

    let text = token_result.text().await?;
    debug!("Strava token result: {}", text);

    let json: StravaAuth = serde_json::from_str(text.as_str())?;

    cookies.add(Cookie::new(
        "segmentor-access-token",
        json.access_token.clone(),
    ));
    cookies.add(Cookie::new("segmentor-refresh-token", json.refresh_token));
    cookies.add(Cookie::new(
        "segmentor-expires-at",
        json.expires_at.to_string(),
    ));
    cookies.add(Cookie::new(
        "segmentor-user-id",
        format!("{}", json.athlete.id),
    ));
    cookies.add(Cookie::new(
        "segmentor-name",
        json.athlete.firstname.unwrap_or_else(|| "unnamed".into()),
    ));

    // format!("{:?}", json)
    Ok(Redirect::permanent("/"))
}

async fn login(Extension(state): Extension<Arc<State>>) -> Result<Redirect, AppError> {
    let (auth_url, _csrf_token) = create_oauth_client(state.environment)
        .authorize_url(CsrfToken::new_random)
        // Set the desired scopes.
        .add_scope(Scope::new("activity:read".to_string()))
        // Set the PKCE code challenge.
        //.set_pkce_challenge(state.pkce_challenge)
        .url();

    Ok(Redirect::permanent(auth_url.as_str()))
}

async fn sync(ws: WebSocketUpgrade) -> impl IntoResponse {
    ws.on_upgrade(sync_socket)
}

async fn sync_socket(mut socket: WebSocket) {
    debug!("Receiving expiration from frontend.");
    let expires_at_string = match receive_message(&mut socket).await {
        Ok(result) => result,
        Err(_) => return,
    };

    debug!("Receiving access token from frontend.");
    let access_token_string = match receive_message(&mut socket).await {
        Ok(result) => result,
        Err(_) => return,
    };

    debug!("Receiving refresh token from frontend.");
    let refresh_token_string = match receive_message(&mut socket).await {
        Ok(result) => result,
        Err(_) => return,
    };

    debug!("Receiving all data from frontend.");

    let expires_at = match expires_at_string
        .parse::<u64>()
        .with_context(|| format!("Strava expiration ('{}') is not UNIX time.", expires_at_string))
    {
        Ok(u) => u,
        Err(err) => {
            send(&mut socket, SocketMessage::Error(err.to_string())).await;
            return;
        }
    };

    let now = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .as_secs();

    if expires_at < (now + 10 * 60) {
        error!("Access token has expired.");
    }

    debug!("Make Strava access token.");
    let access_token = strava::api::AccessToken::new(access_token_string.clone());
    debug!("Loading activities from Strava.");
    let activities = strava::activities::Activity::athlete_activities(&access_token).await;

    match activities {
        Ok(activities) => {
            debug!("Finished loading activities from Strava.");
            save_activities(&activities)
                .await
                .expect("saving activities");
        }
        Err(err) => {
            error!("Failed getting activities from Strava: {:?}", err);
        }
    }

    send(&mut socket, SocketMessage::Foo(access_token_string)).await;
    send(&mut socket, SocketMessage::Foo(refresh_token_string)).await;
}

async fn receive_message(socket: &mut WebSocket) -> Result<String> {
    if let Some(msg) = socket.recv().await {
        if let Ok(msg) = msg {
            match msg {
                Message::Text(t) => {
                    debug!("client send str: {:?}", t);
                    Ok(t)
                }
                _ => {
                    let error = "Unexpected websocket message.";
                    send(socket, SocketMessage::Error(error.to_string())).await;
                    error!(error);
                    bail!(error)
                }
            }
        } else {
            let error = "Client disconnected.";
            error!(error);
            bail!(error)
        }
    } else {
        let error = "Did not receive data from client.";
        error!(error);
        bail!(error)
    }
}

async fn send(socket: &mut WebSocket, message: SocketMessage) {
    let s: String = message.into();
    let msg = Message::Text(s.to_string());
    debug!("Sending to client: {:?}", msg);
    socket
        .send(msg)
        .await
        .with_context(|| "Failed to send WS message.")
        .unwrap_or_else(|err| error!("{}", err));
}

#[derive(sqlx::FromRow, Serialize)]
struct Activity {
    id: u32,
    name: String,
    time: Utc,
}

async fn get_activities() -> Result<Json<Value>> {
    let conn = PgConnectOptions::new()
        .host("/home/tor/projects/segmentor/postgres")
        .database("my_postgres_db")
        .username("postgres_user")
        .password("password");

    let pool = PgPoolOptions::new()
        .max_connections(5)
        .connect_with(conn)
        //.connect("host=/home/tor/projects/segmentor/postgres dbname=foo user=postgres_user")
        .await?;

    let activities: Vec<Activity> = sqlx::query_as::<_, Activity>("SELECT * FROM activities;")
        .fetch_all(&pool)
        .await?;

    Ok(Json(json!(activities)))
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
    OAuthParse(ParseError),
    Reqwest(reqwest::Error),
    Json(serde_json::Error),
    Strava(strava::error::ApiError),
    UnexpectedError(anyhow::Error),
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
        Self::OAuthParse(inner)
    }
}

impl From<anyhow::Error> for AppError {
    fn from(err: anyhow::Error) -> Self {
        Self::UnexpectedError(err)
    }
}

impl From<reqwest::Error> for AppError {
    fn from(err: reqwest::Error) -> Self {
        Self::Reqwest(err)
    }
}

impl From<serde_json::Error> for AppError {
    fn from(err: serde_json::Error) -> Self {
        Self::Json(err)
    }
}

impl From<strava::error::ApiError> for AppError {
    fn from(err: strava::error::ApiError) -> Self {
        Self::Strava(err)
    }
}

impl IntoResponse for AppError {
    fn into_response(self) -> Response {
        let (status, error_message) = match self {
            AppError::OAuthParse(_err) => (
                StatusCode::INTERNAL_SERVER_ERROR,
                "OAuth2 parsing failure".to_string(),
            ),
            AppError::Reqwest(err) => (
                StatusCode::INTERNAL_SERVER_ERROR,
                format!("HTTP request failure: {:?}", err),
            ),
            AppError::Json(err) => (
                StatusCode::INTERNAL_SERVER_ERROR,
                format!("JSON serialization failure: {:?}", err),
            ),
            AppError::Strava(err) => (
                StatusCode::INTERNAL_SERVER_ERROR,
                format!("Strava API failure: {:?}", err),
            ),
            AppError::UnexpectedError(_err) => (
                StatusCode::INTERNAL_SERVER_ERROR,
                "Unexpected error".to_string(),
            ),
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

fn get_html_file_name(environment: Environment) -> &'static str {
    match environment {
        Environment::Development => "index-development.html",
        Environment::Production => "index.html",
        _ => panic!("Undefined environment"),
    }
}

fn get_redirect_url(environment: Environment) -> &'static str {
    match environment {
        Environment::Development => "http://localhost:8088/callback",
        Environment::Production => "https://segmentor.hovland.xyz/callback",
        _ => panic!("Undefined environment"),
    }
}

fn get_static_path(environment: Environment) -> Result<PathBuf> {
    match environment {
        Environment::Development => Ok(env::current_dir()?.join("static")),
        Environment::Production => Ok(PathBuf::from("/static")),
        _ => bail!("Undefined environment"),
    }
}

#[derive(Clone, Copy, Debug)]
enum Environment {
    Development,
    Production,
    Undefined,
}

async fn save_activities(activities: &[strava::activities::Activity]) -> Result<()> {
    let conn = PgConnectOptions::new()
        .host("/home/tor/projects/segmentor/postgres")
        .database("my_postgres_db")
        .username("postgres_user")
        .password("password");

    let pool = PgPoolOptions::new()
        .max_connections(5)
        .connect_with(conn)
        //.connect("host=/home/tor/projects/segmentor/postgres dbname=foo user=postgres_user")
        .await?;

    for activity in activities {
        debug!(
            "Saving activity {} - {}: {}",
            activity.id,
            activity.start_date_local.replace("Z", ""),
            activity.name
        );

        let date = DateTime::<Utc>::from_utc(
            NaiveDateTime::parse_from_str(&activity.start_date_local.replace("Z", ""), "%FT%T")?,
            Utc,
        );

        sqlx::query("INSERT INTO activities (id, name, time) VALUES ($1, $2, $3);")
            .bind(activity.id)
            .bind(&activity.name)
            .bind(&date)
            .execute(&pool)
            .await?;
    }

    Ok(())
}
