import { quoteEmail } from "./template.mjs";
const limits = {
  name: 100,
  company: 160,
  email: 254,
  phone: 40,
  service: 120,
  origin: 160,
  destination: 160,
  details: 5000,
};
const required = [
  "name",
  "email",
  "phone",
  "service",
  "origin",
  "destination",
  "details",
];
export function createQuoteHandler({
  projectUrl,
  serviceKey,
  resendKey,
  fromEmail,
  websiteOrigins = "",
  turnstileSecret,
  fetchImpl = fetch,
  now = () => new Date(),
}) {
  const origins = websiteOrigins
    .split(",")
    .map((s) => s.trim())
    .filter(Boolean);
  return async (request) => {
    const origin = request.headers.get("Origin");
    const allowed = origins.includes(origin);
    const headers = {
      "Content-Type": "application/json",
      "Cache-Control": "no-store",
      Vary: "Origin",
      ...(allowed
        ? {
            "Access-Control-Allow-Origin": origin,
            "Access-Control-Allow-Methods": "POST, OPTIONS",
            "Access-Control-Allow-Headers": "content-type",
          }
        : {}),
    };
    const reply = (status, message, extra = {}) =>
      new Response(JSON.stringify({ message, ...extra }), { status, headers });
    if (!allowed) return reply(403, "Origin not allowed");
    if (request.method === "OPTIONS")
      return new Response(null, { status: 204, headers });
    if (request.method !== "POST") return reply(405, "Method not allowed");
    if (
      !projectUrl ||
      !serviceKey ||
      !resendKey ||
      !fromEmail ||
      !turnstileSecret
    )
      return reply(
        503,
        "The quote form is not configured. Please email info@lmipk.com.",
      );
    try {
      if (
        !(request.headers.get("Content-Type") || "").startsWith(
          "application/json",
        )
      )
        return reply(415, "Please send JSON.");
      if (Number(request.headers.get("Content-Length")) > 16000)
        return reply(413, "Your message is too long.");
      // Read a bounded stream so absent/forged Content-Length cannot bypass the limit.
      const reader = request.body?.getReader();
      if (!reader) return reply(400, "Please complete the form.");
      let size = 0;
      const chunks = [];
      while (true) {
        const { done, value } = await reader.read();
        if (done) break;
        size += value.byteLength;
        if (size > 16000) {
          await reader.cancel();
          return reply(413, "Your message is too long.");
        }
        chunks.push(value);
      }
      const buffer = new Uint8Array(size);
      let offset = 0;
      for (const chunk of chunks) {
        buffer.set(chunk, offset);
        offset += chunk.length;
      }
      let payload;
      try {
        payload = JSON.parse(new TextDecoder().decode(buffer));
      } catch {
        return reply(400, "Invalid form submission.");
      }
      if (!payload || typeof payload !== "object" || Array.isArray(payload))
        return reply(400, "Invalid form submission.");
      if (payload.website) return reply(400, "Unable to submit this request.");
      const values = {};
      for (const [key, max] of Object.entries(limits)) {
        if (payload[key] != null && typeof payload[key] !== "string")
          return reply(400, "Invalid form fields.");
        values[key] = (payload[key] || "").trim();
        if (
          values[key].length > max ||
          (key !== "details" && /[\r\n\x00-\x1f]/.test(values[key]))
        )
          return reply(400, "Please check your form fields.");
      }
      if (
        required.some((key) => !values[key]) ||
        !/^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9.-]*[a-zA-Z0-9])?\.[a-zA-Z]{2,}$/.test(
          values.email,
        ) ||
        values.phone.replace(/\D/g, "").length < 7
      )
        return reply(
          400,
          "Please provide a valid name, email, phone and requirement details.",
        );
      if (
        typeof payload.requestId !== "string" ||
        !/^[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$/i.test(
          payload.requestId,
        )
      )
        return reply(
          400,
          "Invalid submission reference. Please reload the page.",
        );
      if (
        typeof payload.captchaToken !== "string" ||
        !payload.captchaToken ||
        payload.captchaToken.length > 2048
      )
        return reply(400, "Please complete the security check.");
      const submittedAt = new Date(payload.submittedAt);
      if (
        typeof payload.submittedAt !== "string" ||
        !Number.isFinite(submittedAt.getTime()) ||
        submittedAt.getTime() > now().getTime() + 300000 ||
        submittedAt.getTime() < now().getTime() - 86400000
      )
        return reply(400, "Please refresh the form and try again.");
      const verification = await fetchImpl(
        "https://challenges.cloudflare.com/turnstile/v0/siteverify",
        {
          method: "POST",
          body: new URLSearchParams({
            secret: turnstileSecret,
            response: payload.captchaToken,
          }),
          signal: AbortSignal.timeout(10000),
        },
      );
      if (!verification.ok)
        return reply(
          503,
          "Security verification is temporarily unavailable. Please try again.",
        );
      const challenge = await verification.json();
      if (
        !challenge.success ||
        challenge.action !== "quote" ||
        challenge.hostname !== new URL(origin).hostname
      )
        return reply(
          400,
          "Security check expired or failed. Please try again.",
        );
      // Only trust the platform-provided client address; never accept it in the payload.
      const ip =
        request.headers.get("x-forwarded-for")?.split(",")[0].trim() ||
        "unknown";
      const hmac = await crypto.subtle.importKey(
        "raw",
        new TextEncoder().encode(serviceKey),
        { name: "HMAC", hash: "SHA-256" },
        false,
        ["sign"],
      );
      const ipHash = [
        ...new Uint8Array(
          await crypto.subtle.sign("HMAC", hmac, new TextEncoder().encode(ip)),
        ),
      ]
        .map((b) => b.toString(16).padStart(2, "0"))
        .join("");
      const quota = await fetchImpl(
        `${projectUrl}/rest/v1/rpc/quote_consume_limit`,
        {
          method: "POST",
          headers: {
            apikey: serviceKey,
            Authorization: `Bearer ${serviceKey}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({ p_ip_hash: ipHash }),
          signal: AbortSignal.timeout(10000),
        },
      );
      if (!quota.ok)
        return reply(
          503,
          "Unable to submit right now. Please try again or email info@lmipk.com.",
        );
      if ((await quota.json()) !== true)
        return reply(
          429,
          "Too many requests. Please try again later or email info@lmipk.com.",
        );
      const email = quoteEmail(values, payload.requestId, submittedAt);
      const delivery = await fetchImpl("https://api.resend.com/emails", {
        method: "POST",
        headers: {
          Authorization: `Bearer ${resendKey}`,
          "Content-Type": "application/json",
          "Idempotency-Key": `quote-${payload.requestId}`,
        },
        body: JSON.stringify({
          from: fromEmail,
          to: ["info@lmipk.com"],
          reply_to: values.email,
          ...email,
        }),
        signal: AbortSignal.timeout(15000),
      });
      if (!delivery.ok)
        return reply(
          502,
          "Your request could not be submitted. Please try again or email info@lmipk.com.",
        );
      const result = await delivery.json();
      if (!result.id)
        return reply(
          502,
          "Unable to confirm submission. Please contact info@lmipk.com.",
        );
      return reply(
        200,
        "Your quote request has been submitted to LMI. Our team will contact you using the details provided.",
        { reference: payload.requestId },
      );
    } catch {
      return reply(
        503,
        "Unable to submit right now. Please try again or email info@lmipk.com.",
      );
    }
  };
}
