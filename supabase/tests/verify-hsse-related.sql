do $$ begin
 if not exists(select 1 from public.cms_sections where page_id='hsse' and key='sectionTen' and not enabled and revision=5 and data->>'heading'='Admin edited HSSE links') then raise exception 'Retired overview content lost or migration not idempotent';end if;
 if public.cms_public_page('hsse')->'sections' ? 'sectionTen' then raise exception 'Retired section still public';end if;
 if public.cms_section_active('hsse','sectionTen') or public.cms_section_active('company--leadership','sectionThree') then raise exception 'Retirement rules lost';end if;
 if (select count(*) from public.cms_history where actor='System: HSSE related pages retired')<>1 then raise exception 'Unexpected migration history';end if;
end $$;
