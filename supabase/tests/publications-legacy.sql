update public.cms_sections set data=jsonb_set(data,'{insights,action,path}','"/insights"'::jsonb) where page_id='home' and key='sectionNine';
update public.cms_sections set data=jsonb_set(data,'{caseStudies,action,path}','"/custom-case-studies"'::jsonb) where page_id='home' and key='sectionNine';
