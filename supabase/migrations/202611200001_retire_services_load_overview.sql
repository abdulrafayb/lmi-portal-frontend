-- Retire the Services overview At a Glance section without deleting content/history.
begin;
create or replace function public.cms_section_active(p_page_id text,p_key text) returns boolean
language sql immutable set search_path = ''
as $$ select not ((p_page_id='hsse' and p_key='sectionTen') or (p_page_id='fleet-visibility--shipment-tracking-operational-visibility' and p_key='sectionFive') or (p_page_id='industries' and p_key='sectionFour') or (p_page_id='services' and p_key in ('sectionTwo','sectionFive')) or (p_page_id='company--leadership' and p_key='sectionThree') or (p_key='sectionSeven' and p_page_id=any(array['services--chemical-liquid-cargo-transportation','services--containerized-transportation','services--dry-cargo-transportation','services--flatbed-transportation','services--full-truckload-ftl','services--heavy-project-cargo','services--petroleum-transportation','services--road-freight-transportation','fleet-visibility--fleet-equipment','fleet-visibility--nationwide-network','fleet-visibility--shipment-tracking-operational-visibility']))) $$;
revoke all on function public.cms_section_active(text,text) from public,anon,authenticated;
do $$ declare section public.cms_sections%rowtype;
begin
 select * into section from public.cms_sections where page_id='services' and key='sectionFive' for update;
 if section.enabled then
   update public.cms_sections set enabled=false,revision=revision+1,updated_at=now() where page_id=section.page_id and key=section.key;
   insert into public.cms_history(actor,actor_id,page_id,section,revision,changes)
   values('System: Services load overview retired','00000000-0000-0000-0000-000000000000'::uuid,section.page_id,section.key,section.revision+1,public.cms_diff(jsonb_build_object('enabled',true),jsonb_build_object('enabled',false)));
 end if;
end $$;
commit;
