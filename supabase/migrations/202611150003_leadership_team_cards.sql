-- Move the CEO into the fixed six-card team layout. Preserves existing edited team cards and CEO portrait.
begin;
create or replace function public.cms_section_active(p_page_id text,p_key text) returns boolean
language sql immutable set search_path = ''
as $$ select not ((p_page_id='company--leadership' and p_key='sectionThree') or (p_key='sectionSeven' and p_page_id=any(array['services--chemical-liquid-cargo-transportation','services--containerized-transportation','services--dry-cargo-transportation','services--flatbed-transportation','services--full-truckload-ftl','services--heavy-project-cargo','services--petroleum-transportation','services--road-freight-transportation','fleet-visibility--fleet-equipment','fleet-visibility--nationwide-network','fleet-visibility--shipment-tracking-operational-visibility']))) $$;
revoke all on function public.cms_section_active(text,text) from public,anon,authenticated;

do $$
declare team public.cms_sections%rowtype; executive public.cms_sections%rowtype; new_data jsonb; new_template jsonb; member jsonb; changes jsonb;
begin
 select * into executive from public.cms_sections where page_id='company--leadership' and key='sectionThree' for update;
 select * into strict team from public.cms_sections where page_id='company--leadership' and key='sectionFour' for update;
 new_template := team.template;
 new_data := team.data;
 if jsonb_array_length(team.template->'members')=5 then
   new_template := jsonb_set(team.template,'{members}',jsonb_build_array(team.template->'members'->0) || (team.template->'members'));
   member := jsonb_build_object('name','Brig. (R) Shahid Mahmood','initials','SM','role','Chief Executive Officer','image',executive.data->'image');
   if not (team.data ? 'members') or team.data->'members'='null'::jsonb then
     new_data := jsonb_set(team.data,'{members}',jsonb_build_array(member) || '[{},{},{},{},{}]'::jsonb);
   elsif jsonb_typeof(team.data->'members')='array' and jsonb_array_length(team.data->'members')=5 then
     new_data := jsonb_set(team.data,'{members}',jsonb_build_array(member) || (team.data->'members'));
   else
     raise exception 'Leadership team must contain the original five fixed cards before migration';
   end if;
   changes := public.cms_diff(jsonb_build_object('template',team.template,'data',team.data),jsonb_build_object('template',new_template,'data',new_data));
   update public.cms_sections set template=new_template,data=new_data,revision=revision+1,updated_at=now() where page_id=team.page_id and key=team.key;
   insert into public.cms_history(actor,actor_id,page_id,section,revision,changes) values('System: six-card leadership layout','00000000-0000-0000-0000-000000000000'::uuid,team.page_id,team.key,team.revision+1,changes);
 elsif jsonb_array_length(team.template->'members')<>6 then
   raise exception 'Unexpected leadership team layout';
 end if;
 if executive.enabled then
   update public.cms_sections set enabled=false,revision=revision+1,updated_at=now() where page_id=executive.page_id and key=executive.key;
   insert into public.cms_history(actor,actor_id,page_id,section,revision,changes) values('System: executive layout retired','00000000-0000-0000-0000-000000000000'::uuid,executive.page_id,executive.key,executive.revision+1,public.cms_diff(jsonb_build_object('enabled',true),jsonb_build_object('enabled',false)));
 end if;
end $$;
commit;
