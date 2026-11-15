do $$ declare section public.cms_sections%rowtype;
begin
 select * into strict section from public.cms_sections where page_id='services' and key='sectionSeven';
 if jsonb_array_length(section.data->'items')<>6 or jsonb_array_length(section.template->'items')<>6 or not section.enabled then raise exception 'Six editable FAQs missing';end if;
 if not (public.cms_public_page('services')->'sections' ? 'sectionSeven') then raise exception 'FAQ not public';end if;
 if (select count(*) from public.cms_history where actor='System: services overview FAQs added')<>1 then raise exception 'Migration history duplicated';end if;
end $$;
update public.cms_sections set data=jsonb_set(data,'{items,0,answer}','"Admin edited FAQ"'),enabled=false,revision=3 where page_id='services' and key='sectionSeven';
