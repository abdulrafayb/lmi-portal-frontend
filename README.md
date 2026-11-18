# LMI content portal — Supabase

The existing portal UI now uses Supabase Auth, PostgreSQL and RPC APIs directly. No Node backend, MongoDB, Render service, or image-upload service is needed. The administrator edits one fixed section at a time, shows/hides it, and chooses Cancel or Publish. History records before/after values. Layouts, sections, order and list slots cannot be added/deleted through the portal.

## Existing project: one editable field per heading

Run [`supabase/migrations/202611150001_single_heading_fields.sql`](supabase/migrations/202611150001_single_heading_fields.sql) in Supabase SQL Editor. Do **not** rerun the initial table-creation migration. This update joins the heading lines currently stored in your database into one string, for both templates and published content. It preserves your edits, section visibility, and existing history, records a System migration event, and increments changed sections' revisions so old open editor tabs cannot overwrite the new format. Reload the portal afterward. It is safe to rerun: headings already converted are left unchanged.

The portal displays one field even for legacy heading arrays during rollout; the website also accepts old heading arrays while projects migrate. Current catalog/seed content uses plain strings. Other arrays, such as service cards or paragraphs, remain separate fixed items. Headings wrap naturally on the website rather than using hard-coded line breaks. A fresh project seeded with the latest `seed.sql` already has this format; applying this migration there is a no-op.

## Set up Supabase (in this order)

1. Create a Supabase project in your organization. Choose a nearby region, set a strong database password, and save it privately. The database password is **not** the portal login password and never belongs in a frontend environment variable.
2. In **SQL Editor**, create a new query, paste all of [`supabase/migrations/202611110001_cms.sql`](supabase/migrations/202611110001_cms.sql), and run it **once**. It creates the tables, row-level security and API functions. Keep RLS enabled. This migration is a first-time migration, not a script to rerun on an initialized project.
3. Create another query, paste [`supabase/seed.sql`](supabase/seed.sql), and run it. It seeds the website's 25 pages / 175 active sections (existing projects retain retired records). It is safe to rerun: it does not replace published content. `npm run seed:sql` regenerates it from `supabase/catalog.json` when the developer updates the layout contract.
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

The eight `public/home/section-2-image-*.png` files correspond to Home's service cards (Section Four in code). Industry images are now supplied for all five slots. Apply `202611180001_home_manufacturing_image.sql` to add the subsequently supplied `section-8-image-3.png` Manufacturing image to an existing database. All image paths remain editable through the portal. Fresh projects use the updated seed/catalog (175 active sections). Old databases can still contain 190 physical section records; the 11 retired records are filtered out of CMS/public APIs and cannot be republished through the portal.

## Six-card leadership layout

Existing projects: run `supabase/migrations/202611150003_leadership_team_cards.sql` once after the earlier migrations, then refresh the portal and rebuild the website. It moves the CEO to the first of six fixed team cards, preserves the five current edited cards and the CEO portrait, and retires the old executive section without deleting its data/history. It is safe to rerun. Fresh installs use the updated catalog/seed.

## Services overview cards retired

For existing projects, run the portal migration `supabase/migrations/202611150004_retire_services_overview_cards.sql`, then rebuild the website and refresh the portal. Section two is removed from the Services overview layout and CMS editing. Its content and history stay stored. The hero’s `#services` link now leads to the following section.

## Services overview FAQs

Run the portal migration `supabase/migrations/202611150005_services_overview_faq.sql` for existing projects before building the website. It adds a six-item FAQ section at the end of Services overview, using the existing accordion design. Placeholder questions and answers are editable in the portal. Rerunning the migration preserves publications and visibility; fresh installs use the updated seed.

## Industries overview section four retired

For existing projects, run the portal migration `supabase/migrations/202611150006_retire_industries_overview_cards.sql`, refresh the portal and rebuild the website. The cargo-to-service card section is removed from the layout and CMS editor; its stored content/history is preserved. The following comparison section uses a white background.

## Shipment Tracking Where It Applies retired

Existing projects: run the portal migration `supabase/migrations/202611150007_retire_tracking_services.sql`, then rebuild the website and refresh the portal. The Where It Applies service-link section is retired from the layout/editor while stored data and history are preserved.

