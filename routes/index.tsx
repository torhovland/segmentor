import type { Handlers, PageProps } from "$fresh/server.ts";
import { oauth2Client } from "@/utils/oauth2_client.ts";
import { redirectToOAuthLogin } from "@/utils/deno_kv_oauth.ts";
import type { State } from "./_middleware.ts";

interface Data {
  name: string;
}

export const handler: Handlers<any, State> = {
  async GET(_req, ctx) {
    if (!ctx.state.sessionId) {
      return redirectToOAuthLogin(oauth2Client);
    }

    const userResponse = await fetch("https://www.strava.com/api/v3/athlete", {
      headers: {
        Authorization: `Bearer ${ctx.state.accessToken}`,
      },
    });
    const { firstname } = await userResponse.json();

    return await ctx.render({ name: firstname });
  },
};

export default function Page({ data }: PageProps<Data>) {
  const { name } = data;

  return (
    <main>
      <h1>Segmentor</h1>
      <p>Hello, {name}!</p>
    </main>
  );
}
