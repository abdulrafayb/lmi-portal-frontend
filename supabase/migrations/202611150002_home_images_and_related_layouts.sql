-- Existing projects: apply Home image paths and retire related-link layouts.
-- Stored related content and other administrator edits are preserved.
begin;
create or replace function public.cms_section_active(p_page_id text,p_key text) returns boolean
language sql immutable set search_path = ''
as $$ select not (p_key='sectionSeven' and p_page_id=any(array['services--chemical-liquid-cargo-transportation','services--containerized-transportation','services--dry-cargo-transportation','services--flatbed-transportation','services--full-truckload-ftl','services--heavy-project-cargo','services--petroleum-transportation','services--road-freight-transportation','fleet-visibility--fleet-equipment','fleet-visibility--nationwide-network','fleet-visibility--shipment-tracking-operational-visibility'])) $$;
revoke all on function public.cms_section_active(text,text) from public,anon,authenticated;

create or replace function public.cms_public_page(p_page_id text) returns jsonb
language plpgsql stable security definer set search_path = ''
as $$
begin
  if not exists(select 1 from public.cms_pages where id=p_page_id) then raise sqlstate 'PT404' using message='Page not found'; end if;
  return jsonb_build_object('id',p_page_id,'sections',coalesce((
    select jsonb_object_agg(key,jsonb_build_object('enabled',enabled,'data',case when enabled then data else null end,'revision',revision))
    from public.cms_sections where page_id=p_page_id and public.cms_section_active(page_id,key)
  ),'{}'::jsonb));
end $$;

create or replace function public.cms_admin_pages() returns jsonb
language plpgsql stable security definer set search_path = ''
as $$ begin
  if not public.cms_is_admin() then raise sqlstate 'PT403' using message='Administrator access required'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id',p.id,'title',p.title,'route',p.route,'sections',(
    select jsonb_agg(s.key order by s.position) from public.cms_sections s where s.page_id=p.id and public.cms_section_active(s.page_id,s.key)
  )) order by p.position) from public.cms_pages p),'[]'::jsonb);
end $$;

create or replace function public.cms_admin_page(p_page_id text) returns jsonb
language plpgsql stable security definer set search_path = ''
as $$ begin
  if not public.cms_is_admin() then raise sqlstate 'PT403' using message='Administrator access required'; end if;
  if not exists(select 1 from public.cms_pages where id=p_page_id) then raise sqlstate 'PT404' using message='Page not found'; end if;
  return (select jsonb_build_object('id',p.id,'title',p.title,'route',p.route,'template',coalesce((select jsonb_object_agg(key,template) from public.cms_sections where page_id=p.id and public.cms_section_active(page_id,key)),'{}'::jsonb),'sections',coalesce((select jsonb_object_agg(key,jsonb_build_object('key',key,'data',data,'enabled',enabled,'revision',revision)) from public.cms_sections where page_id=p.id and public.cms_section_active(page_id,key)),'{}'::jsonb)) from public.cms_pages p where p.id=p_page_id);
end $$;

create or replace function public.cms_publish_section(p_page_id text, p_key text, p_data jsonb, p_enabled boolean, p_expected_revision integer) returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare current_section public.cms_sections%rowtype; validated jsonb; changes jsonb; published timestamptz := now();
begin
  if not public.cms_is_admin() then raise sqlstate 'PT403' using message='Administrator access required'; end if;
  if p_enabled is null or p_expected_revision is null or p_expected_revision < 0 or p_data is null or jsonb_typeof(p_data)<>'object' or pg_column_size(p_data)>1000000 then raise sqlstate 'PT400' using message='Invalid section publication'; end if;
  if not public.cms_section_active(p_page_id,p_key) then raise sqlstate 'PT404' using message='Section is no longer part of this page'; end if;
  select * into current_section from public.cms_sections where page_id=p_page_id and key=p_key for update;
  if not found then raise sqlstate 'PT404' using message='Section not found'; end if;
  if current_section.revision<>p_expected_revision then raise sqlstate 'PT409' using message='This section changed in another tab. Reload before publishing.'; end if;
  validated := public.cms_validate(current_section.template,p_data);
  changes := public.cms_diff(jsonb_build_object('data',current_section.data,'enabled',current_section.enabled),jsonb_build_object('data',validated,'enabled',p_enabled));
  if jsonb_array_length(changes)=0 then return jsonb_build_object('revision',current_section.revision,'unchanged',true); end if;
  update public.cms_sections set data=validated, enabled=p_enabled, revision=revision+1, updated_at=published where page_id=p_page_id and key=p_key;
  insert into public.cms_history(actor,actor_id,page_id,section,revision,changes) values(coalesce(auth.jwt()->>'email','admin'),auth.uid(),p_page_id,p_key,current_section.revision+1,changes);
  return jsonb_build_object('revision',current_section.revision+1,'publishedAt',published);
