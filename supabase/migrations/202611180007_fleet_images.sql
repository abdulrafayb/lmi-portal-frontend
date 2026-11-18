-- Add supplied Fleet & Visibility images without resetting text or visibility.
begin;
do $$
declare s public.cms_sections%rowtype; entry jsonb; updated jsonb; target_path text[]; parent_path text[]; new_template jsonb;
begin
 for s in select * from public.cms_sections where page_id like 'fleet-visibility--%' for update loop
  updated := s.data; new_template := s.template;
  if s.page_id='fleet-visibility--shipment-tracking-operational-visibility' and s.key='sectionThree' then
   if not new_template ? 'image' then new_template := new_template || '{"image":null}'::jsonb; end if;
   if not new_template ? 'imageAlt' then new_template := new_template || '{"imageAlt":""}'::jsonb; end if;
   if not updated ? 'imageAlt' then updated := updated || '{"imageAlt":"Illustrative shipment route and vehicle position"}'::jsonb; end if;
  end if;
  for entry in select value from jsonb_array_elements('[{"page": "fleet-visibility--fleet-equipment", "section": "sectionOne", "path": ["image"], "image": "/fleet-and-visiblity/fleet-and-equipment/section-1-main-image.png"}, {"page": "fleet-visibility--fleet-equipment", "section": "sectionThree", "path": ["services", "0", "image"], "image": "/fleet-and-visiblity/fleet-and-equipment/section-3-image-1.png"}, {"page": "fleet-visibility--fleet-equipment", "section": "sectionThree", "path": ["services", "1", "image"], "image": "/fleet-and-visiblity/fleet-and-equipment/section-3-image-2.png"}, {"page": "fleet-visibility--fleet-equipment", "section": "sectionThree", "path": ["services", "2", "image"], "image": "/fleet-and-visiblity/fleet-and-equipment/section-3-image-3.png"}, {"page": "fleet-visibility--fleet-equipment", "section": "sectionThree", "path": ["services", "3", "image"], "image": "/fleet-and-visiblity/fleet-and-equipment/section-3-image-4.png"}, {"page": "fleet-visibility--fleet-equipment", "section": "sectionThree", "path": ["services", "4", "image"], "image": "/fleet-and-visiblity/fleet-and-equipment/section-3-image-5.png"}, {"page": "fleet-visibility--fleet-equipment", "section": "sectionThree", "path": ["services", "5", "image"], "image": "/fleet-and-visiblity/fleet-and-equipment/section-3-image-6.png"}, {"page": "fleet-visibility--nationwide-network", "section": "sectionOne", "path": ["image"], "image": "/fleet-and-visiblity/nationwide-network/section-1-main-image.png"}, {"page": "fleet-visibility--nationwide-network", "section": "sectionFour", "path": ["locations", "0", "image"], "image": "/fleet-and-visiblity/nationwide-network/section-4-image-1.png"}, {"page": "fleet-visibility--nationwide-network", "section": "sectionFour", "path": ["locations", "1", "image"], "image": "/fleet-and-visiblity/nationwide-network/section-4-image-2.png"}, {"page": "fleet-visibility--nationwide-network", "section": "sectionFour", "path": ["locations", "2", "image"], "image": "/fleet-and-visiblity/nationwide-network/section-4-image-3.png"}, {"page": "fleet-visibility--nationwide-network", "section": "sectionFour", "path": ["locations", "3", "image"], "image": "/fleet-and-visiblity/nationwide-network/section-4-image-4.png"}, {"page": "fleet-visibility--nationwide-network", "section": "sectionFour", "path": ["locations", "4", "image"], "image": "/fleet-and-visiblity/nationwide-network/section-4-image-5.png"}, {"page": "fleet-visibility--shipment-tracking-operational-visibility", "section": "sectionOne", "path": ["image"], "image": "/fleet-and-visiblity/shipment-tracking-and-visibility/section-1-main-image.png"}, {"page": "fleet-visibility--shipment-tracking-operational-visibility", "section": "sectionThree", "path": ["image"], "image": "/fleet-and-visiblity/shipment-tracking-and-visibility/section-3-main-image.png"}]'::jsonb) loop
   if entry->>'page'=s.page_id and entry->>'section'=s.key then
    select array_agg(value order by ord) into target_path from jsonb_array_elements_text(entry->'path') with ordinality as a(value,ord);
    parent_path := target_path[1:cardinality(target_path)-1];
    if cardinality(target_path)=1 or (jsonb_typeof(updated#>parent_path)='object' and updated#>parent_path<>'{}'::jsonb) then
     updated := jsonb_set(updated,target_path,entry->'image');
    end if;
   end if;
  end loop;
  if updated is distinct from s.data or new_template is distinct from s.template then
   update public.cms_sections set data=updated,template=new_template,revision=revision+1,updated_at=now() where page_id=s.page_id and key=s.key;
   insert into public.cms_history(actor,actor_id,page_id,section,revision,changes)
   values('System: Fleet page images added','00000000-0000-0000-0000-000000000000'::uuid,s.page_id,s.key,s.revision+1,public.cms_diff(jsonb_build_object('data',s.data,'template',s.template),jsonb_build_object('data',updated,'template',new_template)));
  end if;
 end loop;
end $$;
commit;
