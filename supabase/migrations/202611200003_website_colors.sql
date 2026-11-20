-- Website palette. Defaults are extracted from lmi-website/src/index.css.
begin;
create table if not exists public.cms_colors (
 singleton boolean primary key default true check(singleton),
 colors jsonb not null, defaults jsonb not null,
 revision integer not null default 0,updated_at timestamptz not null default now()
);
alter table public.cms_colors enable row level security;
revoke all on public.cms_colors from anon,authenticated;
insert into public.cms_colors(singleton,colors,defaults) values(true,'{"brand-red": "#c22735", "brand-red-dark": "#b61a21", "brand-black": "#101213", "brand-charcoal": "#29282c", "brand-ink": "#1b1e22", "placeholder": "#d1d3d6", "surface": "#ffffff", "hero-stripe-light": "#eeeae2", "hero-stripe-dark": "#e6e1d8", "hero-heading": "#222120", "hero-copy": "#66615c", "hero-shadow": "#29282c1a", "trust-border": "#e9e5df", "surface-transparent": "#ffffff00", "proof-surface": "#f6f4ef", "proof-accent": "#ffae42", "action-amber-hover": "#ffc166", "proof-divider": "#e9e5dd", "editorial-border": "#d6cdbf", "process-number": "#ffe0b2", "equipment-badge": "#fff2da", "subtle-surface": "#f8fafc", "subtle-border": "#e2e8f0", "accent-surface": "#fffbeb", "accent-border": "#fde68a", "accent-strong": "#d97706", "accent-ink": "#78350f"}'::jsonb,'{"brand-red": "#c22735", "brand-red-dark": "#b61a21", "brand-black": "#101213", "brand-charcoal": "#29282c", "brand-ink": "#1b1e22", "placeholder": "#d1d3d6", "surface": "#ffffff", "hero-stripe-light": "#eeeae2", "hero-stripe-dark": "#e6e1d8", "hero-heading": "#222120", "hero-copy": "#66615c", "hero-shadow": "#29282c1a", "trust-border": "#e9e5df", "surface-transparent": "#ffffff00", "proof-surface": "#f6f4ef", "proof-accent": "#ffae42", "action-amber-hover": "#ffc166", "proof-divider": "#e9e5dd", "editorial-border": "#d6cdbf", "process-number": "#ffe0b2", "equipment-badge": "#fff2da", "subtle-surface": "#f8fafc", "subtle-border": "#e2e8f0", "accent-surface": "#fffbeb", "accent-border": "#fde68a", "accent-strong": "#d97706", "accent-ink": "#78350f"}'::jsonb) on conflict(singleton) do nothing;

create or replace function public.cms_public_colors() returns jsonb language sql stable security definer set search_path='' as $$ select colors from public.cms_colors where singleton $$;
revoke all on function public.cms_public_colors() from public;
grant execute on function public.cms_public_colors() to anon,authenticated;
create or replace function public.cms_admin_colors() returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
 if not public.cms_is_admin() then raise sqlstate 'PT403' using message='Administrator access required';end if;
 return (select jsonb_build_object('colors',colors,'defaults',defaults,'revision',revision) from public.cms_colors where singleton);
end $$;
create or replace function public.cms_save_colors(p_colors jsonb,p_expected_revision integer) returns jsonb language plpgsql security definer set search_path='' as $$
declare current_palette public.cms_colors%rowtype; item record;
begin
 if not public.cms_is_admin() then raise sqlstate 'PT403' using message='Administrator access required';end if;
 select * into strict current_palette from public.cms_colors where singleton for update;
 if current_palette.revision<>p_expected_revision then raise sqlstate 'PT409' using message='Colors changed in another session. Reload before saving.';end if;
 if jsonb_typeof(p_colors) is distinct from 'object' then raise sqlstate 'PT400' using message='Invalid color palette';end if;
 if (select count(*) from jsonb_object_keys(p_colors))<>(select count(*) from jsonb_object_keys(current_palette.defaults)) then raise sqlstate 'PT400' using message='Save the complete color palette';end if;
 for item in select key,value from jsonb_each(p_colors) loop
  if not current_palette.defaults ? item.key or jsonb_typeof(item.value)<>'string' or (item.value#>>'{}') !~ '^#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$' then raise sqlstate 'PT400' using message='Use six or eight digit hex colors for known palette fields';end if;
 end loop;
 if p_colors=current_palette.colors then return jsonb_build_object('revision',current_palette.revision,'unchanged',true);end if;
 update public.cms_colors set colors=p_colors,revision=revision+1,updated_at=now() where singleton;
 insert into public.cms_history(actor,actor_id,page_id,section,revision,changes) values(coalesce(auth.jwt()->>'email','admin'),auth.uid(),'site','colors',current_palette.revision+1,public.cms_diff(current_palette.colors,p_colors));
 return jsonb_build_object('revision',current_palette.revision+1);
end $$;
revoke all on function public.cms_admin_colors(),public.cms_save_colors(jsonb,integer) from public,anon;
grant execute on function public.cms_admin_colors(),public.cms_save_colors(jsonb,integer) to authenticated;
commit;
