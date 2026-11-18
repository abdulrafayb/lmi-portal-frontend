-- Add the eight supplied About Us partner logos without resetting names/visibility.
begin;
do $$
declare section public.cms_sections%rowtype; new_data jsonb; i integer;
paths jsonb := '["/our-company/about-us/logo-1.png", "/our-company/about-us/logo-2.png", "/our-company/about-us/logo-3.png", "/our-company/about-us/logo-4.png", "/our-company/about-us/logo-5.png", "/our-company/about-us/logo-6.png", "/our-company/about-us/logo-7.png", "/our-company/about-us/logo-8.png"]'::jsonb;
begin
 select * into strict section from public.cms_sections where page_id='company--about-us' and key='sectionSix' for update;
 new_data := section.data;
 if jsonb_typeof(section.data->'partners')='array' then
   for i in 0..least(jsonb_array_length(section.data->'partners'),8)-1 loop
     if jsonb_typeof(section.data->'partners'->i)='object' and section.data->'partners'->i<>'{}'::jsonb then
       new_data := jsonb_set(new_data,array['partners',i::text,'image'],paths->i);
     end if;
   end loop;
 end if;
 if new_data is distinct from section.data then
   update public.cms_sections set data=new_data,revision=revision+1,updated_at=now() where page_id=section.page_id and key=section.key;
   insert into public.cms_history(actor,actor_id,page_id,section,revision,changes)
   values('System: About Us partner logos added','00000000-0000-0000-0000-000000000000'::uuid,section.page_id,section.key,section.revision+1,public.cms_diff(section.data,new_data));
 end if;
end $$;
commit;
