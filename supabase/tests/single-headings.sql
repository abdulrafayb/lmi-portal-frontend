-- Create a legacy, already-edited heading, including a stale open-tab revision.
update public.cms_sections
set template=jsonb_set(template,'{heading}','["Original","Three","Lines"]'),
    data=jsonb_set(data,'{heading}','["Custom edited","heading text","preserved"]'),
    enabled=false,revision=7
where page_id='home' and key='sectionOne';
