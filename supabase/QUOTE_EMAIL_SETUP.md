# Formspree quote form setup

The website now posts the form directly to **Formspree**. Set **info@lmipk.com** as the recipient in Formspree. The standard notification contains all enquiry fields; the customer's `email` field is used for Reply-To. No email API key, sending domain, Supabase email function or separate CAPTCHA account is required.

## Connect the form

1. Create/sign into your account at **https://formspree.io**.
2. Create a project/form named **LMI Quote Requests**. Set the notification recipient to **info@lmipk.com** and complete the recipient verification email if requested. Ensure email notifications are enabled in the form's settings.
3. Copy its public endpoint, which looks like `https://formspree.io/f/abcdefgh`. Use the real form ID, not this example. The recipient is controlled by your Formspree account, not by a field the visitor can change.
4. In the **website's Netlify site → Environment variables**, add:

   ```dotenv
   VITE_FORMSPREE_ENDPOINT=https://formspree.io/f/YOUR_ACTUAL_FORM_ID
   ```

   For local development, add the same variable to the website's ignored `.env` file.
5. Rebuild/redeploy the website. Vite reads this variable at build time. Restart `npm run dev` after changing local environment variables.
6. Fill in the deployed Contact Us form with a test enquiry. Check the Formspree submissions dashboard and **info@lmipk.com**, including spam/junk. Click Reply in the received notification and confirm it addresses the customer.

Keep the website's existing CMS build variables and all portal variables. Only the website needs the new Formspree variable. Missing/invalid configuration disables submission and displays the direct email contact.

## What the notification contains

- Name and customer email (Reply-To)
- Company, or “Not provided”
- Phone number
- Transportation requirement
- Origin and destination
- Full requirement message

Formspree supplies its standard notification layout. We do not create or send an HTML email template in code. Custom notification styling/subjects and advanced features depend on Formspree's plan. Check its current free submission allowance and enable its available spam protection; the website also sends the supported `_gotcha` honeypot. If you choose extra CAPTCHA or domain restrictions in Formspree, follow its instructions for AJAX forms and retest the deployed form.

The form validates inputs, prevents duplicate clicks while sending, and shows success only when Formspree acknowledges acceptance. Errors preserve entered details for retry. There is no guaranteed duplicate suppression after a timeout/retry, and acceptance does not guarantee mailbox delivery; check Formspree's dashboard and mailbox. When the account/form limit is reached, visitors see an error and the contact alternative. No customer auto-reply is configured by the code.

## Remove the previous email setup, only if you activated it

The old email function, template, CAPTCHA widget, API code and private quota implementation have been removed from both repositories. If you never configured/deployed that setup, skip these cleanup steps.

1. Delete the old **`send-quote`** function from Supabase's Edge Functions dashboard, or run:

   ```sh
   npx supabase functions delete send-quote --project-ref YOUR_PROJECT_REF
   ```

   Deleting source files and deploying the portal to Netlify do not delete an already deployed Supabase function.
2. Delete the old quote-only Edge Function secrets: `RESEND_API_KEY`, `QUOTE_FROM_EMAIL`, `QUOTE_WEBSITE_ORIGINS`, `TURNSTILE_SECRET_KEY`, if they were created only for this removed form. Revoke the old sending key in Resend and remove the unused Turnstile widget if desired. Keep built-in Supabase secrets and all CMS/rebuild configuration.
3. If you ran `202611160002_quote_email.sql` previously, run [`migrations/202611170001_remove_quote_email_backend.sql`](migrations/202611170001_remove_quote_email_backend.sql) in Supabase SQL Editor. It removes only the obsolete quota table/function and updates the original mail-draft note if still present. It preserves CMS data, custom notes and history; rerunning is safe. It is optional when the old backend was never installed.
4. Remove `VITE_QUOTE_FUNCTION_URL` and `VITE_TURNSTILE_SITE_KEY` from the website's Netlify variables/local `.env`. Replace them with `VITE_FORMSPREE_ENDPOINT` and rebuild.

## Checks

Website `npm test` covers endpoint validation, payload fields and rejection/error handling with mocked Formspree responses. Browser checks use mocked submissions and send no real enquiries. A live test requires your Formspree endpoint and verified notification recipient. The portal's database tests cover optional legacy cleanup; the contact form itself no longer depends on a Supabase migration or runtime API.
