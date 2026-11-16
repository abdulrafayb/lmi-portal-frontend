-- A disposable stand-in for obsolete operational objects; no actual email code.
create table public.quote_rate_limits(key text primary key);
insert into public.quote_rate_limits values('old-counter');
create function public.quote_consume_limit(text) returns boolean language sql as $$ select false $$;
update public.cms_sections set data=jsonb_set(data,'{note}','"This form prepares an email draft. Send it from your email app to submit your request; our team will then review it and contact you using the details provided."') where page_id='contact-us' and key='sectionTwo';
