do $$ declare section public.cms_sections%rowtype;
begin
 select * into section from public.cms_sections where page_id='services--flatbed-transportation' and key='sectionFive';
 if section.revision<>8 or section.enabled then raise exception 'Migration changed visibility or is not idempotent';end if;
 if jsonb_array_length(section.template->'clients')<>4 or jsonb_array_length(section.data->'clients')<>4 then raise exception 'Fixed slots changed';end if;
 if section.data#>>'{clients,0,name}'<>'Admin edited pending client' then raise exception 'Edited placeholder not preserved';end if;
 if section.data#>>'{clients,1,name}'<>'' or section.data#>>'{clients,1,image}'<>'/custom-client.svg' then raise exception 'Existing cleared name or image replaced';end if;
 if section.data#>'{clients,2}'<>'null'::jsonb or section.data#>>'{clients,3,name}'<>'' then raise exception 'Cleared slots restored';end if;
 if not (section.template#>'{clients,0}' ? 'image') then raise exception 'Image editor field missing';end if;
 select * into section from public.cms_sections where page_id='services--full-truckload-ftl' and key='sectionFive';
 if section.revision<>8 or section.data->'clients'<>'null'::jsonb then raise exception 'Missing client data restored';end if;
 select * into section from public.cms_sections where page_id='services--containerized-transportation' and key='sectionFive';
 if section.revision<>8 or section.data#>>'{clients,0,name}'<>'Admin client' or section.data#>>'{clients,0,image}'<>'/admin-logo.webp' then raise exception 'Edited name/logo lost';end if;
 if (select count(*) from public.cms_history where actor='System: service trust card fields')<>3 then raise exception 'Unexpected migration audit';end if;
end $$;
