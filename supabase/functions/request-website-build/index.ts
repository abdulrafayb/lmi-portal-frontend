import { createBuildHandler } from "./handler.mjs";

// Supabase's gateway JWT check is disabled for signing-key compatibility;
// the handler verifies the token with Auth and checks the admin allowlist itself.
Deno.serve(
  createBuildHandler({
    projectUrl: Deno.env.get("SUPABASE_URL"),
    publicKey: Deno.env.get("CMS_PUBLISHABLE_KEY") ?? Deno.env.get("SUPABASE_ANON_KEY"),
    hookUrl: Deno.env.get("WEBSITE_BUILD_HOOK_URL"),
    portalOrigin: Deno.env.get("PORTAL_ORIGIN"),
  }),
);
