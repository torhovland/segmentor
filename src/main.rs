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
    http::StatusCode,
    response::IntoResponse,
    routing::{get, get_service, post},
    Json, Router,
};
use serde::{Deserialize, Serialize};
use std::net::SocketAddr;
use tower_http::{
    services::{ServeDir, ServeFile},
    trace::TraceLayer,
};

#[tokio::main]
async fn main() {
    // initialize tracing
    tracing_subscriber::fmt::init();

    // build our application with a route
    let app = Router::new()
        .route(
            "/",
            get_service(ServeFile::new("index.html")).handle_error(
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
            get_service(ServeDir::new("static")).handle_error(|error: std::io::Error| async move {
                (
                    StatusCode::INTERNAL_SERVER_ERROR,
                    format!("Unhandled internal error: {}", error),
                )
            }),
        )
        .layer(TraceLayer::new_for_http())
        // `GET /` goes to `root`
        .route("/foo", get(root))
        // `POST /users` goes to `create_user`
        .route("/users", post(create_user));

    // run our app with hyper
    // `axum::Server` is a re-export of `hyper::Server`
    let addr = SocketAddr::from(([127, 0, 0, 1], 3000));
    tracing::debug!("listening on {}", addr);
    axum::Server::bind(&addr)
        .serve(app.into_make_service())
        .await
        .unwrap();
}

// basic handler that responds with a static string
async fn root() -> &'static str {
    "Hello, World!"
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
