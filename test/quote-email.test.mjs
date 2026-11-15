import { test } from "node:test";
import assert from "node:assert/strict";
import { createQuoteHandler } from "../supabase/functions/send-quote/handler.mjs";
const origin = "https://lmi.example";
const payload = {
  name: "Ali Ahmed",
  company: "Example Ltd",
  email: "ali@example.com",
  phone: "+92 300 1234567",
  service: "Dry Cargo",
  origin: "Karachi",
  destination: "Lahore",
  details: "10 pallets\nDeliver next week",
  website: "",
  captchaToken: "valid-challenge",
  requestId: "11111111-1111-4111-8111-111111111111",
  submittedAt: "2026-11-16T10:00:00.000Z",
};
function setup({
  verify = { success: true, hostname: "lmi.example", action: "quote" },
  quota = true,
  deliveryStatus = 200,
  deliveryBody = { id: "email-123" },
  ...overrides
} = {}) {
  const calls = [];
  const handler = createQuoteHandler({
    projectUrl: "https://project.supabase.co",
    serviceKey: "secret-service-key",
    resendKey: "secret-resend-key",
    fromEmail: "LMI Website <website@notifications.lmipk.com>",
    websiteOrigins: origin,
    turnstileSecret: "secret-turnstile-key",
    now: () => new Date("2026-11-16T10:01:00Z"),
    fetchImpl: async (url, options) => {
      calls.push({ url, options });
      if (url.includes("siteverify")) return Response.json(verify);
      if (url.includes("quote_consume_limit")) return Response.json(quota);
      return Response.json(deliveryBody, { status: deliveryStatus });
    },
    ...overrides,
  });
  return { handler, calls };
}
const request = (body = payload, options = {}) =>
  new Request("https://project.supabase.co/functions/v1/send-quote", {
    method: "POST",
    headers: {
      Origin: origin,
      "Content-Type": "application/json",
      "x-forwarded-for": "203.0.113.10",
      ...options.headers,
    },
    body: JSON.stringify(body),
    ...options,
  });
test("public quote endpoint denies untrusted origins, methods and missing configuration", async () => {
  const { handler, calls } = setup();
  assert.equal(
    (
      await handler(
        request(payload, {
          headers: {
            Origin: "https://evil.example",
            "Content-Type": "application/json",
          },
        }),
      )
    ).status,
    403,
  );
  assert.equal(
    (
      await handler(
        new Request("https://x.example", {
          method: "OPTIONS",
          headers: { Origin: origin },
        }),
      )
    ).status,
    204,
  );
  assert.equal(
    (
      await handler(
        new Request("https://x.example", { headers: { Origin: origin } }),
      )
    ).status,
    405,
  );
  assert.equal((await setup({ resendKey: "" }).handler(request())).status, 503);
  assert.equal(calls.length, 0);
});
test("server validates fields, lengths, header injection and honeypot before calling providers", async () => {
  for (const changed of [
    { website: "bot" },
    { name: "" },
    { phone: "12" },
    { email: "ali@example.com\r\nBcc:evil@example.com" },
    { company: 5 },
    { details: "x".repeat(5001) },
    { service: "cargo\nInjected" },
    { captchaToken: "" },
    { requestId: "nope" },
    { submittedAt: "not-a-date" },
  ]) {
    const { handler, calls } = setup();
    assert.equal(
      (await handler(request({ ...payload, ...changed }))).status,
      400,
    );
    assert.equal(calls.length, 0);
  }
  const { handler } = setup();
  const res = await handler(
    new Request("https://x.example", {
      method: "POST",
      headers: { Origin: origin, "Content-Type": "application/json" },
      body: "x".repeat(16001),
    }),
  );
  assert.equal(res.status, 413);
});
test("Turnstile must validate the exact website hostname and action", async () => {
  for (const verify of [
    { success: false },
    { success: true, hostname: "evil.example", action: "quote" },
    { success: true, hostname: "lmi.example", action: "login" },
  ]) {
    const { handler, calls } = setup({ verify });
    assert.equal((await handler(request())).status, 400);
    assert.equal(calls.length, 1);
  }
});
test("shared quota failure never sends an email", async () => {
  const { handler, calls } = setup({ quota: false });
  assert.equal((await handler(request())).status, 429);
  assert.equal(calls.length, 2);
});
test("sends escaped HTML and plain text only to LMI, with customer Reply-To and deterministic retry payload", async () => {
  const { handler, calls } = setup();
  const values = {
    ...payload,
    name: "Ali <b>Ahmed</b>",
    details: "<script>alert(1)</script>\nCargo & freight",
    to: "attacker@example.com",
    from: "attacker@example.com",
  };
  for (let i = 0; i < 2; i++) {
    const res = await handler(request(values));
    assert.equal(res.status, 200);
    assert.equal((await res.json()).reference, payload.requestId);
    assert.equal(res.headers.get("Access-Control-Allow-Origin"), origin);
  }
  const emails = calls.filter((c) => c.url === "https://api.resend.com/emails");
  const email = JSON.parse(emails[0].options.body);
  assert.deepEqual(email.to, ["info@lmipk.com"]);
  assert.equal(email.reply_to, payload.email);
  assert.equal(email.from, "LMI Website <website@notifications.lmipk.com>");
  assert.ok(email.html.includes("&lt;script&gt;"));
  assert.ok(!email.html.includes("<script>"));
  assert.ok(email.text.includes(values.details));
  assert.ok(email.html.includes("PKT"));
  assert.equal(emails[0].options.body, emails[1].options.body);
  assert.equal(
    emails[0].options.headers["Idempotency-Key"],
    `quote-${payload.requestId}`,
  );
  const quota = JSON.parse(
    calls.find((c) => c.url.includes("quote_consume_limit")).options.body,
  );
  assert.match(quota.p_ip_hash, /^[a-f0-9]{64}$/);
  assert.ok(!JSON.stringify(quota).includes("203.0.113.10"));
});
test("provider rejection, missing acknowledgement and network errors do not report success or leak secrets", async () => {
  for (const config of [
    { deliveryStatus: 429, deliveryBody: { error: "secret-resend-key" } },
    { deliveryBody: {} },
    {
      fetchImpl: async () => {
        throw new Error("secret-service-key");
      },
    },
  ]) {
    const { handler } = setup(config);
    const res = await handler(request());
    assert.ok(res.status >= 500);
    assert.ok(!(await res.text()).includes("secret-"));
  }
});
