-- Simulate old text-only layouts and preserve edits made before the migration.
update public.cms_sections set
 template=(template - 'logoPlaceholder') || jsonb_build_object('clients',(select jsonb_agg(value-'name'-'image' order by ordinal) from jsonb_array_elements(template->'clients') with ordinality as x(value,ordinal))),
 data=jsonb_set(data,'{clients}','[{"id":"1","placeholder":"Admin edited pending client"},{"id":"2","name":"","image":"/custom-client.svg","placeholder":"Do not restore name"},null,{}]'::jsonb),
 revision=7,enabled=false
where page_id='services--flatbed-transportation' and key='sectionFive';
update public.cms_sections set
 template=(template - 'logoPlaceholder') || jsonb_build_object('clients',(select jsonb_agg(value-'name'-'image' order by ordinal) from jsonb_array_elements(template->'clients') with ordinality as x(value,ordinal))),
 data=jsonb_set(data,'{clients}','null'),revision=7
where page_id='services--full-truckload-ftl' and key='sectionFive';
update public.cms_sections set
 template=(template - 'logoPlaceholder') || jsonb_build_object('clients',(select jsonb_agg(value-'name'-'image' order by ordinal) from jsonb_array_elements(template->'clients') with ordinality as x(value,ordinal))),
 data=jsonb_set(jsonb_set(data,'{clients,0,name}','"Admin client"'),'{clients,0,image}','"/admin-logo.webp"'),revision=7
where page_id='services--containerized-transportation' and key='sectionFive';
