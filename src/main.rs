extern crate strava;

use anyhow::{Context, Result};
use std::path::Path;
use std::{env, fs};

use strava::api::AccessToken;
use strava::athletes::Athlete;

#[tokio::main]
async fn main() -> Result<()> {
    let token = read_token().with_context(|| "Failed to read Strava access token.")?;

    let athlete = Athlete::get_current(&token)
        .await
        .with_context(|| "Failed to get athlete data from Strava.")?;

    println!("{:?}", athlete);

    Ok(())
}

fn read_token() -> Result<AccessToken> {
    Ok(AccessToken::new(
        fs::read_to_string(
            Path::new(&env::var("HOME")?)
                .join(".segmentor")
                .join("access-token"),
        )?
        .trim()
        .to_string(),
    ))
}
