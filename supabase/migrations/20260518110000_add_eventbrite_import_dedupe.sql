-- Step 5: Eventbrite organizer/organization event import support.
-- Eventbrite rows are pending curation and deduped by external event id.

insert into public.external_sources (source_type, display_name, base_url)
values ('eventbrite', 'Eventbrite', 'https://www.eventbriteapi.com')
on conflict (source_type) do update
set
  display_name = excluded.display_name,
  base_url = excluded.base_url;

create unique index if not exists idx_content_items_eventbrite_external_id_unique
on public.content_items ((source_refs->>'external_id'))
where source_type = 'eventbrite' and source_refs ? 'external_id';
