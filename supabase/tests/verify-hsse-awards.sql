do $$ declare section public.cms_sections%rowtype;
begin
 select * into section from public.cms_sections where page_id='hsse' and key='sectionEight';
 if jsonb_array_length(section.template->'awards')<>3 or jsonb_array_length(section.data->'awards')<>3 then raise exception 'Awards not reduced to three';end if;
 if section.data#>>'{awards,0,description}'<>'Admin edited ISO copy' or section.enabled or section.revision<>6 then raise exception 'Edits/visibility lost or migration not idempotent';end if;
 if (select count(*) from public.cms_history where actor='System: Shell award slot retired')<>1 then raise exception 'Migration audit duplicated';end if;
end $$;
