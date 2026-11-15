\set ON_ERROR_STOP on
do $$ declare current_section public.cms_sections%rowtype; begin
 select * into current_section from public.cms_sections where page_id='home' and key='sectionOne';
 if current_section.data->>'heading'<>'Custom edited heading text preserved' then raise exception 'Edited content lost';end if;
 if jsonb_typeof(current_section.template->'heading')<>'string' then raise exception 'Heading is not a single field';end if;
 if current_section.enabled or current_section.revision<>8 then raise exception 'Visibility/revision not preserved correctly';end if;
 if (select count(*) from public.cms_history)<>3 then raise exception 'Migration duplicated or lost history';end if;
 if not exists(select 1 from public.cms_history where actor='System: single-heading migration' and page_id='home' and section='sectionOne') then raise exception 'Migration not audited';end if;
end $$;
begin;
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"11111111-1111-1111-1111-111111111111","email":"admin@example.test"}',true);
do $$ declare content jsonb; begin
 content:=public.cms_admin_page('home')->'sections'->'sectionOne'->'data';
 begin perform public.cms_publish_section('home','sectionOne',content,false,7);raise exception 'Stale editor revision accepted';exception when sqlstate 'PT409' then null;end;
 content:=jsonb_set(content,'{heading}','"One editable heading"');
 perform public.cms_publish_section('home','sectionOne',content,false,8);
 if public.cms_admin_page('home')->'sections'->'sectionOne'->'data'->>'heading'<>'One editable heading' then raise exception 'Single-field publication failed';end if;
end $$;
commit;
