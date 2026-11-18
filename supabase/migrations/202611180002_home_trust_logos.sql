-- Add the five supplied Home trust-strip logos without resetting names/visibility.
begin;
do $$
declare section public.cms_sections%rowtype; new_data jsonb; i integer;
paths jsonb := '["/home/shell-logo.png", "/home/pso_logo.png", "/home/caltex-logo.png", "/home/engro-logo.png", "/home/nlc_logo.png"]'::jsonb;
begin
 select * into strict section from public.cms_sections where page_id='home' and key='sectionTwo' for update;
 new_data := section.data;
 if jsonb_typeof(section.data->'logos')='array' then
   for i in 0..least(jsonb_array_length(section.data->'logos'),5)-1 loop
     if jsonb_typeof(section.data->'logos'->i)='object' and section.data->'logos'->i<>'{}'::jsonb then
       new_data := jsonb_set(new_data,array['logos',i::text,'src'],paths->i);
     end if;
   end loop;
 end if;
 if new_data is distinct from section.data then
   update public.cms_sections set data=new_data,revision=revision+1,updated_at=now() where page_id=section.page_id and key=section.key;
   insert into public.cms_history(actor,actor_id,page_id,section,revision,changes)
   values('System: Home trust logos added','00000000-0000-0000-0000-000000000000'::uuid,section.page_id,section.key,section.revision+1,public.cms_diff(section.data,new_data));
 end if;
end $$;
commit;
