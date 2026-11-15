# Send website quote enquiries to LMI

The website sends the quote form to the public `send-quote` Supabase Edge Function. It verifies Cloudflare Turnstile, validates the fields, checks shared quotas, and sends an HTML and plain-text email through Resend. The only recipient is **info@lmipk.com**. Reply-To is the visitor's email. No email service credentials belong in the website or portal frontend.

## 1. Verify a sending domain in Resend

1. Create a Resend account and open **Domains → Add domain**.
2. Use a dedicated sending subdomain such as **notifications.lmipk.com**.
3. Add the exact DNS records Resend displays at the provider that manages `lmipk.com` DNS. Keep the existing records for your `info@lmipk.com` mailbox; this sending subdomain does not replace your mailbox.
4. Wait until Resend shows the domain as verified. No inbox needs to exist at the sending address.
5. Create an API key with **Sending access**, restricted to that domain if available. Keep it private.
6. Use a verified sender such as `LMI Website <website@notifications.lmipk.com>`. The default Resend test sender cannot deliver production enquiries to arbitrary recipients.

## 2. Create a free Cloudflare Turnstile widget

1. In Cloudflare, open **Turnstile → Add widget**. Your website can stay hosted on Netlify; you do not need to move its DNS to Cloudflare.
2. Choose **Managed** mode.
3. Add the website hostname, currently `logistics-management-international.netlify.app`. Add your custom hostname when you use one. Enter hostnames only, without `https://` or paths.
4. Save the **site key** (public) and **secret key** (private). The website automatically sends the action `quote`.
5. For local development, use Cloudflare's documented testing keys and a local-only function configuration. Do not deploy testing keys on the public website.

## 3. Run the database migration

In Supabase **SQL Editor**, run:

[`migrations/202611160002_quote_email.sql`](migrations/202611160002_quote_email.sql)

Run this for existing and fresh projects after the main CMS schema and seed. It creates a private RLS-protected quota table and service-role-only function. It is safe to rerun. It also replaces the old built-in email-draft instruction without overwriting custom notes, and records that content change in CMS history.

The quotas allow **5 validated attempts per hashed IP address per 15 minutes** and **90 validated attempts per UTC day for this form**. These are conservative sending-attempt limits, including provider failures. Change them in a reviewed migration if your needs change. Only salted IP hashes and counters are stored, not raw IP addresses or enquiry details. Old quota rows are removed during subsequent submissions. Your team receives the enquiry details by email; they are not added to the CMS history or a database inbox.

## 4. Add private Supabase Edge Function secrets

In Supabase's **Edge Functions → Secrets**, add:

| Secret | Value |
| --- | --- |
| `RESEND_API_KEY` | Your Resend sending API key |
| `QUOTE_FROM_EMAIL` | `LMI Website <website@notifications.lmipk.com>` (use your verified sender) |
| `QUOTE_WEBSITE_ORIGINS` | `https://logistics-management-international.netlify.app` |
| `TURNSTILE_SECRET_KEY` | Your Turnstile secret key |

Use an exact origin with no trailing slash or path. Multiple trusted origins can be comma-separated, e.g. Netlify plus your later custom domain. Add only domains you control. The function also checks that Turnstile's verified hostname matches the requesting origin.

Supabase automatically provides `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` inside the Edge Function. Do not copy the service-role key into either frontend. JWT gateway verification is disabled for this public enquiry endpoint; Turnstile, origin checks, server validation and quotas protect submission. This does not change authentication on the administrator portal.

CLI alternative: create a local ignored `supabase/.env.quote.local` containing those four secrets, then run:

```sh
npx supabase login
npx supabase link --project-ref YOUR_PROJECT_REF
npx supabase secrets set --env-file supabase/.env.quote.local
```

Never commit this file or paste private keys into a public issue or chat.

## 5. Deploy the function

From the **lmi-portal-frontend** repository (where the Supabase functions live):

```sh
npx supabase functions deploy send-quote --project-ref YOUR_PROJECT_REF --no-verify-jwt
```

Deploying the portal through Netlify does **not** deploy Supabase functions. Deploy this function separately. No separate Node server or paid runtime is required.

Its public URL is:

```text
https://YOUR_PROJECT_REF.supabase.co/functions/v1/send-quote
```

## 6. Set two public website variables and rebuild

In the **website's** Netlify environment variables (and website `.env` for local builds), add:

```dotenv
VITE_QUOTE_FUNCTION_URL=https://YOUR_PROJECT_REF.supabase.co/functions/v1/send-quote
VITE_TURNSTILE_SITE_KEY=YOUR_PUBLIC_TURNSTILE_SITE_KEY
```

Keep the existing `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY` and `SITE_URL` build variables. The portal needs no new frontend environment variables. Rebuild the website after adding or changing any `VITE_` value. Missing quote configuration disables online submission and shows a direct email contact instead; it never pretends to send.

## 7. Verify delivery

1. Visit the deployed `/contact-us` page and fill in a test enquiry using your own contact details.
2. Complete the security check and submit once. The button shows a sending state and prevents duplicate clicks.
3. Check **info@lmipk.com**, including spam/junk, and Resend's email logs. Confirm the recipient, all fields, branded template, reference and Pakistan submission time.
4. Click Reply and verify it addresses the customer's email, rather than the website sender.
5. Success means Resend accepted the email, not that the recipient's mail server guarantees delivery. Use Resend logs for delivered/bounced status. Provider errors leave the form values available for retry and show a contact alternative. No automatic customer acknowledgement email is sent; each accepted enquiry uses one email.

Unchanged retries reuse a submission reference and timestamp so Resend's idempotency window can suppress duplicates. Editing the form creates a new reference. CAPTCHA verification expires and must be renewed for each attempt.

## Troubleshooting

- **Online submissions are not available:** set both website `VITE_` variables, then rebuild.
- **Security check cannot load:** allow `challenges.cloudflare.com` in browser/privacy settings and any CSP you manage, confirm allowed widget hostnames, then reload.
- **Security check failed/expired:** complete it again; verify the widget secret belongs to the site's key. The expected action is `quote`.
- **403:** check the exact `QUOTE_WEBSITE_ORIGINS` value against the live website origin.
- **503:** check function deployment, private secrets, SQL migration and Supabase function logs. The handler deliberately does not return credentials or raw provider errors to visitors.
- **502 / no email:** verify the Resend sender/domain and key permissions, free-plan limits, recipient mailbox, and Resend logs. Requests aren't reported as successful if Resend rejects them.
- **429:** shared quota exceeded. Wait, or contact LMI by email. Do not bypass the quota from the browser.
- **CMS edits still show the old mail-app note:** run the migration and rebuild; if that note was customized, update it in the portal to describe direct submission.

`npm test` exercises validation, CORS, CAPTCHA, fixed recipient, Reply-To, escaping, provider failures and idempotent payloads with mocked services; it sends no real emails. `npm run test:db` checks quota permissions and limits in disposable PostgreSQL. A real delivery test requires your verified domain, deployed function and secrets.