## Three HSSE awards

Existing projects must run the portal migration `supabase/migrations/202611160001_hsse_three_awards.sql` before rebuilding the website. It removes the fourth Shell award and its image slot while retaining current edits to the other three awards and the policy content. The migration records the change in history and is safe to rerun. Refresh the portal afterward.

## Website quote email

The website submits directly to Formspree. There is no Supabase email function, email template backend, or email-service secret to configure. Follow [the Formspree setup guide](supabase/QUOTE_EMAIL_SETUP.md) to select `info@lmipk.com` as the recipient and configure the website endpoint. The portal's Supabase CMS and website rebuild function are unchanged.

## HSSE Related Pages retired

Existing projects: run the portal migration `supabase/migrations/202611170002_retire_hsse_related.sql` to retire HSSE’s Related Pages from the editor/public API, then refresh the portal and rebuild the website. The section is removed from the layout; its stored content and history are preserved. The migration is safe to rerun.

## Service client and testimonial cards

The eight service detail pages use matching rounded client cards, optional middle highlight cards only where that content already exists (Heavy & Project Cargo and Chemical & Liquid Cargo), and a full-width testimonial card. Existing client counts and copy are retained. Logos use the existing `image` URL field and a visual placeholder until supplied; names remain visible with uploaded logos.

Existing projects: run the portal migration `supabase/migrations/202611170003_service_trust_cards.sql`, refresh the portal, and rebuild the website. It adds name/image fields to previously text-only client slots without overwriting edited names/images, visibility or other section content. The migration is safe to rerun. Old placeholder wording becomes the initial editable name only when no name field existed.

To hide an individual client card, clear **both name and image** for that fixed item. Its structural ID/placeholder flags do not keep it visible. The remaining client cards expand evenly across the desktop row. Clear heading and description to hide a middle highlight; remaining highlights fill the row. Clear quote and attribution to hide the testimonial card. Clearing every visible field in the entire section hides it. Missing optional parts stay omitted. These are fixed slots: no CMS adding, deleting or layout controls have been introduced. Original `data/` files remain unchanged.

## Home Manufacturing & Industrial image

The missing third Home industry photo is now `/home/section-8-image-3.png`. For an existing database, run the portal migration `supabase/migrations/202611180001_home_manufacturing_image.sql`, then rebuild the website. It changes only that image path, preserves edited text and section visibility, and audits the change. It is safe to rerun and does not recreate a missing/null/empty third slot. Fresh installs receive the image path through the updated seed. Earlier migration instructions describing the photo as missing applied before this asset was supplied.

## Home trust logos and image formats

The Home section-two logo strip now uses the supplied Shell, PSO, Caltex, Engro and NLC images from `public/home`. Existing databases: run the portal migration `supabase/migrations/202611180002_home_trust_logos.sql`, then rebuild the website. It changes only existing logo image paths, preserves edited names and section visibility, and is safe to rerun. Fresh installs receive the paths through the seed.

Images are URLs/paths, not uploads. For a deployed file `public/home/logo.webp`, enter `/home/logo.webp` (or `/public/home/logo.webp`, which is normalized). JPG/JPEG, PNG, WebP, GIF, AVIF, SVG, BMP and other browser-supported formats work in both the portal preview and website; there is no PNG-only extension rule. Exact filenames, capitalization and extensions must match deployed files. Commit/push the file to the website repository, update its path in the portal, publish, then wait for the website rebuild. New files or changed paths require a successful deployment to appear. Convert formats that web browsers cannot decode, such as TIFF/HEIC, to a supported web format first. Local static preview now serves the corresponding image MIME types too.

## Company page images

Run `supabase/migrations/202611180003_company_images.sql` after the earlier leadership team migration, then rebuild the website. It connects all 18 supplied About Us, Leadership and Certifications images, preserves text/visibility, skips missing or cleared cards, and is safe to rerun. Portraits and certificates follow the existing card order. `supabase/company-image-map.json` lists every mapping; fresh installs use the updated seed.

## Service page images

Run `supabase/migrations/202611180004_service_images.sql` after the service trust cards migration, then rebuild the website. This connects all 54 supplied service images, including the overview hero. Numbered logos follow existing client-card order. Text/visibility and missing or cleared cards are preserved; reruns are safe. `supabase/service-image-map.json` lists the mappings, and fresh installs receive the updated seed.

