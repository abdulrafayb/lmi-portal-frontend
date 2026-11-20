do $$ declare s public.cms_sections%rowtype;begin
 select * into s from public.cms_sections where page_id='services' and key='sectionThree';
 if s.enabled or s.revision<>101 or s.data#>>'{cards,0,heading}'<>'Edited cargo copy' or s.data#>>'{cards,0,category}'<>'Custom category' then raise exception 'Edited data/visibility changed';end if;
 if s.data#>>'{cards,1,category}'<>'Petroleum & Fuel' or s.data#>'{cards,5}'<>'{}'::jsonb then raise exception 'Default header or cleared slot incorrect';end if;
 if (select count(*) from public.cms_history where actor='System: Service category headers')<>1 then raise exception 'Category migration not idempotent';end if;
 perform public.cms_validate(s.template,s.data);
end $$;
