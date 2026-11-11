import { createClient } from "@supabase/supabase-js";
const url = import.meta.env.VITE_SUPABASE_URL;
const key = import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY;
export const WEBSITE = (import.meta.env.VITE_WEBSITE_URL ?? "").replace(
  /\/$/,
  "",
);
export const supabase =
  url && key
    ? createClient(url, key, {
        auth: {
          storage: window.sessionStorage,
          storageKey: "lmi-portal-auth",
          persistSession: true,
          autoRefreshToken: true,
          detectSessionInUrl: false,
        },
      })
    : null;
function configured() {
  if (!supabase)
    throw new Error(
      "Set VITE_SUPABASE_URL and VITE_SUPABASE_PUBLISHABLE_KEY before using the portal.",
    );
  return supabase;
}
async function rpc(name, params = {}, signal) {
  let query = configured().rpc(name, params);
  if (signal) query = query.abortSignal(signal);
  const { data, error } = await query;
  if (error) {
    const failure = new Error(
      error.message || "Cannot reach Supabase. Please try again.",
    );
    failure.status = Number(error.code?.replace(/^PT/, "")) || 500;
    throw failure;
  }
  return data;
}
export async function signIn(email, password) {
  const { error } = await configured().auth.signInWithPassword({
    email,
    password,
  });
  if (error) throw new Error(error.message);
}
export async function signOut() {
  const { error } = await configured().auth.signOut({ scope: "local" });
  if (error) throw new Error(error.message);
}
export const getAdmin = () => rpc("cms_admin_me");
export const getPages = (signal) => rpc("cms_admin_pages", {}, signal);
export const getPage = (id, signal) =>
  rpc("cms_admin_page", { p_page_id: id }, signal);
export const publishSection = (id, key, data, enabled, revision) =>
  rpc("cms_publish_section", {
    p_page_id: id,
    p_key: key,
    p_data: data,
    p_enabled: enabled,
    p_expected_revision: revision,
  });
export const getHistory = (page, id, signal) =>
  rpc("cms_admin_history", { p_page: page, p_page_id: id || null }, signal);
