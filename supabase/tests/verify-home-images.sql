\set ON_ERROR_STOP on
do $$ declare section public.cms_sections%rowtype; i integer;
begin
 select * into section from public.cms_sections where page_id='home' and key='sectionOne';
 if section.data->>'heading'<>'Admin edited Home title preserved' or section.enabled then raise exception 'Home text/visibility changed';end if;
 if section.data->>'image'<>'/home/section-1-main-image.png' or not section.template ? 'image' or not section.template ? 'imageAlt' then raise exception 'Hero image schema/data missing';end if;
 if section.revision<>10 then raise exception 'Migration is not idempotent';end if;
 select * into section from public.cms_sections where page_id='home' and key='sectionFour';
 for i in 0..7 loop
  if section.data->'services'->i->>'image'<>('/home/section-2-image-'||(i+1)||'.png') then raise exception 'Service image mismatch';end if;
 end loop;
 select * into section from public.cms_sections where page_id='home' and key='sectionEight';
 if section.data->'industries'->2->>'image'<>'/custom-manufacturing.webp' then raise exception 'Existing manufacturing image changed';end if;
 if section.data->'industries'->3->>'image'<>'/home/section-8-image-4.png' then raise exception 'Construction image missing';end if;
 if not exists(select 1 from public.cms_sections where page_id='services--flatbed-transportation' and key='sectionSeven' and not enabled and data->>'heading'='Admin edited related content') then raise exception 'Retired content lost';end if;
 if public.cms_public_page('services--flatbed-transportation')->'sections' ? 'sectionSeven' then raise exception 'Retired section public';end if;
 if (select count(*) from public.cms_history where actor='System: Home images updated')<>3 then raise exception 'Image migration not audited or duplicated';end if;
 if (select count(*) from public.cms_history where actor='System: related layout retired')<>1 then raise exception 'Retirement not audited';end if;
end $$;
begin;
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"11111111-1111-1111-1111-111111111111","email":"admin@example.test"}',true);
do $$ begin
 if public.cms_admin_page('services--flatbed-transportation')->'template' ? 'sectionSeven' then raise exception 'Retired section in portal';end if;
 begin perform public.cms_publish_section('services--flatbed-transportation','sectionSeven','{"heading":"Try to restore"}',true,4);raise exception 'Retired section restored';exception when sqlstate 'PT404' then null;end;
end $$;
commit;
