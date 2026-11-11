-- Fixed-section CMS. Run as the project owner through migrations or SQL Editor.
create table public.cms_admin (
  singleton boolean primary key default true check (singleton),
  user_id uuid not null unique references auth.users(id) on delete restrict
);
create table public.cms_pages (
  id text primary key,
  title text not null,
  route text not null unique,
  position integer not null
);
create table public.cms_sections (
  page_id text not null references public.cms_pages(id) on delete restrict,
  key text not null,
  position integer not null,
  template jsonb not null check (jsonb_typeof(template) = 'object'),
  data jsonb not null check (jsonb_typeof(data) = 'object'),
  enabled boolean not null default true,
  revision integer not null default 0,
  updated_at timestamptz not null default now(),
  primary key (page_id, key)
);
create table public.cms_history (
  id bigint generated always as identity primary key,
  at timestamptz not null default now(),
  actor text not null,
  actor_id uuid not null,
  page_id text not null,
  section text not null,
  revision integer not null,
  changes jsonb not null,
  unique (page_id, section, revision)
);
create index cms_history_time on public.cms_history (at desc, id desc);

alter table public.cms_admin enable row level security;
alter table public.cms_pages enable row level security;
alter table public.cms_sections enable row level security;
alter table public.cms_history enable row level security;
-- No direct browser writes, including to the allowlist or audit log.
revoke all on public.cms_admin, public.cms_pages, public.cms_sections, public.cms_history from anon, authenticated;
revoke all on sequence public.cms_history_id_seq from anon, authenticated;

create function public.cms_is_admin() returns boolean
language sql stable security definer set search_path = ''
as $$ select exists(select 1 from public.cms_admin where user_id = auth.uid()) $$;
revoke all on function public.cms_is_admin() from public;
grant execute on function public.cms_is_admin() to authenticated;

-- Dashboard read policies remain restricted even if a table is queried directly.
create policy cms_pages_admin_read on public.cms_pages for select to authenticated using (public.cms_is_admin());
create policy cms_sections_admin_read on public.cms_sections for select to authenticated using (public.cms_is_admin());
create policy cms_history_admin_read on public.cms_history for select to authenticated using (public.cms_is_admin());
grant select on public.cms_pages, public.cms_sections, public.cms_history to authenticated;

-- Validate against the fixed template. Null/missing content is permitted; layout
-- attributes and existing list slots cannot be changed through publishing.
create function public.cms_validate(p_template jsonb, p_value jsonb, p_key text default '', p_location text default 'data') returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare result jsonb; item record; i integer; kind text; value_text text;
begin
  if p_value is null or p_value = 'null'::jsonb then return 'null'::jsonb; end if;
  if p_key = any(array['id','icon','variant','type','as','number']) then
    if p_value is distinct from p_template then raise sqlstate 'PT400' using message = p_location || ' is fixed by the layout'; end if;
    return p_value;
  end if;
  kind := jsonb_typeof(p_template);
  if kind = 'array' then
    if jsonb_typeof(p_value) <> 'array' then raise sqlstate 'PT400' using message = p_location || ' must be an array'; end if;
    if jsonb_array_length(p_value) <> jsonb_array_length(p_template) then raise sqlstate 'PT400' using message = p_location || ': items cannot be added or deleted'; end if;
    result := '[]'::jsonb;
    for i in 0..jsonb_array_length(p_template)-1 loop
      result := result || jsonb_build_array(public.cms_validate(p_template->i, p_value->i, '', p_location || '[' || i || ']'));
    end loop;
    return result;
  elsif kind = 'object' then
    if jsonb_typeof(p_value) <> 'object' then raise sqlstate 'PT400' using message = p_location || ' must be an object'; end if;
    result := '{}'::jsonb;
    for item in select key, value from jsonb_each(p_value) loop
      if not p_template ? item.key or item.key = any(array['__proto__','prototype','constructor']) then raise sqlstate 'PT400' using message = 'Unknown field ' || p_location || '.' || item.key; end if;
      result := result || jsonb_build_object(item.key, public.cms_validate(p_template->item.key, item.value, item.key, p_location || '.' || item.key));
    end loop;
    return result;
  end if;
  if kind = 'null' then kind := 'string'; end if;
  if jsonb_typeof(p_value) <> kind then raise sqlstate 'PT400' using message = p_location || ' has an invalid type'; end if;
  if kind = 'string' then
    value_text := p_value #>> '{}';
    if length(value_text) > 30000 then raise sqlstate 'PT400' using message = p_location || ' is too long'; end if;
    if p_key ~* '^(path|href|src|image|url|imageUrl|embedUrl)$' and value_text <> '' then
      value_text := regexp_replace(value_text, '^/public/', '/');
      if not (value_text ~ '^/[^/]' or value_text = '/' or value_text ~ '^#' or value_text ~* '^(https://|http://localhost([:/]|$)|mailto:|tel:)') or value_text ~ '[[:cntrl:]]' or value_text ~ E'\\\\' then
        raise sqlstate 'PT400' using message = p_location || ' must be a website path or safe URL';
      end if;
      return to_jsonb(value_text);
    end if;
  end if;
  return p_value;
end $$;
revoke all on function public.cms_validate(jsonb,jsonb,text,text) from public, anon, authenticated;