## About Us partner logos

Run `supabase/migrations/202611180005_about_partner_logos.sql`, then rebuild the website to show the eight supplied `public/our-company/about-us/logo-1.png` through `logo-8.png` images in section six. Logos follow existing partner order. The migration preserves edited names/visibility and skips missing or cleared objects; reruns are safe. Fresh installs use the updated seed.

## Industry page images

Run `supabase/migrations/202611180006_industry_images.sql`, then rebuild the website. It connects all 58 supplied industry images, including overview images. Numbered images/logos follow existing card order. Automotive's `section-2-main-image.png` maps to CMS sectionThree, which is displayed second. Text, visibility and cleared card objects are preserved; reruns are safe. `supabase/industry-image-map.json` lists all mappings. Fresh installs use the updated seed.

## Fleet & Visibility images

Run `supabase/migrations/202611180007_fleet_images.sql`, then rebuild the website. It connects all 15 supplied images on Fleet & Equipment, Nationwide Network and Shipment Tracking. It also adds editable `image`/`imageAlt` fields to the tracking section-three map panel. Text, visibility and cleared card objects are preserved; reruns are safe. `supabase/fleet-image-map.json` lists mappings, using the exact supplied folder spelling `fleet-and-visiblity`. Fresh installs use the updated seed.

## HSSE images

Run `supabase/migrations/202611180008_hsse_images.sql` after the earlier three-award migration, then rebuild the website. It connects the six supplied HSSE images: section-one, section-four and section-seven photos plus three awards in existing card order. Text, visibility and cleared award objects are preserved; reruns are safe. `supabase/hsse-image-map.json` lists mappings. Fresh installs use the updated seed.

## Insights and Contact Us images

Run `supabase/migrations/202611180009_insights_contact_images.sql`, then rebuild the website. It connects six supplied images: Insights hero, three cards and leadership portrait, plus the Contact Us hero. Text, visibility and cleared card objects are preserved; reruns are safe. `supabase/insights-contact-image-map.json` lists mappings. Fresh installs use the updated seed.

## Publications and direct image uploads

1. Run `supabase/migrations/202611180010_publications_and_media.sql` in the Supabase SQL Editor after the existing CMS migrations. It creates publication/audit tables, admin-only save APIs, a public `cms-media` image bucket with admin-only uploads, and nine **Sample:** posts (three per type). Reruns preserve edited posts and custom CTA links.
2. Deploy this portal, then rebuild the website. The website build now also requires `cms_public_posts`; it fails clearly if the migration is missing. Keep the existing `request-website-build` Edge Function configured so publishing requests a deployment.
3. Open **Publications** in the portal. Choose Blog, Case study or Article; add a lowercase URL slug, title, summary, featured image, author, date and rich text body. SEO title/description and author role are optional. Save Draft to keep content private or unpublish it; Save & publish makes it public after the rebuild. Future scheduling is not included. Revision history is available inside each publication. Changing the slug changes the URL; automatic redirects are not created.
4. Listings are `/blogs`, `/case-studies` and `/articles`, with details at `/<listing>/<slug>`. The existing `/insights` landing page remains. Home and Insights link to published posts and these listings; no new header/footer links are added. Listing and detail HTML, SEO metadata and sitemap entries are generated at build time. Drafts are never included in the public API/build.

All image fields now allow a public-folder path or HTTPS URL **or** a direct upload. Body images in the rich editor support the same options. Existing JPG/JPEG/PNG/WebP/GIF/AVIF/SVG paths still work. Uploads accept JPG, PNG, WebP, GIF and AVIF up to 10 MB; use a path/URL for SVG. Files receive unique object names and public URLs. Only the allowlisted CMS admin can upload; images are publicly viewable. Removing/replacing a field does not delete its file, to avoid breaking other pages. Manage unused files through the Supabase Storage dashboard. No service-role key is needed in either frontend.

The sample publications are explicitly labelled demonstration content, not real client results. Edit them or save them as drafts before using this content publicly. A saved publication can succeed even if the build hook fails; use **Website content → Request website rebuild** after fixing the build configuration. Deploy the SQL migration before rebuilding the website.
