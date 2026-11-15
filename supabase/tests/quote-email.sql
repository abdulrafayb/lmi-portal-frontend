do $$ declare i integer; allowed boolean;
begin
 if (select data->>'note' from public.cms_sections where page_id='contact-us' and key='sectionTwo')<>'Submit your requirement directly to LMI. Our team will review it and contact you using the details provided.' then raise exception 'Email note not migrated';end if;
 if (select count(*) from public.cms_history where actor='System: direct quote email enabled')<>1 then raise exception 'Email note audit duplicated';end if;
 if has_table_privilege('anon','public.quote_rate_limits','SELECT') or has_function_privilege('authenticated','public.quote_consume_limit(text)','EXECUTE') or has_function_privilege('anon','public.quote_consume_limit(text)','EXECUTE') then raise exception 'Public quota access';end if;
 if not has_function_privilege('service_role','public.quote_consume_limit(text)','EXECUTE') then raise exception 'Service role quota access missing';end if;
 if public.quote_consume_limit('raw-ip') then raise exception 'Invalid hash accepted';end if;
 for i in 1..5 loop if not public.quote_consume_limit(repeat('a',64)) then raise exception 'Initial quota unavailable';end if;end loop;
 if public.quote_consume_limit(repeat('a',64)) then raise exception 'IP quota bypassed';end if;
 update public.quote_rate_limits set window_start=now()-interval '16 minutes' where key='ip:'||repeat('a',64);
 if not public.quote_consume_limit(repeat('a',64)) then raise exception 'IP quota did not reset';end if;
 for i in 1..84 loop if not public.quote_consume_limit(md5(i::text)||md5(i::text)) then raise exception 'Unexpected daily quota';end if;end loop;
 if public.quote_consume_limit(repeat('b',64)) then raise exception 'Daily quota bypassed';end if;
 update public.quote_rate_limits set window_start=now()-interval '1 day' where key='daily';
 if not public.quote_consume_limit(repeat('c',64)) then raise exception 'Daily quota did not reset';end if;
 if not (select relrowsecurity from pg_class where oid='public.quote_rate_limits'::regclass) then raise exception 'Quota RLS missing';end if;
end $$;
