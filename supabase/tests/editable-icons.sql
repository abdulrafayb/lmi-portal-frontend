begin;
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"11111111-1111-1111-1111-111111111111","email":"admin@example.test"}',true);
do $$ declare s public.cms_sections%rowtype; p jsonb; r jsonb; original text;
begin
 select * into s from public.cms_sections where page_id='home' and key='sectionThree';original:=s.data#>>'{items,0,icon}';
 p:=jsonb_set(s.data,'{items,0,iconOverride}','"icon:truck"');r:=public.cms_publish_section(s.page_id,s.key,p,true,s.revision);
 if (select data#>>'{items,0,icon}' from public.cms_sections where page_id=s.page_id and key=s.key)<>original then raise exception 'Semantic identity changed';end if;
 if (select data#>>'{items,0,iconOverride}' from public.cms_sections where page_id=s.page_id and key=s.key)<>'icon:truck' then raise exception 'Icon not saved';end if;
 select * into s from public.cms_sections where page_id='home' and key='sectionThree';
 begin perform public.cms_publish_section(s.page_id,s.key,jsonb_set(s.data,'{items,0,iconOverride}','"invalid"'),true,s.revision);raise exception 'Unknown icon accepted';exception when sqlstate 'PT400' then null;end;
 begin perform public.cms_publish_section(s.page_id,s.key,jsonb_set(s.data,'{items,0,iconOverride}','123'),true,s.revision);raise exception 'Nontext icon accepted';exception when sqlstate 'PT400' then null;end;
 r:=public.cms_publish_section(s.page_id,s.key,jsonb_set(s.data,'{items,0,iconOverride}','""'),true,s.revision);
 if (select data#>>'{items,0,iconOverride}' from public.cms_sections where page_id=s.page_id and key=s.key)<>'' then raise exception 'Default reset failed';end if;
 if not exists(select 1 from public.cms_history where page_id=s.page_id and section=s.key and changes::text like '%iconOverride%') then raise exception 'Icon not audited';end if;
 select * into s from public.cms_sections where page_id='home' and key='sectionOne';
 begin perform public.cms_publish_section(s.page_id,s.key,s.data||'{"iconOverride":"icon:truck"}',true,s.revision);raise exception 'Icon allowed on non-icon section';exception when sqlstate 'PT400' then null;end;
end $$;
rollback;
