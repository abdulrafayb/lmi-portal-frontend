update public.cms_sections set data=jsonb_set(jsonb_set(data,'{partners,0,name}','"Edited partner"'::jsonb),'{partners,7}','{}'::jsonb),enabled=false,revision=60 where page_id='company--about-us' and key='sectionSix';
update public.cms_sections set data=jsonb_set(data,'{partners,0,image}','null'::jsonb) where page_id='company--about-us' and key='sectionSix';
