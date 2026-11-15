#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
cms_test_container="lmi-supabase-test-$$"
trap 'docker rm -fv "$cms_test_container" >/dev/null 2>&1 || true' EXIT
docker run -d --name "$cms_test_container" -e POSTGRES_PASSWORD=disposable-test-only postgres:16 >/dev/null
for ((i=0;i<60;i++)); do
  if docker exec "$cms_test_container" pg_isready -U postgres >/dev/null 2>&1; then break; fi
  sleep 0.5
done
for file in supabase/tests/auth-shim.sql supabase/migrations/202611110001_cms.sql supabase/seed.sql supabase/tests/access-and-publish.sql; do
 docker exec -i "$cms_test_container" psql -U postgres -v ON_ERROR_STOP=1 < "$file" >/dev/null
done
# Reseeding must not replace an administrator's published content.
docker exec -i "$cms_test_container" psql -U postgres -v ON_ERROR_STOP=1 < supabase/seed.sql >/dev/null
docker exec -i "$cms_test_container" psql -U postgres -v ON_ERROR_STOP=1 <<'SQL'
do $$ begin
 if (select revision from public.cms_sections where page_id='home' and key='sectionTen')<>1 then raise exception 'Seed overwrote publication';end if;
 if (select count(*) from public.cms_history)<>2 then raise exception 'History lost';end if;
end $$;
SQL
printf '%s\n' 'Supabase schema, RLS, single admin, public reads, publishing, audit, validation, revision conflicts, and safe seeding checks passed.'

# Existing projects migrate edited heading arrays without resetting content.
for file in supabase/tests/single-headings.sql supabase/migrations/202611150001_single_heading_fields.sql supabase/migrations/202611150001_single_heading_fields.sql supabase/tests/verify-single-headings.sql; do
 docker exec -i "$cms_test_container" psql -U postgres -v ON_ERROR_STOP=1 < "$file" >/dev/null
done
printf '%s\n' 'Single-heading migration preserves edits/visibility, audits changes, is idempotent and rejects stale revisions.'

for file in supabase/tests/home-images.sql supabase/migrations/202611150002_home_images_and_related_layouts.sql supabase/migrations/202611150002_home_images_and_related_layouts.sql supabase/tests/verify-home-images.sql; do
 docker exec -i "$cms_test_container" psql -U postgres -v ON_ERROR_STOP=1 < "$file" >/dev/null
done
printf '%s\n' 'Home images preserve text/visibility and absent-image slots; related sections retire without losing their stored content.'

for file in supabase/tests/leadership.sql supabase/migrations/202611150003_leadership_team_cards.sql supabase/migrations/202611150003_leadership_team_cards.sql supabase/tests/verify-leadership.sql; do
 docker exec -i "$cms_test_container" psql -U postgres -v ON_ERROR_STOP=1 < "$file" >/dev/null
done
printf '%s\n' 'Leadership migration preserves existing cards, portrait, visibility and archived content; reruns do not duplicate cards or audit events.'

for file in supabase/tests/services-overview.sql supabase/migrations/202611150004_retire_services_overview_cards.sql supabase/migrations/202611150004_retire_services_overview_cards.sql supabase/tests/verify-services-overview.sql; do
 docker exec -i "$cms_test_container" psql -U postgres -v ON_ERROR_STOP=1 < "$file" >/dev/null
done
printf '%s\n' 'Services overview retirement preserves content/history and is idempotent.'

for file in supabase/tests/overview-faq.sql supabase/migrations/202611150005_services_overview_faq.sql supabase/migrations/202611150005_services_overview_faq.sql supabase/tests/verify-overview-faq.sql supabase/migrations/202611150005_services_overview_faq.sql; do
 docker exec -i "$cms_test_container" psql -U postgres -v ON_ERROR_STOP=1 < "$file" >/dev/null
done
docker exec -i "$cms_test_container" psql -U postgres -v ON_ERROR_STOP=1 <<'SQL'
do $$ begin
 if not exists(select 1 from public.cms_sections where page_id='services' and key='sectionSeven' and data#>>'{items,0,answer}'='Admin edited FAQ' and not enabled and revision=3) then raise exception 'FAQ migration overwrote publication';end if;
end $$;
SQL
printf '%s\n' 'Six-item overview FAQ migration adds once and preserves edited content and visibility on rerun.'

for file in supabase/tests/industries-overview.sql supabase/migrations/202611150006_retire_industries_overview_cards.sql supabase/migrations/202611150006_retire_industries_overview_cards.sql supabase/tests/verify-industries-overview.sql; do
 docker exec -i "$cms_test_container" psql -U postgres -v ON_ERROR_STOP=1 < "$file" >/dev/null
done
printf '%s\n' 'Industries overview retirement preserves content/history and is idempotent.'
