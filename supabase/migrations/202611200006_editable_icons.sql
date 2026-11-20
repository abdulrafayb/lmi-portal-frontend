-- Optional icon overrides; preserves original semantic keys, content and history.
begin;
create or replace function public.cms_validate(p_template jsonb, p_value jsonb, p_key text default '', p_location text default 'data') returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare result jsonb; item record; i integer; kind text; value_text text; candidate jsonb; validated jsonb; matched boolean; failure text;
begin
  if p_value is null or p_value = 'null'::jsonb then return 'null'::jsonb; end if;
  if p_key = any(array['id','icon','variant','type','as','number']) then
    if p_value is distinct from p_template then raise sqlstate 'PT400' using message = p_location || ' is fixed by the layout'; end if;
    return p_value;
  end if;
  kind := jsonb_typeof(p_template);
  if kind = 'array' then
    if jsonb_typeof(p_value) <> 'array' then raise sqlstate 'PT400' using message = p_location || ' must be an array'; end if;
    if p_key = any(array['actions','fields']) or p_key ~* 'heading$' then
      if jsonb_array_length(p_value) <> jsonb_array_length(p_template) then raise sqlstate 'PT400' using message = p_location || ': layout items are fixed'; end if;
      result := '[]'::jsonb;
      for i in 0..jsonb_array_length(p_value)-1 loop
        result := result || jsonb_build_array(public.cms_validate(p_template->i,p_value->i,'',p_location || '[' || i || ']'));
      end loop;
      return result;
    end if;
    if jsonb_array_length(p_value)>50 then raise sqlstate 'PT400' using message = p_location || ': use up to 50 items'; end if;
    result := '[]'::jsonb;
    for i in 0..jsonb_array_length(p_value)-1 loop
      matched := false;
      failure := p_location || ': unsupported item';
      for candidate in select value from jsonb_array_elements(p_template) loop
        begin
          validated := public.cms_validate(candidate,p_value->i,'',p_location || '[' || i || ']');
          matched := true;
          exit;
        exception when sqlstate 'PT400' then
          get stacked diagnostics failure = message_text;
        end;
      end loop;
      if not matched then raise sqlstate 'PT400' using message = failure; end if;
      result := result || jsonb_build_array(validated);
    end loop;
    return result;
  elsif kind = 'object' then
    if jsonb_typeof(p_value) <> 'object' then raise sqlstate 'PT400' using message = p_location || ' must be an object'; end if;
    result := '{}'::jsonb;
    for item in select key, value from jsonb_each(p_value) loop
      if item.key = 'iconOverride' and p_template ? 'icon' then
        if jsonb_typeof(item.value) is distinct from 'string' or not ((item.value #>> '{}') = any(array['','icon:truck','icon:shield-check','icon:users','icon:map-pin','icon:clipboard','icon:chart','icon:gear','icon:stack','icon:cube','icon:drop','icon:wrench','icon:buildings','icon:factory','icon:globe','icon:clock','icon:check','icon:certificate','icon:medal','icon:handshake','icon:leaf','icon:lightning','icon:scales','icon:road','icon:compass','icon:target','icon:phone','icon:envelope','icon:calendar','icon:warning','icon:arrows-clockwise'])) then raise sqlstate 'PT400' using message = 'Unsupported icon'; end if;
        result := result || jsonb_build_object(item.key,item.value);
        continue;
      end if;
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

commit;
