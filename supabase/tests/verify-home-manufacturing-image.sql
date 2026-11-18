do $$ declare section public.cms_sections%rowtype;
begin
 select * into section from public.cms_sections where page_id='home' and key='sectionEight';
 if section.data#>>'{industries,2,image}'<>'/home/section-8-image-3.png' then raise exception 'Manufacturing photo missing';end if;
 if section.data#>>'{industries,2,title}'<>'Admin manufacturing title' or section.data#>>'{industries,1,image}'<>'/keep-chemical-image.webp' or section.enabled then raise exception 'Other content or visibility changed';end if;
 if section.revision<>21 then raise exception 'Migration not idempotent';end if;
 if (select count(*) from public.cms_history where actor='System: Home manufacturing image added')<>1 then raise exception 'Audit duplicated';end if;
end $$;