create function public.cms_diff(p_before jsonb, p_after jsonb, p_path text default '') returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare result jsonb := '[]'::jsonb; k text; i integer;
begin
  if p_before is not distinct from p_after then return result; end if;
  if jsonb_typeof(p_before) = 'object' and jsonb_typeof(p_after) = 'object' then
    for k in select key from jsonb_object_keys(p_before || p_after) as keys(key) loop
      result := result || public.cms_diff(p_before->k,p_after->k,case when p_path = '' then k else p_path || '.' || k end);
    end loop;
    return result;
  elsif jsonb_typeof(p_before) = 'array' and jsonb_typeof(p_after) = 'array' then
    for i in 0..greatest(jsonb_array_length(p_before),jsonb_array_length(p_after))-1 loop
      result := result || public.cms_diff(p_before->i,p_after->i,p_path || '.' || i);
    end loop;
    return result;
  end if;
  return jsonb_build_array(jsonb_build_object('field',p_path,'before',p_before,'after',p_after));
end $$;
revoke all on function public.cms_diff(jsonb,jsonb,text) from public, anon, authenticated;

-- The only anonymous API. No templates, history or hidden section content leak.
create function public.cms_public_page(p_page_id text) returns jsonb
language plpgsql stable security definer set search_path = ''
as $$
begin
  if not exists(select 1 from public.cms_pages where id=p_page_id) then raise sqlstate 'PT404' using message='Page not found'; end if;
  return jsonb_build_object('id',p_page_id,'sections',coalesce((
    select jsonb_object_agg(key,jsonb_build_object('enabled',enabled,'data',case when enabled then data else null end,'revision',revision))
    from public.cms_sections where page_id=p_page_id
  ),'{}'::jsonb));
end $$;
revoke all on function public.cms_public_page(text) from public;
grant execute on function public.cms_public_page(text) to anon, authenticated;

create function public.cms_admin_me() returns jsonb
language plpgsql stable security definer set search_path = ''
as $$ begin
  if not public.cms_is_admin() then raise sqlstate 'PT403' using message='Administrator access required'; end if;
  return jsonb_build_object('username',auth.jwt()->>'email');
end $$;
create function public.cms_admin_pages() returns jsonb
language plpgsql stable security definer set search_path = ''
as $$ begin
  if not public.cms_is_admin() then raise sqlstate 'PT403' using message='Administrator access required'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id',p.id,'title',p.title,'route',p.route,'sections',(
    select jsonb_agg(s.key order by s.position) from public.cms_sections s where s.page_id=p.id
  )) order by p.position) from public.cms_pages p),'[]'::jsonb);
end $$;
create function public.cms_admin_page(p_page_id text) returns jsonb
language plpgsql stable security definer set search_path = ''
as $$ begin
  if not public.cms_is_admin() then raise sqlstate 'PT403' using message='Administrator access required'; end if;
  if not exists(select 1 from public.cms_pages where id=p_page_id) then raise sqlstate 'PT404' using message='Page not found'; end if;
  return (select jsonb_build_object('id',p.id,'title',p.title,'route',p.route,'template',coalesce((select jsonb_object_agg(key,template) from public.cms_sections where page_id=p.id),'{}'::jsonb),'sections',coalesce((select jsonb_object_agg(key,jsonb_build_object('key',key,'data',data,'enabled',enabled,'revision',revision)) from public.cms_sections where page_id=p.id),'{}'::jsonb)) from public.cms_pages p where p.id=p_page_id);
end $$;
create function public.cms_publish_section(p_page_id text, p_key text, p_data jsonb, p_enabled boolean, p_expected_revision integer) returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare current_section public.cms_sections%rowtype; validated jsonb; changes jsonb; published timestamptz := now();
begin
  if not public.cms_is_admin() then raise sqlstate 'PT403' using message='Administrator access required'; end if;
  if p_enabled is null or p_expected_revision is null or p_expected_revision < 0 or p_data is null or jsonb_typeof(p_data)<>'object' or pg_column_size(p_data)>1000000 then raise sqlstate 'PT400' using message='Invalid section publication'; end if;
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
create function public.cms_admin_history(p_page integer default 1,p_page_id text default null) returns jsonb
language plpgsql stable security definer set search_path = ''
as $$
declare page_number integer := greatest(1,least(100000,coalesce(p_page,1)));
begin
  if not public.cms_is_admin() then raise sqlstate 'PT403' using message='Administrator access required'; end if;
  return jsonb_build_object('page',page_number,'pageSize',20,'total',(select count(*) from public.cms_history where p_page_id is null or page_id=p_page_id),'items',coalesce((select jsonb_agg(to_jsonb(events) order by events.at desc, events._id desc) from (select id as _id,at,actor,page_id as "pageId",section,revision,changes from public.cms_history where p_page_id is null or page_id=p_page_id order by at desc,id desc limit 20 offset (page_number-1)*20) events),'[]'::jsonb));
end $$;
revoke all on function public.cms_admin_me(), public.cms_admin_pages(), public.cms_admin_page(text), public.cms_publish_section(text,text,jsonb,boolean,integer), public.cms_admin_history(integer,text) from public, anon;
grant execute on function public.cms_admin_me(), public.cms_admin_pages(), public.cms_admin_page(text), public.cms_publish_section(text,text,jsonb,boolean,integer), public.cms_admin_history(integer,text) to authenticated;
