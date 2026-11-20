-- Add editable red category headers while preserving edited service copy/links.
begin;
do $$ declare s public.cms_sections%rowtype; updated jsonb; tpl jsonb; i integer;
labels jsonb := '["Packaged & Industrial Goods", "Petroleum & Fuel", "Chemicals & Liquids", "Containers & Port Cargo", "Full Loads", "Machinery & Oversized Loads"]'::jsonb;
begin
 select * into strict s from public.cms_sections where page_id='services' and key='sectionThree' for update;
 updated:=s.data;tpl:=s.template;
 for i in 0..5 loop
  if jsonb_typeof(tpl#>array['cards',i::text])='object' and not (tpl#>array['cards',i::text]) ? 'category' then tpl:=jsonb_set(tpl,array['cards',i::text,'category'],'""');end if;
  if jsonb_typeof(updated#>array['cards',i::text])='object' and updated#>array['cards',i::text]<>'{}'::jsonb and not (updated#>array['cards',i::text]) ? 'category' then updated:=jsonb_set(updated,array['cards',i::text,'category'],labels->i);end if;
 end loop;
 if updated is distinct from s.data or tpl is distinct from s.template then
  update public.cms_sections set data=updated,template=tpl,revision=revision+1,updated_at=now() where page_id=s.page_id and key=s.key;
  insert into public.cms_history(actor,actor_id,page_id,section,revision,changes) values('System: Service category headers','00000000-0000-0000-0000-000000000000',s.page_id,s.key,s.revision+1,public.cms_diff(jsonb_build_object('data',s.data,'template',s.template),jsonb_build_object('data',updated,'template',tpl)));
 end if;
end $$;
commit;
