do $$ begin
 if to_regclass('public.quote_rate_limits') is not null or to_regprocedure('public.quote_consume_limit(text)') is not null then raise exception 'Old quote backend remains';end if;
 if not exists(select 1 from public.cms_sections where page_id='contact-us' and key='sectionTwo' and data->>'note' like 'Submit your requirement directly to LMI.%') then raise exception 'Contact section changed unexpectedly';end if;
 if (select count(*) from public.cms_history where actor='System: Formspree quote form enabled')<>1 then raise exception 'Cleanup note audit duplicated';end if;
end $$;
