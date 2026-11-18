do $$ declare d jsonb; i integer;
begin
 select data into strict d from public.cms_sections where page_id='company--about-us' and key='sectionSix';
 for i in 0..6 loop
  if d#>>array['partners',i::text,'image'] is distinct from '/our-company/about-us/logo-'||(i+1)||'.png' then raise exception 'Incorrect partner image %',i; end if;
 end loop;
 if d#>>'{partners,0,name}'<>'Edited partner' or d#>'{partners,7}'<>'{}'::jsonb then raise exception 'Edited text or cleared card changed'; end if;
 if exists(select 1 from public.cms_sections where page_id='company--about-us' and key='sectionSix' and (enabled or revision<>61)) then raise exception 'Visibility/revision changed'; end if;
 if (select count(*) from public.cms_history where actor='System: About Us partner logos added')<>1 then raise exception 'Not idempotent'; end if;
end $$;
