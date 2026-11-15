-- Simulate an existing project with edited text, empty images and a retired row.
insert into public.cms_sections(page_id,key,position,template,data,enabled,revision)
values('services--flatbed-transportation','sectionSeven',6,'{"heading":"Related Services","services":[]}',
'{"heading":"Admin edited related content","services":[]}',true,3);
update public.cms_sections set template=template-'image'-'imageAlt',
 data=jsonb_set(data-'image'-'imageAlt','{heading}','"Admin edited Home title preserved"'),enabled=false
where page_id='home' and key='sectionOne';
do $$ declare section public.cms_sections%rowtype; item jsonb; i integer; value jsonb;
begin
 select * into section from public.cms_sections where page_id='home' and key='sectionFour';
 value:=section.data;
 for i in 0..7 loop value:=jsonb_set(value,array['services',i::text,'image'],'null');end loop;
 update public.cms_sections set data=value where page_id='home' and key='sectionFour';
 select * into section from public.cms_sections where page_id='home' and key='sectionEight';
 value:=section.data;
 for i in 0..4 loop value:=jsonb_set(value,array['industries',i::text,'image'],'null');end loop;
 value:=jsonb_set(value,'{industries,2,image}','"/custom-manufacturing.webp"');
 update public.cms_sections set data=value where page_id='home' and key='sectionEight';
end $$;
