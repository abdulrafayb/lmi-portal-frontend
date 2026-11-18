-- Public API exposes only published posts. Admin APIs use optimistic revisions.
do $$ begin
 if jsonb_array_length(public.cms_public_posts())<>9 then raise exception 'Expected nine samples';end if;
 if (select count(*) from public.cms_posts)<>9 then raise exception 'Migration duplicated samples';end if;
 if (select file_size_limit from storage.buckets where id='cms-media')<>10485760 then raise exception 'Wrong upload limit';end if;
end $$;
begin;
set local role anon;
do $$ begin
 if jsonb_array_length(public.cms_public_posts())<>9 then raise exception 'Anonymous listing failed';end if;
 begin perform * from public.cms_posts;raise exception 'Direct posts exposed';exception when insufficient_privilege then null;end;
 begin perform public.cms_save_post('{}');raise exception 'Anonymous saved';exception when insufficient_privilege then null;end;
 begin insert into storage.objects(bucket_id,name) values('cms-media','images/anon.png');raise exception 'Anonymous uploaded';exception when insufficient_privilege then null;end;
end $$;
rollback;
begin;
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"22222222-2222-2222-2222-222222222222"}',true);
do $$ begin
 if (select count(*) from public.cms_posts)<>0 then raise exception 'Non-admin read drafts';end if;
 begin perform public.cms_save_post('{}');raise exception 'Non-admin saved';exception when sqlstate 'PT403' then null;end;
 begin insert into storage.objects(bucket_id,name) values('cms-media','images/other.png');raise exception 'Non-admin uploaded';exception when insufficient_privilege then null;end;
end $$;
rollback;
begin;
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"11111111-1111-1111-1111-111111111111","email":"admin@example.test"}',true);
do $$ declare p jsonb; saved jsonb; post_identifier uuid; begin
 select to_jsonb(t) into p from public.cms_posts t where kind='blog' limit 1;
 p:=p||'{"slug":"admin-draft-test","status":"draft"}';
 saved:=public.cms_save_post(p);post_identifier:=(saved->>'id')::uuid;
 if jsonb_array_length(public.cms_public_posts())<>9 then raise exception 'Draft leaked';end if;
 saved:=public.cms_save_post(p||'{"status":"published"}',post_identifier,1);
 if jsonb_array_length(public.cms_public_posts())<>10 then raise exception 'Publication missing';end if;
 begin perform public.cms_save_post(p,post_identifier,1);raise exception 'Stale save accepted';exception when sqlstate 'PT409' then null;end;
 begin perform public.cms_save_post(p||'{"content":{"type":"doc","content":[{"type":"script"}]}}');raise exception 'Script accepted';exception when sqlstate 'PT400' then null;end;
 begin perform public.cms_save_post(p||'{"content":{"type":"doc","content":[{"type":"paragraph","content":[{"type":"text","text":"Unsafe","marks":[{"type":"link","attrs":{"href":"javascript:alert(1)"}}]}]}]}}');raise exception 'Unsafe link accepted';exception when sqlstate 'PT400' then null;end;
 begin perform public.cms_save_post(p||'{"status":"published","content":{"type":"doc","content":[{"type":"paragraph"}]}}');raise exception 'Empty body published';exception when sqlstate 'PT400' then null;end;
 begin perform public.cms_save_post(p||'{"slug":"../bad"}');raise exception 'Bad slug accepted';exception when check_violation then null;end;
 begin perform public.cms_save_post(p);raise exception 'Duplicate slug accepted';exception when unique_violation then null;end;
 perform public.cms_save_post(p,post_identifier,2);
 if jsonb_array_length(public.cms_public_posts())<>9 then raise exception 'Unpublish failed';end if;
 if (select count(*) from public.cms_post_history where post_id=post_identifier)<>3 then raise exception 'Missing history';end if;
 insert into storage.objects(bucket_id,name) values('cms-media','images/admin.png');
 begin insert into storage.objects(bucket_id,name) values('cms-media','wrong.png');raise exception 'Wrong prefix accepted';exception when insufficient_privilege then null;end;
end $$;
rollback;
