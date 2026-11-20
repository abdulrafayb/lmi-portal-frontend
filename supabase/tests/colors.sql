begin;
set local role anon;
do $$ begin
 if public.cms_public_colors()->>'brand-red' is null then raise exception 'Public palette missing';end if;
 begin perform public.cms_admin_colors();raise exception 'Anonymous read admin colors';exception when insufficient_privilege then null;end;
 begin perform * from public.cms_colors;raise exception 'Direct palette exposed';exception when insufficient_privilege then null;end;
end $$;
rollback;
begin;
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"22222222-2222-2222-2222-222222222222"}',true);
do $$ begin
 begin perform public.cms_save_colors('{}',0);raise exception 'Non-admin saved colors';exception when sqlstate 'PT403' then null;end;
end $$;
rollback;
begin;
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"11111111-1111-1111-1111-111111111111","email":"admin@example.test"}',true);
do $$ declare p jsonb;result jsonb;begin
 p:=public.cms_admin_colors()->'colors';
 result:=public.cms_save_colors(p,0);if result->>'unchanged'<>'true' then raise exception 'Unchanged save audited';end if;
 p:=jsonb_set(p,'{brand-red}','"#123456"');result:=public.cms_save_colors(p,0);
 if public.cms_public_colors()->>'brand-red'<>'#123456' then raise exception 'Saved color missing';end if;
 begin perform public.cms_save_colors(p,0);raise exception 'Stale save allowed';exception when sqlstate 'PT409' then null;end;
 begin perform public.cms_save_colors(jsonb_set(p,'{brand-red}','"red;display:none"'),1);raise exception 'CSS injection accepted';exception when sqlstate 'PT400' then null;end;
 begin perform public.cms_save_colors(p-'surface',1);raise exception 'Incomplete palette accepted';exception when sqlstate 'PT400' then null;end;
 if (select count(*) from public.cms_history where page_id='site' and section='colors')<>1 then raise exception 'Palette history missing';end if;
end $$;
rollback;
