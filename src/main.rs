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

#[macro_use]
extern crate rocket;

#[get("/")]
fn index() -> &'static str {
    "Hello, world!"
}

#[launch]
fn rocket() -> _ {
    rocket::build().mount("/", routes![index])
}

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
