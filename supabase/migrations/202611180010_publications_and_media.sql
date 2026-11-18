-- Publications are separate from the fixed page-section CMS.
begin;
create table if not exists public.cms_posts (
 id uuid primary key default gen_random_uuid(),
 kind text not null check(kind in ('blog','case-study','article')),
 slug text not null check(slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$' and length(slug)<=120),
 title text not null check(length(trim(title)) between 1 and 200),
 excerpt text not null default '' check(length(excerpt)<=1000),
 image text not null default '', image_alt text not null default '',
 author text not null default '', author_role text not null default '',
 content jsonb not null default '{"type":"doc","content":[{"type":"paragraph"}]}',
 seo_title text not null default '', seo_description text not null default '',
 status text not null default 'draft' check(status in ('draft','published')),
 published_at timestamptz not null default now(),
 revision integer not null default 1,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 unique(kind,slug)
);
create table if not exists public.cms_post_history (
 id bigint generated always as identity primary key, post_id uuid not null,
 at timestamptz not null default now(), actor_id uuid not null, actor text not null,
 revision integer not null, changes jsonb not null, unique(post_id,revision)
);
alter table public.cms_posts enable row level security;
alter table public.cms_post_history enable row level security;
revoke all on public.cms_posts,public.cms_post_history from anon,authenticated;
drop policy if exists posts_admin_read on public.cms_posts;
create policy posts_admin_read on public.cms_posts for select to authenticated using(public.cms_is_admin());
drop policy if exists post_history_admin_read on public.cms_post_history;
create policy post_history_admin_read on public.cms_post_history for select to authenticated using(public.cms_is_admin());
grant select on public.cms_posts,public.cms_post_history to authenticated;

-- Structured rich text only: no raw HTML, embeds, scripts or arbitrary attributes.
create or replace function public.cms_validate_richtext(node jsonb, depth integer default 0) returns void
language plpgsql set search_path='' as $$
declare child jsonb; mark jsonb; t text; url text;
begin
 if depth>20 or jsonb_typeof(node) is distinct from 'object' then raise sqlstate 'PT400' using message='Invalid rich text'; end if;
 t:=node->>'type';
 if t is null or t not in ('doc','paragraph','text','heading','bulletList','orderedList','listItem','blockquote','codeBlock','hardBreak','horizontalRule','image') then raise sqlstate 'PT400' using message='Unsupported rich text block'; end if;
 if t='text' and (jsonb_typeof(node->'text') is distinct from 'string' or length(node->>'text')>50000) then raise sqlstate 'PT400' using message='Invalid text'; end if;
 if t='heading' and coalesce(node#>>'{attrs,level}','') not in ('2','3','4') then raise sqlstate 'PT400' using message='Use heading levels 2 to 4'; end if;
 if t='image' then
  url:=node#>>'{attrs,src}';
  if url is null or not (url ~ '^/[^/]' or url ~ '^https://[^/[:space:]]+') or url ~ '[\\[:cntrl:]]' then raise sqlstate 'PT400' using message='Invalid image URL'; end if;
 end if;
 if node ? 'marks' then
  if jsonb_typeof(node->'marks')<>'array' then raise sqlstate 'PT400' using message='Invalid text marks'; end if;
  for mark in select value from jsonb_array_elements(node->'marks') loop
   if coalesce(mark->>'type','') not in ('bold','italic','strike','underline','code','link') then raise sqlstate 'PT400' using message='Unsupported text format'; end if;
   if mark->>'type'='link' then
    url:=mark#>>'{attrs,href}';
    if url is null or not (url ~ '^https?://' or url ~ '^/[^/]' or url ~ '^#[a-zA-Z0-9_-]+' or url ~ '^mailto:[^[:space:]]+@') or url ~ '[\\[:cntrl:]]' then raise sqlstate 'PT400' using message='Invalid link'; end if;
   end if;
  end loop;
 end if;
 if node ? 'content' then
  if jsonb_typeof(node->'content')<>'array' then raise sqlstate 'PT400' using message='Invalid content'; end if;
  for child in select value from jsonb_array_elements(node->'content') loop perform public.cms_validate_richtext(child,depth+1); end loop;
 end if;
end $$;
revoke all on function public.cms_validate_richtext(jsonb,integer) from public,anon,authenticated;

create or replace function public.cms_public_posts() returns jsonb
language sql stable security definer set search_path='' as $$
 select coalesce(jsonb_agg(to_jsonb(p) - 'revision' - 'created_at' - 'updated_at' order by p.published_at desc,p.id), '[]'::jsonb)
 from public.cms_posts p where status='published' and published_at<=now();
$$;
revoke all on function public.cms_public_posts() from public;
grant execute on function public.cms_public_posts() to anon,authenticated;

create or replace function public.cms_save_post(p_data jsonb,p_id uuid default null,p_expected_revision integer default 0) returns jsonb
language plpgsql security definer set search_path='' as $$
declare old public.cms_posts%rowtype; saved public.cms_posts%rowtype; clean jsonb; f text;
begin
 if not public.cms_is_admin() then raise sqlstate 'PT403' using message='Administrator access required'; end if;
 if p_data->>'status'='published' and (p_data->>'published_at')::timestamptz>now() then raise sqlstate 'PT400' using message='Future publication dates are not supported'; end if;
 if octet_length(p_data::text)>600000 then raise sqlstate 'PT400' using message='Post is too large'; end if;
 if p_data->'content'->>'type' is distinct from 'doc' then raise sqlstate 'PT400' using message='Rich text document required'; end if;
 perform public.cms_validate_richtext(p_data->'content');
 clean:=p_data;
 for f in select unnest(array['title','excerpt','image_alt','author','author_role','seo_title','seo_description']) loop
  if jsonb_typeof(clean->f) is distinct from 'string' or length(clean->>f)>2000 then raise sqlstate 'PT400' using message='Invalid field: '||f; end if;
 end loop;
 clean:=jsonb_set(clean,'{image}',public.cms_validate('""'::jsonb,coalesce(clean->'image','""'::jsonb),'image','image'));
 if clean->>'status'='published' and (trim(clean->>'excerpt')='' or trim(clean->>'author')='' or trim(clean->>'image')='' or not coalesce(jsonb_path_query_array(clean->'content','$.**.text')::text ~ '[[:alnum:]]',false)) then raise sqlstate 'PT400' using message='Published posts need an excerpt, author, image and body'; end if;
 if p_id is not null then
  select * into old from public.cms_posts where id=p_id for update;
  if not found then raise sqlstate 'PT404' using message='Post not found'; end if;
  if old.revision<>p_expected_revision then raise sqlstate 'PT409' using message='This post changed. Reload before saving.'; end if;
  update public.cms_posts set kind=clean->>'kind',slug=clean->>'slug',title=clean->>'title',excerpt=clean->>'excerpt',image=clean->>'image',image_alt=clean->>'image_alt',author=clean->>'author',author_role=clean->>'author_role',content=clean->'content',seo_title=clean->>'seo_title',seo_description=clean->>'seo_description',status=clean->>'status',published_at=(clean->>'published_at')::timestamptz,revision=revision+1,updated_at=now() where id=p_id returning * into saved;
 else
  insert into public.cms_posts(kind,slug,title,excerpt,image,image_alt,author,author_role,content,seo_title,seo_description,status,published_at) values(clean->>'kind',clean->>'slug',clean->>'title',clean->>'excerpt',clean->>'image',clean->>'image_alt',clean->>'author',clean->>'author_role',clean->'content',clean->>'seo_title',clean->>'seo_description',clean->>'status',(clean->>'published_at')::timestamptz) returning * into saved;
 end if;
 insert into public.cms_post_history(post_id,actor_id,actor,revision,changes) values(saved.id,auth.uid(),coalesce(auth.jwt()->>'email','admin'),saved.revision,public.cms_diff(coalesce(to_jsonb(old),'{}'),to_jsonb(saved)));
 return to_jsonb(saved);
end $$;
revoke all on function public.cms_save_post(jsonb,uuid,integer) from public,anon;
grant execute on function public.cms_save_post(jsonb,uuid,integer) to authenticated;

-- Public images, admin-only uploads. Unique object names avoid overwriting live media.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('cms-media','cms-media',true,10485760,array['image/jpeg','image/png','image/webp','image/gif','image/avif']) on conflict(id) do update set public=true,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;
drop policy if exists cms_media_insert on storage.objects;
create policy cms_media_insert on storage.objects for insert to authenticated with check(bucket_id='cms-media' and public.cms_is_admin() and name like 'images/%');
-- No browser delete/update policy: replacing a field never deletes media used elsewhere.

-- Nine clearly labelled demonstration publications. Never overwrite edited posts.
insert into public.cms_posts(id,kind,slug,title,excerpt,image,image_alt,author,author_role,content,seo_title,seo_description,status,published_at) values('597a8ed2-dfa8-54ba-ad96-e98035d5d1b4','blog','planning-a-reliable-road-movement','Sample: Planning a reliable road movement','Demonstration content: The planning team collects the cargo dimensions, weight, handling method and pickup and delivery details. Clear information helps everyone understand the movement before equipment is selected.','/services/road-freight-transportation/section-1-main-image.png','Sample: Planning a reliable road movement','LMI Editorial Team','Sample publication','{"type": "doc", "content": [{"type": "paragraph", "content": [{"type": "text", "text": "This is demonstration content for the new publication system. It is an illustrative example, not a report of a real LMI project. Replace it with approved content before sharing."}]}, {"type": "heading", "attrs": {"level": 2}, "content": [{"type": "text", "text": "Start with the cargo"}]}, {"type": "paragraph", "content": [{"type": "text", "text": "The planning team collects the cargo dimensions, weight, handling method and pickup and delivery details. Clear information helps everyone understand the movement before equipment is selected."}]}, {"type": "heading", "attrs": {"level": 2}, "content": [{"type": "text", "text": "Agree the operating plan"}]}, {"type": "paragraph", "content": [{"type": "text", "text": "The next step is to agree the vehicle requirements, route and delivery window. Site access and loading arrangements are reviewed with the relevant teams."}]}, {"type": "heading", "attrs": {"level": 2}, "content": [{"type": "text", "text": "Prepare the handover"}]}, {"type": "paragraph", "content": [{"type": "text", "text": "Before dispatch, the teams confirm readiness and the communication plan. The receiving site gets the information it needs to prepare for arrival."}]}]}'::jsonb,'','','published','2026-11-10T00:00:00Z') on conflict do nothing;
insert into public.cms_posts(id,kind,slug,title,excerpt,image,image_alt,author,author_role,content,seo_title,seo_description,status,published_at) values('92be522b-5b63-5146-b287-39b9ee15dd39','blog','why-fleet-readiness-matters','Sample: Why fleet readiness matters','Demonstration content: The planning team collects the cargo dimensions, weight, handling method and pickup and delivery details. Clear information helps everyone understand the movement before equipment is selected.','/fleet-and-visiblity/fleet-and-equipment/section-1-main-image.png','Sample: Why fleet readiness matters','LMI Editorial Team','Sample publication','{"type": "doc", "content": [{"type": "paragraph", "content": [{"type": "text", "text": "This is demonstration content for the new publication system. It is an illustrative example, not a report of a real LMI project. Replace it with approved content before sharing."}]}, {"type": "heading", "attrs": {"level": 2}, "content": [{"type": "text", "text": "Start with the cargo"}]}, {"type": "paragraph", "content": [{"type": "text", "text": "The planning team collects the cargo dimensions, weight, handling method and pickup and delivery details. Clear information helps everyone understand the movement before equipment is selected."}]}, {"type": "heading", "attrs": {"level": 2}, "content": [{"type": "text", "text": "Agree the operating plan"}]}, {"type": "paragraph", "content": [{"type": "text", "text": "The next step is to agree the vehicle requirements, route and delivery window. Site access and loading arrangements are reviewed with the relevant teams."}]}, {"type": "heading", "attrs": {"level": 2}, "content": [{"type": "text", "text": "Prepare the handover"}]}, {"type": "paragraph", "content": [{"type": "text", "text": "Before dispatch, the teams confirm readiness and the communication plan. The receiving site gets the information it needs to prepare for arrival."}]}]}'::jsonb,'','','published','2026-11-11T00:00:00Z') on conflict do nothing;
insert into public.cms_posts(id,kind,slug,title,excerpt,image,image_alt,author,author_role,content,seo_title,seo_description,status,published_at) values('10c37736-7e6e-55e5-bd71-59c5035a7c2f','blog','keeping-receiving-teams-informed','Sample: Keeping receiving teams informed','Demonstration content: The planning team collects the cargo dimensions, weight, handling method and pickup and delivery details. Clear information helps everyone understand the movement before equipment is selected.','/fleet-and-visiblity/shipment-tracking-and-visibility/section-1-main-image.png','Sample: Keeping receiving teams informed','LMI Editorial Team','Sample publication','{"type": "doc", "content": [{"type": "paragraph", "content": [{"type": "text", "text": "This is demonstration content for the new publication system. It is an illustrative example, not a report of a real LMI project. Replace it with approved content before sharing."}]}, {"type": "heading", "attrs": {"level": 2}, "content": [{"type": "text", "text": "Start with the cargo"}]}, {"type": "paragraph", "content": [{"type": "text", "text": "The planning team collects the cargo dimensions, weight, handling method and pickup and delivery details. Clear information helps everyone understand the movement before equipment is selected."}]}, {"type": "heading", "attrs": {"level": 2}, "content": [{"type": "text", "text": "Agree the operating plan"}]}, {"type": "paragraph", "content": [{"type": "text", "text": "The next step is to agree the vehicle requirements, route and delivery window. Site access and loading arrangements are reviewed with the relevant teams."}]}, {"type": "heading", "attrs": {"level": 2}, "content": [{"type": "text", "text": "Prepare the handover"}]}, {"type": "paragraph", "content": [{"type": "text", "text": "Before dispatch, the teams confirm readiness and the communication plan. The receiving site gets the information it needs to prepare for arrival."}]}]}'::jsonb,'','','published','2026-11-12T00:00:00Z') on conflict do nothing;
insert into public.cms_posts(id,kind,slug,title,excerpt,image,image_alt,author,author_role,content,seo_title,seo_description,status,published_at) values('047efa11-839f-5938-98f7-0b7ccd6e799d','case-study','coordinating-a-factory-delivery','Sample: Coordinating a factory delivery','Demonstration content: The planning team collects the cargo dimensions, weight, handling method and pickup and delivery details. Clear information helps everyone understand the movement before equipment is selected.','/industries/manufacturing-and-industrial/section-1-main-image.png','Sample: Coordinating a factory delivery','LMI Editorial Team','Sample publication','{"type": "doc", "content": [{"type": "paragraph", "content": [{"type": "text", "text": "This is demonstration content for the new publication system. It is an illustrative example, not a report of a real LMI project. Replace it with approved content before sharing."}]}, {"type": "heading", "attrs": {"level": 2}, "content": [{"type": "text", "text": "Challenge"}]}, {"type": "paragraph", "content": [{"type": "text", "text": "The planning team collects the cargo dimensions, weight, handling method and pickup and delivery details. Clear information helps everyone understand the movement before equipment is selected."}]}, {"type": "heading", "attrs": {"level": 2}, "content": [{"type": "text", "text": "Approach"}]}, {"type": "paragraph", "content": [{"type": "text", "text": "The next step is to agree the vehicle requirements, route and delivery window. Site access and loading arrangements are reviewed with the relevant teams."}]}, {"type": "heading", "attrs": {"level": 2}, "content": [{"type": "text", "text": "Delivery"}]}, {"type": "paragraph", "content": [{"type": "text", "text": "Before dispatch, the teams confirm readiness and the communication plan. The receiving site gets the information it needs to prepare for arrival."}]}, {"type": "heading", "attrs": {"level": 2}, "content": [{"type": "text", "text": "Result"}]}, {"type": "paragraph", "content": [{"type": "text", "text": "In this illustrative scenario, the outcome is a clear and coordinated plan. No actual delivery metrics or customer endorsement are implied."}]}]}'::jsonb,'','','published','2026-11-13T00:00:00Z') on conflict do nothing;
insert into public.cms_posts(id,kind,slug,title,excerpt,image,image_alt,author,author_role,content,seo_title,seo_description,status,published_at) values('b429d291-6dcb-5eb9-a33d-28f0bd5cc56e','case-study','planning-an-open-deck-movement','Sample: Planning an open-deck movement','Demonstration content: The planning team collects the cargo dimensions, weight, handling method and pickup and delivery details. Clear information helps everyone understand the movement before equipment is selected.','/services/flatbed-transportation/section-1-main-image.png','Sample: Planning an open-deck movement','LMI Editorial Team','Sample publication','{"type": "doc", "content": [{"type": "paragraph", "content": [{"type": "text", "text": "This is demonstration content for the new publication system. It is an illustrative example, not a report of a real LMI project. Replace it with approved content before sharing."}]}, {"type": "heading", "attrs": {"level": 2}, "content": [{"type": "text", "text": "Challenge"}]}, {"type": "paragraph", "content": [{"type": "text", "text": "The planning team collects the cargo dimensions, weight, handling method and pickup and delivery details. Clear information helps everyone understand the movement before equipment is selected."}]}, {"type": "heading", "attrs": {"level": 2}, "content": [{"type": "text", "text": "Approach"}]}, {"type": "paragraph", "content": [{"type": "text", "text": "The next step is to agree the vehicle requirements, route and delivery window. Site access and loading arrangements are reviewed with the relevant teams."}]}, {"type": "heading", "attrs": {"level": 2}, "content": [{"type": "text", "text": "Delivery"}]}, {"type": "paragraph", "content": [{"type": "text", "text": "Before dispatch, the teams confirm readiness and the communication plan. The receiving site gets the information it needs to prepare for arrival."}]}, {"type": "heading", "attrs": {"level": 2}, "content": [{"type": "text", "text": "Result"}]}, {"type": "paragraph", "content": [{"type": "text", "text": "In this illustrative scenario, the outcome is a clear and coordinated plan. No actual delivery metrics or customer endorsement are implied."}]}]}'::jsonb,'','','published','2026-11-14T00:00:00Z') on conflict do nothing;
insert into public.cms_posts(id,kind,slug,title,excerpt,image,image_alt,author,author_role,content,seo_title,seo_description,status,published_at) values('936be9b2-95b1-5821-a29e-c67db6c9bed9','case-study','organizing-a-container-collection','Sample: Organizing a container collection','Demonstration content: The planning team collects the cargo dimensions, weight, handling method and pickup and delivery details. Clear information helps everyone understand the movement before equipment is selected.','/services/containerized-transportation/section-1-main-image.png','Sample: Organizing a container collection','LMI Editorial Team','Sample publication','{"type": "doc", "content": [{"type": "paragraph", "content": [{"type": "text", "text": "This is demonstration content for the new publication system. It is an illustrative example, not a report of a real LMI project. Replace it with approved content before sharing."}]}, {"type": "heading", "attrs": {"level": 2}, "content": [{"type": "text", "text": "Challenge"}]}, {"type": "paragraph", "content": [{"type": "text", "text": "The planning team collects the cargo dimensions, weight, handling method and pickup and delivery details. Clear information helps everyone understand the movement before equipment is selected."}]}, {"type": "heading", "attrs": {"level": 2}, "content": [{"type": "text", "text": "Approach"}]}, {"type": "paragraph", "content": [{"type": "text", "text": "The next step is to agree the vehicle requirements, route and delivery window. Site access and loading arrangements are reviewed with the relevant teams."}]}, {"type": "heading", "attrs": {"level": 2}, "content": [{"type": "text", "text": "Delivery"}]}, {"type": "paragraph", "content": [{"type": "text", "text": "Before dispatch, the teams confirm readiness and the communication plan. The receiving site gets the information it needs to prepare for arrival."}]}, {"type": "heading", "attrs": {"level": 2}, "content": [{"type": "text", "text": "Result"}]}, {"type": "paragraph", "content": [{"type": "text", "text": "In this illustrative scenario, the outcome is a clear and coordinated plan. No actual delivery metrics or customer endorsement are implied."}]}]}'::jsonb,'','','published','2026-11-15T00:00:00Z') on conflict do nothing;
insert into public.cms_posts(id,kind,slug,title,excerpt,image,image_alt,author,author_role,content,seo_title,seo_description,status,published_at) values('c43bade5-6e6c-574a-8d33-d4f262055b45','article','choosing-a-transport-service','Sample: Choosing a transport service','Demonstration content: The planning team collects the cargo dimensions, weight, handling method and pickup and delivery details. Clear information helps everyone understand the movement before equipment is selected.','/services/overview/section-1-main-image.png','Sample: Choosing a transport service','LMI Editorial Team','Sample publication','{"type": "doc", "content": [{"type": "paragraph", "content": [{"type": "text", "text": "This is demonstration content for the new publication system. It is an illustrative example, not a report of a real LMI project. Replace it with approved content before sharing."}]}, {"type": "heading", "attrs": {"level": 2}, "content": [{"type": "text", "text": "Start with the cargo"}]}, {"type": "paragraph", "content": [{"type": "text", "text": "The planning team collects the cargo dimensions, weight, handling method and pickup and delivery details. Clear information helps everyone understand the movement before equipment is selected."}]}, {"type": "heading", "attrs": {"level": 2}, "content": [{"type": "text", "text": "Agree the operating plan"}]}, {"type": "paragraph", "content": [{"type": "text", "text": "The next step is to agree the vehicle requirements, route and delivery window. Site access and loading arrangements are reviewed with the relevant teams."}]}, {"type": "heading", "attrs": {"level": 2}, "content": [{"type": "text", "text": "Prepare the handover"}]}, {"type": "paragraph", "content": [{"type": "text", "text": "Before dispatch, the teams confirm readiness and the communication plan. The receiving site gets the information it needs to prepare for arrival."}]}]}'::jsonb,'','','published','2026-11-16T00:00:00Z') on conflict do nothing;
insert into public.cms_posts(id,kind,slug,title,excerpt,image,image_alt,author,author_role,content,seo_title,seo_description,status,published_at) values('847004af-2c43-5bad-8ca7-65d8789b2228','article','preparing-cargo-details','Sample: Preparing your cargo details','Demonstration content: The planning team collects the cargo dimensions, weight, handling method and pickup and delivery details. Clear information helps everyone understand the movement before equipment is selected.','/services/heavy-and-project-cargo/section-1-main-image.png','Sample: Preparing your cargo details','LMI Editorial Team','Sample publication','{"type": "doc", "content": [{"type": "paragraph", "content": [{"type": "text", "text": "This is demonstration content for the new publication system. It is an illustrative example, not a report of a real LMI project. Replace it with approved content before sharing."}]}, {"type": "heading", "attrs": {"level": 2}, "content": [{"type": "text", "text": "Start with the cargo"}]}, {"type": "paragraph", "content": [{"type": "text", "text": "The planning team collects the cargo dimensions, weight, handling method and pickup and delivery details. Clear information helps everyone understand the movement before equipment is selected."}]}, {"type": "heading", "attrs": {"level": 2}, "content": [{"type": "text", "text": "Agree the operating plan"}]}, {"type": "paragraph", "content": [{"type": "text", "text": "The next step is to agree the vehicle requirements, route and delivery window. Site access and loading arrangements are reviewed with the relevant teams."}]}, {"type": "heading", "attrs": {"level": 2}, "content": [{"type": "text", "text": "Prepare the handover"}]}, {"type": "paragraph", "content": [{"type": "text", "text": "Before dispatch, the teams confirm readiness and the communication plan. The receiving site gets the information it needs to prepare for arrival."}]}]}'::jsonb,'','','published','2026-11-17T00:00:00Z') on conflict do nothing;
insert into public.cms_posts(id,kind,slug,title,excerpt,image,image_alt,author,author_role,content,seo_title,seo_description,status,published_at) values('7794b5b4-b213-55ec-9e5f-320b79fee73d','article','understanding-delivery-coordination','Sample: Understanding delivery coordination','Demonstration content: The planning team collects the cargo dimensions, weight, handling method and pickup and delivery details. Clear information helps everyone understand the movement before equipment is selected.','/services/dry-cargo-transportation/section-1-main-image.png','Sample: Understanding delivery coordination','LMI Editorial Team','Sample publication','{"type": "doc", "content": [{"type": "paragraph", "content": [{"type": "text", "text": "This is demonstration content for the new publication system. It is an illustrative example, not a report of a real LMI project. Replace it with approved content before sharing."}]}, {"type": "heading", "attrs": {"level": 2}, "content": [{"type": "text", "text": "Start with the cargo"}]}, {"type": "paragraph", "content": [{"type": "text", "text": "The planning team collects the cargo dimensions, weight, handling method and pickup and delivery details. Clear information helps everyone understand the movement before equipment is selected."}]}, {"type": "heading", "attrs": {"level": 2}, "content": [{"type": "text", "text": "Agree the operating plan"}]}, {"type": "paragraph", "content": [{"type": "text", "text": "The next step is to agree the vehicle requirements, route and delivery window. Site access and loading arrangements are reviewed with the relevant teams."}]}, {"type": "heading", "attrs": {"level": 2}, "content": [{"type": "text", "text": "Prepare the handover"}]}, {"type": "paragraph", "content": [{"type": "text", "text": "Before dispatch, the teams confirm readiness and the communication plan. The receiving site gets the information it needs to prepare for arrival."}]}]}'::jsonb,'','','published','2026-11-18T00:00:00Z') on conflict do nothing;
do $$ declare s public.cms_sections%rowtype; next_data jsonb; begin
 for s in select * from public.cms_sections where page_id='home' and key='sectionNine' and data#>>'{insights,action,path}'='/insights' for update loop
  next_data:=jsonb_set(s.data,'{insights,action,path}',to_jsonb('/articles'::text));
  update public.cms_sections set data=next_data,revision=revision+1,updated_at=now() where page_id=s.page_id and key=s.key;
  insert into public.cms_history(actor,actor_id,page_id,section,revision,changes) values('System: publication links','00000000-0000-0000-0000-000000000000',s.page_id,s.key,s.revision+1,public.cms_diff(s.data,next_data));
 end loop;
end $$;
do $$ declare s public.cms_sections%rowtype; next_data jsonb; begin
 for s in select * from public.cms_sections where page_id='home' and key='sectionNine' and data#>>'{caseStudies,action,path}'='/insights#case-studies' for update loop
  next_data:=jsonb_set(s.data,'{caseStudies,action,path}',to_jsonb('/case-studies'::text));
  update public.cms_sections set data=next_data,revision=revision+1,updated_at=now() where page_id=s.page_id and key=s.key;
  insert into public.cms_history(actor,actor_id,page_id,section,revision,changes) values('System: publication links','00000000-0000-0000-0000-000000000000',s.page_id,s.key,s.revision+1,public.cms_diff(s.data,next_data));
 end loop;
end $$;
do $$ declare s public.cms_sections%rowtype; next_data jsonb; begin
 for s in select * from public.cms_sections where page_id='insights' and key='sectionTwo' and data#>>'{cards,0,path}'='#case-study-approach' for update loop
  next_data:=jsonb_set(s.data,'{cards,0,path}',to_jsonb('/case-studies/coordinating-a-factory-delivery'::text));
  update public.cms_sections set data=next_data,revision=revision+1,updated_at=now() where page_id=s.page_id and key=s.key;
  insert into public.cms_history(actor,actor_id,page_id,section,revision,changes) values('System: publication links','00000000-0000-0000-0000-000000000000',s.page_id,s.key,s.revision+1,public.cms_diff(s.data,next_data));
 end loop;
end $$;
do $$ declare s public.cms_sections%rowtype; next_data jsonb; begin
 for s in select * from public.cms_sections where page_id='insights' and key='sectionTwo' and data#>>'{cards,1,path}'='#case-study-approach' for update loop
  next_data:=jsonb_set(s.data,'{cards,1,path}',to_jsonb('/case-studies/planning-an-open-deck-movement'::text));
  update public.cms_sections set data=next_data,revision=revision+1,updated_at=now() where page_id=s.page_id and key=s.key;
  insert into public.cms_history(actor,actor_id,page_id,section,revision,changes) values('System: publication links','00000000-0000-0000-0000-000000000000',s.page_id,s.key,s.revision+1,public.cms_diff(s.data,next_data));
 end loop;
end $$;
do $$ declare s public.cms_sections%rowtype; next_data jsonb; begin
 for s in select * from public.cms_sections where page_id='insights' and key='sectionTwo' and data#>>'{cards,2,path}'='#case-study-approach' for update loop
  next_data:=jsonb_set(s.data,'{cards,2,path}',to_jsonb('/case-studies/organizing-a-container-collection'::text));
  update public.cms_sections set data=next_data,revision=revision+1,updated_at=now() where page_id=s.page_id and key=s.key;
  insert into public.cms_history(actor,actor_id,page_id,section,revision,changes) values('System: publication links','00000000-0000-0000-0000-000000000000',s.page_id,s.key,s.revision+1,public.cms_diff(s.data,next_data));
 end loop;
end $$;
do $$ declare s public.cms_sections%rowtype; next_data jsonb; begin
 for s in select * from public.cms_sections where page_id='insights' and key='sectionOne' and data#>>'{action,path}'='/contact-us' for update loop
  next_data:=jsonb_set(s.data,'{action,path}',to_jsonb('/case-studies'::text));
  update public.cms_sections set data=next_data,revision=revision+1,updated_at=now() where page_id=s.page_id and key=s.key;
  insert into public.cms_history(actor,actor_id,page_id,section,revision,changes) values('System: publication links','00000000-0000-0000-0000-000000000000',s.page_id,s.key,s.revision+1,public.cms_diff(s.data,next_data));
 end loop;
end $$;

commit;
