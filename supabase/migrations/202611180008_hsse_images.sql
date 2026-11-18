-- Add supplied HSSE images without resetting text or visibility.
begin;
do $$
declare s public.cms_sections%rowtype; entry jsonb; updated jsonb; target_path text[]; parent_path text[];
begin
 for s in select * from public.cms_sections where page_id='hsse' for update loop
  updated := s.data;
  for entry in select value from jsonb_array_elements('[{"page": "hsse", "section": "sectionEight", "path": ["awards", "0", "image"], "image": "/hsse/award-1.png"}, {"page": "hsse", "section": "sectionEight", "path": ["awards", "1", "image"], "image": "/hsse/award-2.png"}, {"page": "hsse", "section": "sectionEight", "path": ["awards", "2", "image"], "image": "/hsse/award-3.png"}, {"page": "hsse", "section": "sectionOne", "path": ["image"], "image": "/hsse/section-1-main-image.png"}, {"page": "hsse", "section": "sectionFour", "path": ["image"], "image": "/hsse/section-4-main-image.png"}, {"page": "hsse", "section": "sectionSeven", "path": ["image"], "image": "/hsse/section-7-main-image.png"}]'::jsonb) loop
   if entry->>'page'=s.page_id and entry->>'section'=s.key then
    select array_agg(value order by ord) into target_path from jsonb_array_elements_text(entry->'path') with ordinality as a(value,ord);
    parent_path := target_path[1:cardinality(target_path)-1];
    if cardinality(target_path)=1 or (jsonb_typeof(updated#>parent_path)='object' and updated#>parent_path<>'{}'::jsonb) then
     updated := jsonb_set(updated,target_path,entry->'image');
    end if;
   end if;
  end loop;
  if updated is distinct from s.data then
   update public.cms_sections set data=updated,revision=revision+1,updated_at=now() where page_id=s.page_id and key=s.key;
   insert into public.cms_history(actor,actor_id,page_id,section,revision,changes)
   values('System: HSSE images added','00000000-0000-0000-0000-000000000000'::uuid,s.page_id,s.key,s.revision+1,public.cms_diff(s.data,updated));
  end if;
 end loop;
end $$;
commit;
