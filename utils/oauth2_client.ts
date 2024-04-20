import { OAuth2Client } from "oauth2_client/mod.ts";

export const oauth2Client = new OAuth2Client({
  clientId: Deno.env.get("STRAVA_CLIENT_ID")!,
  clientSecret: Deno.env.get("STRAVA_CLIENT_SECRET")!,
  redirectUri: "http://localhost:8000/callback",
  authorizationEndpointUri: "https://www.strava.com/oauth/authorize",
  tokenUri: "https://www.strava.com/oauth/token",
  defaults: {
    scope: "activity:read_all",
  },
});
