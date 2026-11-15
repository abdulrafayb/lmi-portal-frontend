import { test } from "node:test";
import assert from "node:assert/strict";
import { createBuildHandler } from "../supabase/functions/request-website-build/handler.mjs";
const config = {
  projectUrl: "https://project.supabase.co",
  publicKey: "public-key",
  hookUrl: "https://api.netlify.com/build_hooks/private-hook",
  portalOrigin: "https://portal.example",
};
const req = (auth = "Bearer user-token", origin = config.portalOrigin) =>
  new Request(
    "https://project.supabase.co/functions/v1/request-website-build",
    {
      method: "POST",
      headers: { ...(auth ? { Authorization: auth } : {}), Origin: origin },
    },
  );
test("missing authentication and untrusted origins cannot trigger a build", async () => {
  let calls = 0;
  const handler = createBuildHandler({
    ...config,
    fetchImpl: async () => {
      calls++;
      throw new Error("Must not fetch");
    },
  });
  assert.equal((await handler(req(null))).status, 401);
  assert.equal(
    (await handler(req("Bearer user-token", "https://other.example"))).status,
    403,
  );
  assert.equal(calls, 0);
});
test("a valid Supabase login alone is not sufficient: admin membership is required", async () => {
  const calls = [];
  const handler = createBuildHandler({
    ...config,
    fetchImpl: async (url) => {
      calls.push(url);
      return url.endsWith("/user")
        ? Response.json({ id: "user-id" })
        : new Response("", { status: 403 });
    },
  });
  assert.equal((await handler(req())).status, 403);
  assert.equal(calls.length, 2);
  assert.ok(!calls.includes(config.hookUrl));
});
test("authorized admins request a build without receiving the hook URL", async () => {
  const calls = [];
  const handler = createBuildHandler({
    ...config,
    fetchImpl: async (url, options) => {
      calls.push({ url, options });
      return Response.json(url.endsWith("/user") ? { id: "admin-id" } : {});
    },
  });
  const response = await handler(req());
  assert.equal(response.status, 202);
  assert.equal(calls[2].url, config.hookUrl);
  assert.equal(calls[2].options.method, "POST");
  assert.ok(!(await response.text()).includes(config.hookUrl));
});
test("hook failures and missing configuration are reported without leaking secrets", async () => {
  const handler = createBuildHandler({
    ...config,
    fetchImpl: async (url) => {
      if (url === config.hookUrl) throw new Error(config.hookUrl);
      return Response.json({ id: "admin-id" });
    },
  });
  const response = await handler(req());
  assert.equal(response.status, 502);
  assert.ok(!(await response.text()).includes(config.hookUrl));
  assert.equal(
    (await createBuildHandler({ ...config, hookUrl: "" })(req())).status,
    503,
  );
});
