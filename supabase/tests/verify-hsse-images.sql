do $$ begin
if (select data#>>'{awards,0,image}' from public.cms_sections where page_id='hsse' and key='sectionEight') is distinct from '/hsse/award-1.png' then raise exception 'Wrong image: hsse {awards,0,image}'; end if;
if (select data#>>'{awards,1,image}' from public.cms_sections where page_id='hsse' and key='sectionEight') is distinct from '/hsse/award-2.png' then raise exception 'Wrong image: hsse {awards,1,image}'; end if;
if (select data#>>'{image}' from public.cms_sections where page_id='hsse' and key='sectionOne') is distinct from '/hsse/section-1-main-image.png' then raise exception 'Wrong image: hsse {image}'; end if;
if (select data#>>'{image}' from public.cms_sections where page_id='hsse' and key='sectionFour') is distinct from '/hsse/section-4-main-image.png' then raise exception 'Wrong image: hsse {image}'; end if;
if (select data#>>'{image}' from public.cms_sections where page_id='hsse' and key='sectionSeven') is distinct from '/hsse/section-7-main-image.png' then raise exception 'Wrong image: hsse {image}'; end if;
if (select data#>'{awards,2}' from public.cms_sections where page_id='hsse' and key='sectionEight')<>'{}'::jsonb then raise exception 'Cleared client recreated'; end if;
if exists(select 1 from public.cms_sections where page_id='hsse' and key='sectionOne' and (enabled or data->>'heading'<>'Edited heading' or revision<>71)) then raise exception 'Text/visibility/revision changed'; end if;
if (select count(*) from public.cms_history where actor='System: HSSE images added')<>4 then raise exception 'Wrong audit count or repeated migration'; end if;
end $$;
