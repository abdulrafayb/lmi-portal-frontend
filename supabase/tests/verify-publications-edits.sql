do $$ begin
 if (select excerpt from public.cms_posts where kind='blog' and slug='planning-a-reliable-road-movement')<>'An administrator edited this sample.' then raise exception 'Migration reset an edited sample';end if;
 if (select data#>>'{insights,action,path}' from public.cms_sections where page_id='home' and key='sectionNine')<>'/articles' then raise exception 'Legacy CTA did not migrate';end if;
 if (select data#>>'{caseStudies,action,path}' from public.cms_sections where page_id='home' and key='sectionNine')<>'/custom-case-studies' then raise exception 'Custom CTA overwritten';end if;
 if (select count(*) from public.cms_history where actor='System: publication links' and page_id='home' and section='sectionNine')<>1 then raise exception 'Link migration audit duplicated';end if;
end $$;
