\set ON_ERROR_STOP on
insert into public.cms_admin(user_id) values('11111111-1111-1111-1111-111111111111');
do $$ begin
 if (select count(*) from public.cms_pages)<>25 or (select count(*) from public.cms_sections)<>190 then raise exception 'Seed counts incorrect'; end if;
 begin insert into public.cms_admin(user_id) values('22222222-2222-2222-2222-222222222222');raise exception 'Second admin accepted';exception when unique_violation then null;end;
end $$;
begin;
set local role anon;
do $$ declare page jsonb; begin
 page:=public.cms_public_page('home');
 if not page->'sections' ? 'sectionOne' then raise exception 'Public page missing'; end if;
 if page->'sections'->'sectionOne' ? 'template' then raise exception 'Template exposed';end if;
 begin perform * from public.cms_history; raise exception 'Audit exposed';exception when insufficient_privilege then null;end;
 begin perform public.cms_admin_pages(); raise exception 'Anonymous admin access';exception when insufficient_privilege then null;end;
 begin perform public.cms_publish_section('home','sectionTen','{}',false,0);raise exception 'Anonymous write allowed';exception when insufficient_privilege then null;end;
end $$;
rollback;
begin;
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"22222222-2222-2222-2222-222222222222","email":"not-admin@example.test"}',true);
do $$ begin
 if (select count(*) from public.cms_sections)<>0 then raise exception 'Non-admin bypassed RLS';end if;
 begin perform public.cms_admin_pages();raise exception 'Non-admin read allowed';exception when sqlstate 'PT403' then null;end;
 begin perform public.cms_publish_section('home','sectionTen','{}',false,0);raise exception 'Non-admin publish allowed';exception when sqlstate 'PT403' then null;end;
end $$;
rollback;
begin;
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"11111111-1111-1111-1111-111111111111","email":"admin@example.test"}',true);
do $$ declare original jsonb; changed jsonb; result jsonb; begin
 if jsonb_array_length(public.cms_admin_pages())<>25 then raise exception 'Admin catalog unavailable';end if;
 original:=(public.cms_admin_page('home')->'sections'->'sectionTen'->'data');
 changed:=jsonb_set(original,'{heading}','"Supabase publication"');
 result:=public.cms_publish_section('home','sectionTen',changed,false,0);
 if result->>'revision'<>'1' then raise exception 'Revision not incremented';end if;
 if (public.cms_public_page('home')->'sections'->'sectionTen'->>'enabled')::boolean then raise exception 'Section not hidden';end if;
 if public.cms_public_page('home')->'sections'->'sectionTen'->'data'<>'null'::jsonb then raise exception 'Hidden content exposed';end if;
 if (public.cms_admin_history()->>'total')::integer<>1 then raise exception 'Missing atomic history';end if;
 if public.cms_admin_history()->'items'->0->>'actor'<>'admin@example.test' then raise exception 'Incorrect audit actor';end if;
 begin perform public.cms_publish_section('home','sectionTen',original,true,0);raise exception 'Stale revision accepted';exception when sqlstate 'PT409' then null;end;
 begin perform public.cms_publish_section('home','sectionTen',original||'{"layout":"new"}',true,1);raise exception 'New layout accepted';exception when sqlstate 'PT400' then null;end;
 begin perform public.cms_publish_section('home','sectionTen',jsonb_set(original,'{action,path}','"javascript:alert(1)"'),true,1);raise exception 'Unsafe URL accepted';exception when sqlstate 'PT400' then null;end;
 begin perform public.cms_publish_section('home','sectionNew',original,true,0);raise exception 'New section accepted';exception when sqlstate 'PT404' then null;end;
 begin update public.cms_sections set enabled=true where page_id='home';raise exception 'Direct write allowed';exception when insufficient_privilege then null;end;
 begin delete from public.cms_history;raise exception 'History deletion allowed';exception when insufficient_privilege then null;end;
 if (public.cms_admin_history()->>'total')::integer<>1 then raise exception 'Failed publication changed history';end if;
 -- A missing heading is valid, and website-relative image paths normalize.
 changed:=(public.cms_admin_page('hsse')->'sections'->'sectionOne'->'data')-'heading';
 changed:=jsonb_set(changed,'{image}','"/public/example.webp"');
 perform public.cms_publish_section('hsse','sectionOne',changed,true,0);
 if public.cms_public_page('hsse')->'sections'->'sectionOne'->'data'->>'image'<>'/example.webp' then raise exception 'Image normalization failed';end if;
 if public.cms_public_page('hsse')->'sections'->'sectionOne'->'data' ? 'heading' then raise exception 'Missing heading restored';end if;
end $$;
commit;
