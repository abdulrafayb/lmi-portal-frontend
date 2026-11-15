import { createQuoteHandler } from "./handler.mjs";
// This endpoint is public. Turnstile, server validation and shared quotas protect it.
Deno.serve(
  createQuoteHandler({
    projectUrl: Deno.env.get("SUPABASE_URL"),
    serviceKey: Deno.env.get("SUPABASE_SERVICE_ROLE_KEY"),
    resendKey: Deno.env.get("RESEND_API_KEY"),
    fromEmail: Deno.env.get("QUOTE_FROM_EMAIL"),
    websiteOrigins: Deno.env.get("QUOTE_WEBSITE_ORIGINS"),
    turnstileSecret: Deno.env.get("TURNSTILE_SECRET_KEY"),
  }),
);
