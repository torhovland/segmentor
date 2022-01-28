extern crate strava;

use strava::athletes::Athlete;
use strava::api::AccessToken;

#[tokio::main]
async fn main() {
    let token = AccessToken::new("<my token>".to_string());

    // Get the athlete associated with the given token
    let athlete = Athlete::get_current(&token).await.unwrap();

    // All of the strava types implement Debug and can be printed like so:
    println!("{:?}", athlete);
}
