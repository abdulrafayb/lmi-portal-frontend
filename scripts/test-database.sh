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
