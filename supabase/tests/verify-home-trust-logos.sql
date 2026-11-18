do $$ declare section public.cms_sections%rowtype; i integer; ext text; paths jsonb := '["/home/shell-logo.png","/home/pso_logo.png","/home/caltex-logo.png","/home/engro-logo.png","/home/nlc_logo.png"]'::jsonb;
begin
 select * into section from public.cms_sections where page_id='home' and key='sectionTwo';
 for i in 0..4 loop
   if section.data->'logos'->i->>'src'<>paths->>i then raise exception 'Logo mismatch';end if;
 end loop;
 if section.data#>>'{logos,0,name}'<>'Admin edited Shell name' or section.data->>'heading'<>'Admin edited trust heading' or section.enabled or section.revision<>31 then raise exception 'Text/visibility changed or not idempotent';end if;
 if (select count(*) from public.cms_history where actor='System: Home trust logos added')<>1 then raise exception 'Logo migration audit duplicated';end if;
 foreach ext in array array['jpg','jpeg','png','webp','gif','avif','svg','bmp','ico','apng','jfif','JPG'] loop
   if public.cms_validate('""'::jsonb,to_jsonb('/public/home/logo.'||ext),'image','image')<>to_jsonb('/home/logo.'||ext) then raise exception 'Image format rejected or normalized incorrectly';end if;
   if public.cms_validate('""'::jsonb,to_jsonb('https://cdn.example/logo.'||ext),'src','src')<>to_jsonb('https://cdn.example/logo.'||ext) then raise exception 'Hosted image format rejected';end if;
 end loop;
end $$;
