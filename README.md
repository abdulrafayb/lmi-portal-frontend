# LMI content portal — Supabase

The existing portal UI now uses Supabase Auth, PostgreSQL and RPC APIs directly. No Node backend, MongoDB, Render service, or image-upload service is needed. The administrator edits one fixed section at a time, shows/hides it, and chooses Cancel or Publish. History records before/after values. Layouts, sections, order and list slots cannot be added/deleted through the portal.

## Existing project: one editable field per heading

Run [`supabase/migrations/202611150001_single_heading_fields.sql`](supabase/migrations/202611150001_single_heading_fields.sql) in Supabase SQL Editor. Do **not** rerun the initial table-creation migration. This update joins the heading lines currently stored in your database into one string, for both templates and published content. It preserves your edits, section visibility, and existing history, records a System migration event, and increments changed sections' revisions so old open editor tabs cannot overwrite the new format. Reload the portal afterward. It is safe to rerun: headings already converted are left unchanged.

The portal displays one field even for legacy heading arrays during rollout; the website also accepts old heading arrays while projects migrate. Current catalog/seed content uses plain strings. Other arrays, such as service cards or paragraphs, remain separate fixed items. Headings wrap naturally on the website rather than using hard-coded line breaks. A fresh project seeded with the latest `seed.sql` already has this format; applying this migration there is a no-op.

## Set up Supabase (in this order)

1. Create a Supabase project in your organization. Choose a nearby region, set a strong database password, and save it privately. The database password is **not** the portal login password and never belongs in a frontend environment variable.
2. In **SQL Editor**, create a new query, paste all of [`supabase/migrations/202611110001_cms.sql`](supabase/migrations/202611110001_cms.sql), and run it **once**. It creates the tables, row-level security and API functions. Keep RLS enabled. This migration is a first-time migration, not a script to rerun on an initialized project.
3. Create another query, paste [`supabase/seed.sql`](supabase/seed.sql), and run it. It seeds the website's 25 pages / 178 active sections (existing projects retain retired records). It is safe to rerun: it does not replace published content. `npm run seed:sql` regenerates it from `supabase/catalog.json` when the developer updates the layout contract.
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
8. The **website** now needs build-time `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY` and `SITE_URL` variables instead of Vite Supabase variables. The portal keeps the Vite variables above. Remove obsolete `VITE_API_URL` / `VITE_CMS_API_URL` variables. Both projects build with `npm run build` and publish `dist`. The website build requires live Supabase content and fails rather than falling back.
9. Configure the website rebuild trigger below, then sign in with the admin **email/password**, edit a section and Publish. Confirm the change and History. The website changes only after a successful static rebuild/deployment. There is no browser content fetching or JSON fallback anymore.

No custom backend URL or CORS-origin environment variable is needed. The RPC endpoints are served by Supabase. For this password-only flow there are no auth callback pages; set your production portal URL under Authentication URL Configuration for future dashboard/password-reset email configuration. Password resets can be managed in the Supabase dashboard; no reset UI is included in the portal.

## Local development

Node 22+. `npm ci`, copy `.env.example` to `.env`, fill the project URL / public key / website URL, then `npm run dev`. Use the same initialized Supabase project, or a separate development project. `.env` is ignored by Git. `npm run build` and `npm run preview` verify the production build.

Login sessions are managed/refreshed by the Supabase SDK and stored in sessionStorage. Sign-out removes this browser session and revokes its refresh token; Supabase access JWTs issued earlier remain valid until their normal expiry. Use a short appropriate JWT lifetime in Supabase for this private portal. No account creation or admin-allowlist management is exposed to browsers.

## Images and rendering

Images remain website files, edited as paths such as `/photo.webp`. Deploy the image in the website's `public/` folder first. The portal previews paths against `VITE_WEBSITE_URL`. `/public/photo.webp` is normalized to `/photo.webp` by the database function. No upload service is involved.

The website's `CMS.md` describes static generation. It fetches content at build time, emits HTML for each route, and never calls the content API in the browser. Hidden sections remain hidden in the generated site. An API failure fails the build and leaves the current deployment live; no bundled JSON fallback is used.

## Access model and APIs

- `cms_public_page(p_page_id)` is the only anonymous CMS API. Hidden section content, templates and history are not returned.
- `cms_admin_me()`, `cms_admin_pages()`, `cms_admin_page(p_page_id)` and `cms_admin_history(p_page,p_page_id)` require the single allowed admin.
- `cms_publish_section(p_page_id,p_key,p_data,p_enabled,p_expected_revision)` locks the section, validates its schema, checks the revision, updates it, and appends the audit event in the **same transaction**. A stale edit returns a 409 conflict; reload the section before retrying.
- Direct table writes, section creation/deletion, audit deletion and allowlist editing are forbidden to anon/authenticated browser roles. Admin read policies are also protected by RLS. Privileged SQL Editor access is for project owners only.

## Tests

`npm run test:db` needs Docker. It creates and removes a disposable PostgreSQL 16 container and tests the migration, seeding, permissions/RLS, single-admin rule, publishing/history consistency, URL validation, missing headings and revision conflicts. `supabase/tests/auth-shim.sql` is a test-only stand-in for Supabase Auth: **never run it in your Supabase project**. Browser checks cover portal publishing, rebuild requests/retries, and the website’s static HTML, hydration and build-failure behavior.

## Moving accounts later