end $$;

do $$
declare section public.cms_sections%rowtype; new_data jsonb; new_template jsonb; changes jsonb; mapping jsonb := '{"hero": {"image": "/home/section-1-main-image.png", "imageAlt": "Trucks traveling through a mountainous highway"}, "services": ["/home/section-2-image-1.png", "/home/section-2-image-2.png", "/home/section-2-image-3.png", "/home/section-2-image-4.png", "/home/section-2-image-5.png", "/home/section-2-image-6.png", "/home/section-2-image-7.png", "/home/section-2-image-8.png"], "industries": {"0": "/home/section-8-image-1.png", "1": "/home/section-8-image-2.png", "3": "/home/section-8-image-4.png", "4": "/home/section-8-image-5.png"}, "retired": ["services--chemical-liquid-cargo-transportation", "services--containerized-transportation", "services--dry-cargo-transportation", "services--flatbed-transportation", "services--full-truckload-ftl", "services--heavy-project-cargo", "services--petroleum-transportation", "services--road-freight-transportation", "fleet-visibility--fleet-equipment", "fleet-visibility--nationwide-network", "fleet-visibility--shipment-tracking-operational-visibility"]}'::jsonb; i integer; item record;
begin
  -- Remove the layouts from portal/public APIs without deleting old records.
  for section in select * from public.cms_sections where not public.cms_section_active(page_id,key) and enabled for update loop
    update public.cms_sections set enabled=false,revision=revision+1,updated_at=now() where page_id=section.page_id and key=section.key;
    insert into public.cms_history(actor,actor_id,page_id,section,revision,changes)
    values('System: related layout retired','00000000-0000-0000-0000-000000000000'::uuid,section.page_id,section.key,section.revision+1,public.cms_diff(jsonb_build_object('enabled',true),jsonb_build_object('enabled',false)));
  end loop;
  for section in select * from public.cms_sections where page_id='home' and key in ('sectionOne','sectionFour','sectionEight') for update loop
    new_data := section.data; new_template := section.template;
    if section.key='sectionOne' then
      if not new_template ? 'image' then new_template := new_template || '{"image":null}'::jsonb; end if;
      if not new_template ? 'imageAlt' then new_template := new_template || '{"imageAlt":""}'::jsonb; end if;
      new_data := new_data || (mapping->'hero');
    elsif section.key='sectionFour' and jsonb_typeof(new_data->'services')='array' then
      for i in 0..least(jsonb_array_length(new_data->'services'),8)-1 loop
        if jsonb_typeof(new_data->'services'->i)='object' then
          new_data := jsonb_set(new_data,array['services',i::text,'image'],mapping->'services'->i,true);
        end if;
      end loop;
    elsif section.key='sectionEight' and jsonb_typeof(new_data->'industries')='array' then
      for item in select key,value from jsonb_each(mapping->'industries') loop
        i := item.key::integer;
        if i<jsonb_array_length(new_data->'industries') and jsonb_typeof(new_data->'industries'->i)='object' then
          new_data := jsonb_set(new_data,array['industries',i::text,'image'],item.value,true);
        end if;
      end loop;
    end if;
    if new_data is distinct from section.data or new_template is distinct from section.template then
      changes := public.cms_diff(jsonb_build_object('template',section.template,'data',section.data),jsonb_build_object('template',new_template,'data',new_data));
      update public.cms_sections set template=new_template,data=new_data,revision=revision+1,updated_at=now() where page_id=section.page_id and key=section.key;
      insert into public.cms_history(actor,actor_id,page_id,section,revision,changes)
      values('System: Home images updated','00000000-0000-0000-0000-000000000000'::uuid,section.page_id,section.key,section.revision+1,changes);
    end if;
  end loop;
end $$;
commit;
