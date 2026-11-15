-- Recreate an existing five-card layout with administrator edits.
insert into public.cms_sections(page_id,key,position,template,data,revision)
values('company--leadership','sectionThree',2,'{}','{"name":"Old CEO copy","image":"/custom-ceo.webp","bio":"Preserve this archived bio"}',3);
update public.cms_sections set
 template=jsonb_set(template,'{members}',(select jsonb_agg(value order by ordinal) from jsonb_array_elements(template->'members') with ordinality as a(value,ordinal) where ordinal>1)),
 data=jsonb_set(jsonb_set(data,'{members}',(select jsonb_agg(value order by ordinal) from jsonb_array_elements(data->'members') with ordinality as a(value,ordinal) where ordinal>1)),'{members,0,name}','"Admin edited first manager"'),
 enabled=false, revision=7
where page_id='company--leadership' and key='sectionFour';
