// Copyright 2023 the Deno authors. All rights reserved. MIT license.
import type { Handlers } from "$fresh/server.ts";
import { redirect } from "@/utils/http.ts";
import { State } from "./_middleware.ts";
import { getAccessToken, setCallbackHeaders } from "@/utils/deno_kv_oauth.ts";
import { oauth2Client } from "@/utils/oauth2_client.ts";

export const handler: Handlers<any, State> = {
  async GET(req) {
    const accessToken = await getAccessToken(req, oauth2Client);
    const sessionId = crypto.randomUUID();

    const response = redirect("/");
    setCallbackHeaders(response.headers, sessionId, accessToken);
    return response;
  },
};
