do $$ begin
if (select data#>>'{image}' from public.cms_sections where page_id='insights' and key='sectionOne') is distinct from '/insights/section-1-main-image.png' then raise exception 'Wrong image: insights {image}'; end if;
if (select data#>>'{cards,0,image}' from public.cms_sections where page_id='insights' and key='sectionTwo') is distinct from '/insights/section-2-image-1.png' then raise exception 'Wrong image: insights {cards,0,image}'; end if;
if (select data#>>'{cards,1,image}' from public.cms_sections where page_id='insights' and key='sectionTwo') is distinct from '/insights/section-2-image-2.png' then raise exception 'Wrong image: insights {cards,1,image}'; end if;
if (select data#>>'{image}' from public.cms_sections where page_id='insights' and key='sectionThree') is distinct from '/insights/section-3-main-image.png' then raise exception 'Wrong image: insights {image}'; end if;
if (select data#>>'{image}' from public.cms_sections where page_id='contact-us' and key='sectionOne') is distinct from '/contact-us/section-1-main-image.png' then raise exception 'Wrong image: contact-us {image}'; end if;
if (select data#>'{cards,2}' from public.cms_sections where page_id='insights' and key='sectionTwo')<>'{}'::jsonb then raise exception 'Cleared client recreated'; end if;
if exists(select 1 from public.cms_sections where page_id='contact-us' and key='sectionOne' and (enabled or data->>'heading'<>'Edited heading' or revision<>71)) then raise exception 'Text/visibility/revision changed'; end if;
if (select count(*) from public.cms_history where actor='System: Insights and Contact images added')<>4 then raise exception 'Wrong audit count or repeated migration'; end if;
end $$;