Transferring the existing project to the new owner's organization is usually simpler than copying data; check Supabase's current transfer eligibility. If creating a new project instead, apply the migration there and migrate the **current** `cms_pages`, `cms_sections` and `cms_history` data with a database backup/export. Do not rely on `seed.sql` to move edits: it contains the original website content only. Create the admin in the new project's Auth and set its new UUID in `cms_admin`. Do not copy an old admin UUID blindly. Historical actor UUIDs remain as audit values and do not block migration. Update both sites' Supabase settings, redeploy the Edge Function and its secrets in the new project, and rebuild both sites; users sign in again.

The old `lmi-portal-backend` repository is no longer referenced. It can be archived or deleted after you are satisfied with this setup; no local backend work was deleted automatically.

## Netlify website rebuild trigger (required for Publish → live website)

Publishing content and deploying the static website are separate steps. Supabase commits the section/history first. The portal then calls an authenticated Edge Function to request a Netlify rebuild. If the trigger fails, content stays saved and the portal offers **Retry website build**. A separate toolbar **Request website rebuild** button can request a build after a browser reload or a manually fixed build. Neither action duplicates the publication/history event. Only a completed, successful Netlify deployment makes changes live; queued/accepted does not mean deployed.

1. In the **website's** Netlify site, create a build hook for the production `main` branch (Build & deploy → Build hooks). Treat the entire hook URL as private. Do not put it in either React project's environment variables or source files.
2. Deploy `supabase/functions/request-website-build` in the same Supabase project. With the Supabase CLI authenticated and linked:
   ```bash
   supabase link --project-ref YOUR_PROJECT_REF
   supabase secrets set --env-file .env.edge.local
   supabase functions deploy request-website-build --no-verify-jwt
   ```
   Create ignored `.env.edge.local` with:
   ```text
   WEBSITE_BUILD_HOOK_URL=https://api.netlify.com/build_hooks/YOUR_PRIVATE_HOOK
   PORTAL_ORIGIN=https://YOUR_PORTAL.netlify.app
   ```
   Do not add a trailing slash to `PORTAL_ORIGIN`. The function uses Supabase-provided `SUPABASE_URL` and `SUPABASE_ANON_KEY` automatically. If legacy API keys are disabled, also set `CMS_PUBLISHABLE_KEY` to your project’s publishable key as a function secret.
3. The function's gateway JWT check is intentionally disabled for Supabase signing-key compatibility. **It still validates the user token through Supabase Auth and checks `cms_admin_me()` before calling Netlify.** Non-admin and anonymous requests are rejected. CORS only allows the configured portal origin; authorization is enforced independently of CORS. Never replace this with an unauthenticated proxy to the build hook.
4. Deploy the updated portal. Publish a small change and check Netlify Deploys. If Supabase content is missing or unavailable, the build must fail and the existing website remains live. Fix the data/configuration and use **Retry website build** or **Request website rebuild**.

The portal does not claim to monitor Netlify completion; use Netlify Deploys to see whether the requested build succeeded. Direct SQL edits do not automatically request a build; use the rebuild toolbar or Netlify for those. If the browser closes after saving but before requesting a build, use the toolbar on returning. Multiple publications may queue multiple builds; no timer-based debounce is used that could lose a later edit. When moving hosting later, replace this Netlify-specific trigger with that host's CI/deploy mechanism. The website itself stays static React output.

`npm test` checks build-trigger authentication/allowlisting and secret-safe failure handling. `npm run test:db` continues to test the database publishing/security contract.

## Home images and removed related sections

Existing projects: run only [`supabase/migrations/202611150002_home_images_and_related_layouts.sql`](supabase/migrations/202611150002_home_images_and_related_layouts.sql) in a new Supabase SQL Editor query. It sets the uploaded Home image paths, adds the hero image fields to the portal template, and retires the Related Services/Related Pages block on eight service pages and three Fleet & Visibility pages. No sections/history are deleted. Existing text and visibility are preserved; changed records receive a revision and System history entry. Refresh the portal and rebuild the website afterward. Do not rerun the original table-creation migration.

The eight `public/home/section-2-image-*.png` files correspond to Home's service cards (Section Four in code). Industry images are supplied for slots 1, 2, 4 and 5. There is no `section-8-image-3.png` for Manufacturing; that slot retains its existing image or placeholder. All image paths remain editable through the portal. Fresh projects use the updated seed/catalog (178 active sections). Old databases can still contain 190 physical section records; the 11 retired records are filtered out of CMS/public APIs and cannot be republished through the portal.

## Six-card leadership layout

Existing projects: run `supabase/migrations/202611150003_leadership_team_cards.sql` once after the earlier migrations, then refresh the portal and rebuild the website. It moves the CEO to the first of six fixed team cards, preserves the five current edited cards and the CEO portrait, and retires the old executive section without deleting its data/history. It is safe to rerun. Fresh installs use the updated catalog/seed.

## Services overview cards retired

For existing projects, run the portal migration `supabase/migrations/202611150004_retire_services_overview_cards.sql`, then rebuild the website and refresh the portal. Section two is removed from the Services overview layout and CMS editing. Its content and history stay stored. The hero’s `#services` link now leads to the following section.

## Services overview FAQs

Run the portal migration `supabase/migrations/202611150005_services_overview_faq.sql` for existing projects before building the website. It adds a six-item FAQ section at the end of Services overview, using the existing accordion design. Placeholder questions and answers are editable in the portal. Rerunning the migration preserves publications and visibility; fresh installs use the updated seed.
