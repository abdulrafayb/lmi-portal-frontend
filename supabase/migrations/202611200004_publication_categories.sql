-- Add optional publication categories; preserve existing posts, tags and history.
begin;
alter table public.cms_posts add column if not exists category text not null default '';
create or replace function public.cms_save_post(p_data jsonb,p_id uuid default null,p_expected_revision integer default 0) returns jsonb
language plpgsql security definer set search_path='' as $$
declare old public.cms_posts%rowtype; saved public.cms_posts%rowtype; clean jsonb; f text; post_tags text[] := '{}'; item jsonb; tag text;
begin
 if not public.cms_is_admin() then raise sqlstate 'PT403' using message='Administrator access required'; end if;
 if p_data->>'status'='published' and (p_data->>'published_at')::timestamptz>now() then raise sqlstate 'PT400' using message='Future publication dates are not supported'; end if;
 if octet_length(p_data::text)>600000 then raise sqlstate 'PT400' using message='Post is too large'; end if;
 if p_data->'content'->>'type' is distinct from 'doc' then raise sqlstate 'PT400' using message='Rich text document required'; end if;
 perform public.cms_validate_richtext(p_data->'content');
 clean:=p_data;
 if clean ? 'category' and (jsonb_typeof(clean->'category') is distinct from 'string' or length(btrim(clean->>'category'))>80) then
  raise sqlstate 'PT400' using message='Category must be text with up to 80 characters';
 end if;
 if clean ? 'tags' then
  if jsonb_typeof(clean->'tags') is distinct from 'array' or jsonb_array_length(clean->'tags')>20 then raise sqlstate 'PT400' using message='Use up to 20 tags'; end if;
  for item in select value from jsonb_array_elements(clean->'tags') loop
   if jsonb_typeof(item) is distinct from 'string' then raise sqlstate 'PT400' using message='Tags must be text';end if;
   tag:=btrim(item#>>'{}');
   if length(tag) not between 1 and 50 then raise sqlstate 'PT400' using message='Each tag must contain 1 to 50 characters';end if;
   if not exists(select 1 from unnest(post_tags) t where lower(t)=lower(tag)) then post_tags:=array_append(post_tags,tag);end if;
  end loop;
 end if;
 for f in select unnest(array['title','excerpt','image_alt','author','author_role','seo_title','seo_description']) loop
  if jsonb_typeof(clean->f) is distinct from 'string' or length(clean->>f)>2000 then raise sqlstate 'PT400' using message='Invalid field: '||f; end if;
 end loop;
 clean:=jsonb_set(clean,'{image}',public.cms_validate('""'::jsonb,coalesce(clean->'image','""'::jsonb),'image','image'));
 if clean->>'status'='published' and (trim(clean->>'excerpt')='' or trim(clean->>'author')='' or trim(clean->>'image')='' or not coalesce(jsonb_path_query_array(clean->'content','$.**.text')::text ~ '[[:alnum:]]',false)) then raise sqlstate 'PT400' using message='Published posts need an excerpt, author, image and body'; end if;
 if p_id is not null then
  select * into old from public.cms_posts where id=p_id for update;
  if not found then raise sqlstate 'PT404' using message='Post not found'; end if;
  if old.revision<>p_expected_revision then raise sqlstate 'PT409' using message='This post changed. Reload before saving.'; end if;
  if not clean ? 'tags' then post_tags:=old.tags;end if;
  update public.cms_posts set category=case when clean ? 'category' then btrim(clean->>'category') else old.category end,tags=post_tags,kind=clean->>'kind',slug=clean->>'slug',title=clean->>'title',excerpt=clean->>'excerpt',image=clean->>'image',image_alt=clean->>'image_alt',author=clean->>'author',author_role=clean->>'author_role',content=clean->'content',seo_title=clean->>'seo_title',seo_description=clean->>'seo_description',status=clean->>'status',published_at=(clean->>'published_at')::timestamptz,revision=revision+1,updated_at=now() where id=p_id returning * into saved;
 else
  insert into public.cms_posts(kind,slug,title,excerpt,image,image_alt,author,author_role,content,seo_title,seo_description,status,published_at,tags,category) values(clean->>'kind',clean->>'slug',clean->>'title',clean->>'excerpt',clean->>'image',clean->>'image_alt',clean->>'author',clean->>'author_role',clean->'content',clean->>'seo_title',clean->>'seo_description',clean->>'status',(clean->>'published_at')::timestamptz,post_tags,coalesce(btrim(clean->>'category'),'')) returning * into saved;
 end if;
 insert into public.cms_post_history(post_id,actor_id,actor,revision,changes) values(saved.id,auth.uid(),coalesce(auth.jwt()->>'email','admin'),saved.revision,public.cms_diff(coalesce(to_jsonb(old),'{}'),to_jsonb(saved)));
 return to_jsonb(saved);
end $$;
revoke all on function public.cms_save_post(jsonb,uuid,integer) from public,anon;
grant execute on function public.cms_save_post(jsonb,uuid,integer) to authenticated;


commit;
