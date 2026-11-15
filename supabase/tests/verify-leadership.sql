do $$ declare team public.cms_sections%rowtype;
begin
 select * into team from public.cms_sections where page_id='company--leadership' and key='sectionFour';
 if jsonb_array_length(team.template->'members')<>6 or jsonb_array_length(team.data->'members')<>6 then raise exception 'Six cards missing';end if;
 if team.data#>>'{members,0,name}'<>'Brig. (R) Shahid Mahmood' or team.data#>>'{members,0,role}'<>'Chief Executive Officer' or team.data#>>'{members,0,image}'<>'/custom-ceo.webp' then raise exception 'CEO card incorrect';end if;
 if team.data#>>'{members,1,name}'<>'Admin edited first manager' or team.enabled then raise exception 'Existing cards or visibility changed';end if;
 if team.revision<>8 then raise exception 'Migration not idempotent';end if;
 if not exists(select 1 from public.cms_sections where page_id='company--leadership' and key='sectionThree' and not enabled and revision=4 and data->>'bio'='Preserve this archived bio') then raise exception 'Archived CEO content lost';end if;
 if public.cms_section_active('company--leadership','sectionThree') then raise exception 'Old executive layout still active';end if;
 if public.cms_public_page('company--leadership')->'sections' ? 'sectionThree' then raise exception 'Old layout exposed by API';end if;
 if (select count(*) from public.cms_history where actor in ('System: six-card leadership layout','System: executive layout retired'))<>2 then raise exception 'Audit not idempotent';end if;
end $$;
