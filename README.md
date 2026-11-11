# LMI content portal — Supabase

The existing portal UI now uses Supabase Auth, PostgreSQL and RPC APIs directly. No Node backend, MongoDB, Render service, or image-upload service is needed. The administrator edits one fixed section at a time, shows/hides it, and chooses Cancel or Publish. History records before/after values. Layouts, sections, order and list slots cannot be added/deleted through the portal.

## Set up Supabase (in this order)

1. Create a Supabase project in your organization. Choose a nearby region, set a strong database password, and save it privately. The database password is **not** the portal login password and never belongs in a frontend environment variable.
2. In **SQL Editor**, create a new query, paste all of [`supabase/migrations/202611110001_cms.sql`](supabase/migrations/202611110001_cms.sql), and run it **once**. It creates the tables, row-level security and API functions. Keep RLS enabled. This migration is a first-time migration, not a script to rerun on an initialized project.
3. Create another query, paste [`supabase/seed.sql`](supabase/seed.sql), and run it. It seeds the website's 25 pages / 190 sections. It is safe to rerun: it does not replace published content. `npm run seed:sql` regenerates it from `supabase/catalog.json` when the developer updates the layout contract.
4. In **Authentication → Users**, add/create your administrator using their email and a strong password. Confirm the email when creating it, if the dashboard offers that option. Do not use Invite unless you have separately configured an invitation flow. Copy this user's **UUID**.
5. In SQL Editor, designate that one account:
   ```sql
   insert into public.cms_admin (user_id)
   values ('PASTE-ADMIN-USER-UUID-HERE'::uuid);
   ```
   Exactly one admin is allowed. No other signed-in user can read admin data or publish. There is no registration page. In Authentication settings, **disable “Allow new users to sign up”** (wording/location may vary). Keep email/password sign-in enabled. Supabase applies its Auth rate limits; use its dashboard to manage/reset the admin password.
6. Copy the **Project URL** and **publishable key** from the project's Connect/API Keys settings. A legacy **anon** key also works. Never copy a secret key or `service_role` key into either frontend.
7. Add these environment variables to the portal's Netlify site:
   ```text
   VITE_SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co
   VITE_SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLIC_PUBLISHABLE_KEY
   VITE_WEBSITE_URL=https://YOUR_WEBSITE.netlify.app
   ```
8. Add `VITE_SUPABASE_URL` and `VITE_SUPABASE_PUBLISHABLE_KEY` with the same values to the **website's** Netlify site. Remove the obsolete `VITE_API_URL` and `VITE_CMS_API_URL` variables. Build both projects with `npm run build`, publishing `dist`, and redeploy both sites.
9. Open the portal, sign in with the admin **email/password**, edit a section and Publish. Confirm the change and History. The website refreshes content when opened/focused or within its 60-second refresh interval. Also test hide/show. API outages use the website's bundled JSON, as requested.

No custom backend URL or CORS-origin environment variable is needed. The RPC endpoints are served by Supabase. For this password-only flow there are no auth callback pages; set your production portal URL under Authentication URL Configuration for future dashboard/password-reset email configuration. Password resets can be managed in the Supabase dashboard; no reset UI is included in the portal.

## Local development

Node 22+. `npm ci`, copy `.env.example` to `.env`, fill the project URL / public key / website URL, then `npm run dev`. Use the same initialized Supabase project, or a separate development project. `.env` is ignored by Git. `npm run build` and `npm run preview` verify the production build.

Login sessions are managed/refreshed by the Supabase SDK and stored in sessionStorage. Sign-out removes this browser session and revokes its refresh token; Supabase access JWTs issued earlier remain valid until their normal expiry. Use a short appropriate JWT lifetime in Supabase for this private portal. No account creation or admin-allowlist management is exposed to browsers.

## Images and rendering

Images remain website files, edited as paths such as `/photo.webp`. Deploy the image in the website's `public/` folder first. The portal previews paths against `VITE_WEBSITE_URL`. `/public/photo.webp` is normalized to `/photo.webp` by the database function. No upload service is involved.

The website's `CMS.md` describes fallback/loading rules. A successful response respects missing/hidden sections. API outages use the original bundled JSON, even when that temporarily brings back a section hidden in the database.

## Access model and APIs

- `cms_public_page(p_page_id)` is the only anonymous CMS API. Hidden section content, templates and history are not returned.
- `cms_admin_me()`, `cms_admin_pages()`, `cms_admin_page(p_page_id)` and `cms_admin_history(p_page,p_page_id)` require the single allowed admin.
- `cms_publish_section(p_page_id,p_key,p_data,p_enabled,p_expected_revision)` locks the section, validates its schema, checks the revision, updates it, and appends the audit event in the **same transaction**. A stale edit returns a 409 conflict; reload the section before retrying.
- Direct table writes, section creation/deletion, audit deletion and allowlist editing are forbidden to anon/authenticated browser roles. Admin read policies are also protected by RLS. Privileged SQL Editor access is for project owners only.

## Tests

`npm run test:db` needs Docker. It creates and removes a disposable PostgreSQL 16 container and tests the migration, seeding, permissions/RLS, single-admin rule, publishing/history consistency, URL validation, missing headings and revision conflicts. `supabase/tests/auth-shim.sql` is a test-only stand-in for Supabase Auth: **never run it in your Supabase project**. Browser checks were also run for login, section publishing/hiding, history, logout, website fallback and partial-content rendering.

## Moving accounts later

Transferring the existing project to the new owner's organization is usually simpler than copying data; check Supabase's current transfer eligibility. If creating a new project instead, apply the migration there and migrate the **current** `cms_pages`, `cms_sections` and `cms_history` data with a database backup/export. Do not rely on `seed.sql` to move edits: it contains the original website content only. Create the admin in the new project's Auth and set its new UUID in `cms_admin`. Do not copy an old admin UUID blindly. Historical actor UUIDs remain as audit values and do not block migration. Update both Netlify sites' URL/public key and redeploy; users sign in again.

The old `lmi-portal-backend` repository is no longer referenced. It can be archived or deleted after you are satisfied with this setup; no local backend work was deleted automatically.
