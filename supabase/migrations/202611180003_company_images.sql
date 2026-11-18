-- Run after the leadership team migration. Add supplied company-page images only.
begin;
do $$
declare s public.cms_sections%rowtype; entry jsonb; updated jsonb; target_path text[]; parent_path text[];
begin
 for s in select * from public.cms_sections where page_id in ('company--about-us','company--leadership','company--certifications-recognitions') for update loop
  updated := s.data;
  for entry in select value from jsonb_array_elements('[{"page": "company--about-us", "section": "sectionOne", "path": ["image"], "image": "/our-company/about-us/section-1-main-image.png"}, {"page": "company--leadership", "section": "sectionOne", "path": ["image"], "image": "/our-company/leadership/section-1-main-image.png"}, {"page": "company--certifications-recognitions", "section": "sectionOne", "path": ["image"], "image": "/our-company/certifications-and-recognitions/section-1-main-image.png"}, {"page": "company--about-us", "section": "sectionFive", "path": ["image"], "image": "/our-company/about-us/section-5-main-image.png"}, {"page": "company--leadership", "section": "sectionFour", "path": ["members", "0", "image"], "image": "/our-company/leadership/person-1.png"}, {"page": "company--leadership", "section": "sectionFour", "path": ["members", "1", "image"], "image": "/our-company/leadership/person-2.png"}, {"page": "company--leadership", "section": "sectionFour", "path": ["members", "2", "image"], "image": "/our-company/leadership/person-3.png"}, {"page": "company--leadership", "section": "sectionFour", "path": ["members", "3", "image"], "image": "/our-company/leadership/person-4.png"}, {"page": "company--leadership", "section": "sectionFour", "path": ["members", "4", "image"], "image": "/our-company/leadership/person-5.png"}, {"page": "company--leadership", "section": "sectionFour", "path": ["members", "5", "image"], "image": "/our-company/leadership/person-6.png"}, {"page": "company--certifications-recognitions", "section": "sectionThree", "path": ["credentials", "0", "image"], "image": "/our-company/certifications-and-recognitions/certificate-1.png"}, {"page": "company--certifications-recognitions", "section": "sectionThree", "path": ["credentials", "1", "image"], "image": "/our-company/certifications-and-recognitions/certificate-2.png"}, {"page": "company--certifications-recognitions", "section": "sectionThree", "path": ["credentials", "2", "image"], "image": "/our-company/certifications-and-recognitions/certificate-3.png"}, {"page": "company--certifications-recognitions", "section": "sectionThree", "path": ["credentials", "3", "image"], "image": "/our-company/certifications-and-recognitions/certificate-4.png"}, {"page": "company--certifications-recognitions", "section": "sectionThree", "path": ["credentials", "4", "image"], "image": "/our-company/certifications-and-recognitions/certificate-5.png"}, {"page": "company--certifications-recognitions", "section": "sectionThree", "path": ["credentials", "5", "image"], "image": "/our-company/certifications-and-recognitions/certificate-6.png"}, {"page": "company--certifications-recognitions", "section": "sectionThree", "path": ["credentials", "6", "image"], "image": "/our-company/certifications-and-recognitions/certificate-7.png"}, {"page": "company--certifications-recognitions", "section": "sectionThree", "path": ["credentials", "7", "image"], "image": "/our-company/certifications-and-recognitions/certificate-8.png"}]'::jsonb) loop
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
   values('System: Company page images added','00000000-0000-0000-0000-000000000000'::uuid,s.page_id,s.key,s.revision+1,public.cms_diff(s.data,updated));
  end if;
 end loop;
end $$;
commit;
