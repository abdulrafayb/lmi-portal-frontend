-- Existing projects: run this once in SQL Editor after the initial CMS migration.
-- Joins current edited heading lines; never restores original/seed content.
begin;
create or replace function public.cms_migrate_heading_text(p_value jsonb) returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare result jsonb; item record; joined text;
begin
  if jsonb_typeof(p_value)='object' then
    result := '{}'::jsonb;
    for item in select key,value from jsonb_each(p_value) loop
      if item.key ~* 'heading$' and jsonb_typeof(item.value)='array' and not exists(select 1 from jsonb_array_elements(item.value) part where jsonb_typeof(part) not in ('string','null')) then
        select coalesce(string_agg(btrim(part #>> '{}'),' ' order by ordinal),'') into joined
        from jsonb_array_elements(item.value) with ordinality as parts(part,ordinal)
        where jsonb_typeof(part)='string' and btrim(part #>> '{}')<>'';
        result := result || jsonb_build_object(item.key,joined);
      else
        result := result || jsonb_build_object(item.key,public.cms_migrate_heading_text(item.value));
      end if;
    end loop;
    return result;
  elsif jsonb_typeof(p_value)='array' then
    return coalesce((select jsonb_agg(public.cms_migrate_heading_text(value) order by ordinal) from jsonb_array_elements(p_value) with ordinality as items(value,ordinal)),'[]'::jsonb);
  end if;
  return p_value;
end $$;
revoke all on function public.cms_migrate_heading_text(jsonb) from public,anon,authenticated;

do $$
declare section public.cms_sections%rowtype; new_template jsonb; new_data jsonb; changes jsonb;
begin
  for section in select * from public.cms_sections for update loop
    new_template := public.cms_migrate_heading_text(section.template);
    new_data := public.cms_migrate_heading_text(section.data);
    if new_template is distinct from section.template or new_data is distinct from section.data then
      changes := public.cms_diff(jsonb_build_object('template',section.template,'data',section.data),jsonb_build_object('template',new_template,'data',new_data));
      update public.cms_sections set template=new_template,data=new_data,revision=revision+1,updated_at=now() where page_id=section.page_id and key=section.key;
      insert into public.cms_history(actor,actor_id,page_id,section,revision,changes)
      values('System: single-heading migration','00000000-0000-0000-0000-000000000000'::uuid,section.page_id,section.key,section.revision+1,changes);
    end if;
  end loop;
end $$;
drop function public.cms_migrate_heading_text(jsonb);
commit;
