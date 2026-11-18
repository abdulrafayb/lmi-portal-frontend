-- Rename the Home publication teaser, preserving custom copy and visibility.
begin;
do $$ declare s public.cms_sections%rowtype; updated jsonb;
begin
 select * into strict s from public.cms_sections where page_id='home' and key='sectionNine' for update;
 updated:=s.data;
 if lower(updated#>>'{insights,eyebrow}')='insights' then updated:=jsonb_set(updated,'{insights,eyebrow}','"Articles"');end if;
 if lower(updated#>>'{insights,action,label}')='view all insights' then updated:=jsonb_set(updated,'{insights,action,label}','"View all articles"');end if;
 if updated is distinct from s.data then
  update public.cms_sections set data=updated,revision=revision+1,updated_at=now() where page_id=s.page_id and key=s.key;
  insert into public.cms_history(actor,actor_id,page_id,section,revision,changes) values('System: Home article labels','00000000-0000-0000-0000-000000000000',s.page_id,s.key,s.revision+1,public.cms_diff(s.data,updated));
 end if;
end $$;
commit;
