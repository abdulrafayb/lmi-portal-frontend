-- Optional cleanup for projects that applied the previous email-backend migration.
-- Removes obsolete operational counters only; CMS content/history remain intact.
begin;
drop function if exists public.quote_consume_limit(text);
drop table if exists public.quote_rate_limits;
-- Retain custom notes, replacing only the old built-in email-draft instruction.
do $$ declare section public.cms_sections%rowtype; new_data jsonb;
begin
 select * into section from public.cms_sections where page_id='contact-us' and key='sectionTwo' for update;
 if section.data->>'note'='This form prepares an email draft. Send it from your email app to submit your request; our team will then review it and contact you using the details provided.' then
   new_data := jsonb_set(section.data,'{note}','"Submit your requirement directly to LMI. Our team will review it and contact you using the details provided."');
   update public.cms_sections set data=new_data,revision=revision+1,updated_at=now() where page_id=section.page_id and key=section.key;
   insert into public.cms_history(actor,actor_id,page_id,section,revision,changes)
   values('System: Formspree quote form enabled','00000000-0000-0000-0000-000000000000'::uuid,section.page_id,section.key,section.revision+1,public.cms_diff(section.data,new_data));
 end if;
end $$;
commit;
