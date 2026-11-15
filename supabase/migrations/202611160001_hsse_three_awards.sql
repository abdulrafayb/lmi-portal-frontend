-- Retire the fourth (Shell) award slot; keep current edits to the first three.
begin;
do $$ declare section public.cms_sections%rowtype; new_template jsonb; new_data jsonb;
begin
 select * into strict section from public.cms_sections where page_id='hsse' and key='sectionEight' for update;
 new_template := section.template; new_data := section.data;
 if jsonb_array_length(section.template->'awards')=4 then
   new_template := jsonb_set(section.template,'{awards}',(section.template->'awards') - 3);
   if jsonb_typeof(section.data->'awards')='array' then
     if jsonb_array_length(section.data->'awards')<>4 then raise exception 'Expected four fixed awards before migration';end if;
     new_data := jsonb_set(section.data,'{awards}',(section.data->'awards') - 3);
   end if;
   update public.cms_sections set template=new_template,data=new_data,revision=revision+1,updated_at=now() where page_id=section.page_id and key=section.key;
   insert into public.cms_history(actor,actor_id,page_id,section,revision,changes)
   values('System: Shell award slot retired','00000000-0000-0000-0000-000000000000'::uuid,section.page_id,section.key,section.revision+1,public.cms_diff(jsonb_build_object('template',section.template,'data',section.data),jsonb_build_object('template',new_template,'data',new_data)));
 elsif jsonb_array_length(section.template->'awards')<>3 then
   raise exception 'Unexpected HSSE awards layout';
 end if;
end $$;
commit;
