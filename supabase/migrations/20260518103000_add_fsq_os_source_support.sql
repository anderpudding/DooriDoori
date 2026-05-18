-- Step 4: FSQ OS Places base POI import support.
-- FSQ OS rows are base POI candidates and remain unapproved until curated.

alter table public.content_items
drop constraint if exists content_items_source_type_check;

alter table public.content_items
add constraint content_items_source_type_check
check (
  source_type in (
    'curated',
    'manual',
    'fsq',
    'fsq_os',
    'google_places',
    'meetup',
    'eventbrite',
    'city_open_data',
    'city_van',
    'luma'
  )
);

alter table public.external_sources
drop constraint if exists external_sources_source_type_check;

alter table public.external_sources
add constraint external_sources_source_type_check
check (
  source_type in (
    'curated',
    'manual',
    'fsq',
    'fsq_os',
    'google_places',
    'meetup',
    'eventbrite',
    'city_open_data',
    'city_van',
    'luma'
  )
);

alter table public.api_import_logs
drop constraint if exists api_import_logs_source_type_check;

alter table public.api_import_logs
add constraint api_import_logs_source_type_check
check (
  source_type in (
    'curated',
    'manual',
    'fsq',
    'fsq_os',
    'google_places',
    'meetup',
    'eventbrite',
    'city_open_data',
    'city_van',
    'luma'
  )
);

insert into public.external_sources (source_type, display_name, base_url)
values ('fsq_os', 'FSQ OS Places', null)
on conflict (source_type) do update
set
  display_name = excluded.display_name,
  base_url = excluded.base_url;

create unique index if not exists idx_content_items_fsq_os_place_id_unique
on public.content_items ((source_refs->>'fsq_place_id'))
where source_type = 'fsq_os' and source_refs ? 'fsq_place_id';
