-- Private operational counters; no enquiry details or raw IP addresses are stored.
begin;
create table if not exists public.quote_rate_limits (
 key text primary key,
 window_start timestamptz not null,
 requests integer not null check(requests>0)
);
alter table public.quote_rate_limits enable row level security;
revoke all on public.quote_rate_limits from public,anon,authenticated;
create or replace function public.quote_consume_limit(p_ip_hash text) returns boolean
language plpgsql security definer set search_path = '' as $$
declare quota_now timestamptz := now(); ip_count integer; daily_count integer;
begin
 if p_ip_hash !~ '^[a-f0-9]{64}$' or p_ip_hash is null then return false;end if;
 -- Serialize the quota check across all Edge Function instances.
 perform pg_catalog.pg_advisory_xact_lock(81616002);
 delete from public.quote_rate_limits where window_start<quota_now-interval '2 days';
 insert into public.quote_rate_limits(key,window_start,requests) values('ip:'||p_ip_hash,quota_now,1)
 on conflict(key) do update set
 requests=case when quote_rate_limits.window_start<quota_now-interval '15 minutes' then 1 else quote_rate_limits.requests+1 end,
 window_start=case when quote_rate_limits.window_start<quota_now-interval '15 minutes' then quota_now else quote_rate_limits.window_start end
 returning requests into ip_count;
 if ip_count>5 then return false;end if;
 insert into public.quote_rate_limits(key,window_start,requests) values('daily',date_trunc('day',quota_now at time zone 'UTC') at time zone 'UTC',1)
 on conflict(key) do update set
 requests=case when quote_rate_limits.window_start<date_trunc('day',quota_now at time zone 'UTC') at time zone 'UTC' then 1 else quote_rate_limits.requests+1 end,
 window_start=date_trunc('day',quota_now at time zone 'UTC') at time zone 'UTC'
 returning requests into daily_count;
 return daily_count<=90;
end $$;
revoke all on function public.quote_consume_limit(text) from public,anon,authenticated;
grant execute on function public.quote_consume_limit(text) to service_role;
-- Retain custom notes, replacing only the old built-in email-draft instruction.
do $$ declare section public.cms_sections%rowtype; new_data jsonb;
begin
 select * into section from public.cms_sections where page_id='contact-us' and key='sectionTwo' for update;
 if section.data->>'note'='This form prepares an email draft. Send it from your email app to submit your request; our team will then review it and contact you using the details provided.' then
   new_data := jsonb_set(section.data,'{note}','"Submit your requirement directly to LMI. Our team will review it and contact you using the details provided."');
   update public.cms_sections set data=new_data,revision=revision+1,updated_at=now() where page_id=section.page_id and key=section.key;
   insert into public.cms_history(actor,actor_id,page_id,section,revision,changes)
   values('System: direct quote email enabled','00000000-0000-0000-0000-000000000000'::uuid,section.page_id,section.key,section.revision+1,public.cms_diff(section.data,new_data));
 end if;
end $$;
commit;
