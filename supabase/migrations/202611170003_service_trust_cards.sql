-- Add editable names/images to the existing fixed client slots.
-- Preserves edited copy, images, visibility, list lengths and testimonial/highlight content.
begin;
do $$
declare section public.cms_sections%rowtype; new_template jsonb; new_data jsonb; clients jsonb; item jsonb;
begin
 for section in select * from public.cms_sections where page_id like 'services--%' and key='sectionFive' for update loop
   new_template := section.template; new_data := section.data;
   if not new_template ? 'logoPlaceholder' then new_template := new_template || '{"logoPlaceholder":""}'::jsonb;end if;
   if not new_data ? 'logoPlaceholder' then new_data := new_data || '{"logoPlaceholder":"[logo]"}'::jsonb;end if;
   clients := '[]'::jsonb;
   for item in select value from jsonb_array_elements(section.template->'clients') with ordinality as x(value,ordinal) order by ordinal loop
     if jsonb_typeof(item)='object' then
       if not item ? 'name' then item := item || '{"name":""}'::jsonb;end if;
       if not item ? 'image' then item := item || '{"image":""}'::jsonb;end if;
     end if;
     clients := clients || jsonb_build_array(item);
   end loop;
   new_template := jsonb_set(new_template,'{clients}',clients);
   if jsonb_typeof(section.data->'clients')='array' then
     clients := '[]'::jsonb;
     for item in select value from jsonb_array_elements(section.data->'clients') with ordinality as x(value,ordinal) order by ordinal loop
       if jsonb_typeof(item)='object' then
         if not item ? 'name' then
           item := item || jsonb_build_object('name',case when jsonb_typeof(item->'placeholder')='string' then item->>'placeholder' else '' end);
         end if;
         if not item ? 'image' then item := item || '{"image":null}'::jsonb;end if;
       end if;
       clients := clients || jsonb_build_array(item);
     end loop;
     new_data := jsonb_set(new_data,'{clients}',clients);
   end if;
   if new_template is distinct from section.template or new_data is distinct from section.data then
     update public.cms_sections set template=new_template,data=new_data,revision=revision+1,updated_at=now() where page_id=section.page_id and key=section.key;
     insert into public.cms_history(actor,actor_id,page_id,section,revision,changes)
     values('System: service trust card fields','00000000-0000-0000-0000-000000000000'::uuid,section.page_id,section.key,section.revision+1,public.cms_diff(jsonb_build_object('template',section.template,'data',section.data),jsonb_build_object('template',new_template,'data',new_data)));
   end if;
 end loop;
end $$;
commit;
