// Copyright 2023 the Deno authors. All rights reserved. MIT license.
import { MiddlewareHandlerContext } from "$fresh/server.ts";
import { walk } from "$std/fs/walk.ts";
import { getAccessTokenCookie, getSessionId } from "@/utils/deno_kv_oauth.ts";

export interface State {
  sessionId?: string;
  accessToken?: string;
}

const STATIC_DIR_ROOT = new URL("../static", import.meta.url);
const staticFileNames: string[] = [];
for await (const { name } of walk(STATIC_DIR_ROOT, { includeDirs: false })) {
  staticFileNames.push(name);
}

export async function handler(
  req: Request,
  ctx: MiddlewareHandlerContext<State>,
) {
  const { pathname } = new URL(req.url);
  // Don't process session-related data for keepalive and static requests
  if (["_frsh", ...staticFileNames].some((part) => pathname.includes(part))) {
    return await ctx.next();
  }

  ctx.state.sessionId = getSessionId(req.headers);
  ctx.state.accessToken = await getAccessTokenCookie(req.headers);

  return await ctx.next();
}
