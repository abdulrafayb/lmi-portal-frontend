-- Set the newly supplied Manufacturing & Industrial image without resetting copy or visibility.
begin;
do $$ declare section public.cms_sections%rowtype; new_data jsonb;
begin
 select * into strict section from public.cms_sections where page_id='home' and key='sectionEight' for update;
 if jsonb_typeof(section.data#>'{industries,2}')='object' and section.data#>'{industries,2}'<>'{}'::jsonb then
   new_data := jsonb_set(section.data,'{industries,2,image}','"/home/section-8-image-3.png"'::jsonb);
   if new_data is distinct from section.data then
     update public.cms_sections set data=new_data,revision=revision+1,updated_at=now() where page_id=section.page_id and key=section.key;
     insert into public.cms_history(actor,actor_id,page_id,section,revision,changes)
     values('System: Home manufacturing image added','00000000-0000-0000-0000-000000000000'::uuid,section.page_id,section.key,section.revision+1,public.cms_diff(section.data,new_data));
   end if;
 end if;
end $$;
commit;
