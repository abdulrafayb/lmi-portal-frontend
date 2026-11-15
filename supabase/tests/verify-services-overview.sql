do $$ begin
 if not exists(select 1 from public.cms_sections where page_id='services' and key='sectionTwo' and not enabled and revision=5 and data->>'heading'='Admin edited service cards') then raise exception 'Retired overview content lost or migration not idempotent';end if;
 if public.cms_public_page('services')->'sections' ? 'sectionTwo' then raise exception 'Retired section still public';end if;
 if public.cms_section_active('services','sectionTwo') or public.cms_section_active('company--leadership','sectionThree') then raise exception 'Retirement rules lost';end if;
 if (select count(*) from public.cms_history where actor='System: services overview cards retired')<>1 then raise exception 'Unexpected migration history';end if;
end $$;
