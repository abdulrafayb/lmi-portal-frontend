update public.cms_sections set data=jsonb_set(data,'{cards,0,category}','"Custom category"') where page_id='services' and key='sectionThree';
do $$ declare s public.cms_sections%rowtype; d jsonb;t jsonb;i integer;begin
 select * into s from public.cms_sections where page_id='services' and key='sectionThree';d:=s.data;t:=s.template;
 for i in 0..5 loop
  t:=jsonb_set(t,array['cards',i::text],(t#>array['cards',i::text])-'category');
  if i>0 then d:=jsonb_set(d,array['cards',i::text],(d#>array['cards',i::text])-'category');end if;
 end loop;
 d:=jsonb_set(d,'{cards,0,heading}','"Edited cargo copy"');d:=jsonb_set(d,'{cards,5}','{}');
 update public.cms_sections set data=d,template=t,enabled=false,revision=100 where page_id=s.page_id and key=s.key;
end $$;
