export function createBuildHandler({
  projectUrl,
  publicKey,
  hookUrl,
  portalOrigin,
  fetchImpl = fetch,
}) {
  return async (request) => {
    const origin = request.headers.get("Origin");
    const allowed = origin && origin === portalOrigin;
    const headers = {
      "Content-Type": "application/json",
      "Cache-Control": "no-store",
      ...(allowed
        ? {
            "Access-Control-Allow-Origin": origin,
            Vary: "Origin",
            "Access-Control-Allow-Headers":
              "authorization, apikey, x-client-info, content-type, x-supabase-client-platform, x-supabase-client-platform-version, x-supabase-client-runtime, x-supabase-client-runtime-version",
            "Access-Control-Allow-Methods": "POST, OPTIONS",
          }
        : {}),
    };
    const reply = (status, message) =>
      new Response(JSON.stringify({ message }), { status, headers });
    if (origin && !allowed) return reply(403, "Origin not allowed");
    if (request.method === "OPTIONS")
      return new Response(null, { status: 204, headers });
    if (request.method !== "POST") return reply(405, "Method not allowed");
    if (!projectUrl || !publicKey || !hookUrl || !portalOrigin)
      return reply(503, "Website build trigger is not configured");
    // The secret must be a Netlify hook, not an arbitrary server-side URL.
    try {
      const url = new URL(hookUrl);
      if (
        url.protocol !== "https:" ||
        url.hostname !== "api.netlify.com" ||
        !url.pathname.startsWith("/build_hooks/")
      )
        return reply(503, "Website build trigger is not configured");
    } catch {
      return reply(503, "Website build trigger is not configured");
    }
    const authorization = request.headers.get("Authorization");
    if (!/^Bearer\s+\S+$/i.test(authorization ?? ""))
      return reply(401, "Please sign in");
    try {
      const authHeaders = {
        apikey: publicKey,
        Authorization: authorization,
        "Content-Type": "application/json",
      };
      const user = await fetchImpl(`${projectUrl}/auth/v1/user`, {
        headers: authHeaders,
        signal: AbortSignal.timeout(10000),
      });
      if (!user.ok) return reply(401, "Session expired. Please sign in");
      const identity = await user.json();
      if (!identity.id) return reply(401, "Please sign in");
      const admin = await fetchImpl(`${projectUrl}/rest/v1/rpc/cms_admin_me`, {
        method: "POST",
        headers: authHeaders,
        body: "{}",
        signal: AbortSignal.timeout(10000),
      });
      if (!admin.ok) return reply(403, "Administrator access required");
      const build = await fetchImpl(hookUrl, {
        method: "POST",
        signal: AbortSignal.timeout(15000),
        redirect: "error",
      });
      if (!build.ok)
        return reply(
          502,
          "Netlify did not accept the build request. Retry the website build.",
        );
      return reply(
        202,
        "Website rebuild requested. Changes go live after a successful deployment.",
      );
    } catch {
      // Do not log or return errors containing the private Netlify hook URL.
      return reply(
        502,
        "Could not request the website build. Retry the website build.",
      );
    }
  };
}
