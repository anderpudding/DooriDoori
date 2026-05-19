-- Phase A source/import tracking foundation for future data integrations.
-- This migration adds metadata tables only; it does not integrate external APIs.

alter table public.content_items
drop constraint if exists content_items_source_type_check;

alter table public.content_items
add constraint content_items_source_type_check
check (source_type in ('curated', 'manual', 'fsq', 'google_places', 'meetup', 'eventbrite', 'luma', 'city_open_data'));

create table if not exists public.external_sources (
  id uuid primary key default gen_random_uuid(),

  source_type text not null unique
    check (source_type in ('curated', 'manual', 'fsq', 'google_places', 'meetup', 'eventbrite', 'luma', 'city_open_data')),
  display_name text not null,
  base_url text,
  config jsonb not null default '{}',
  is_active boolean not null default true,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.api_import_logs (
  id uuid primary key default gen_random_uuid(),

  source_type text not null
    check (source_type in ('curated', 'manual', 'fsq', 'google_places', 'meetup', 'eventbrite', 'luma', 'city_open_data')),
  external_source_id uuid references public.external_sources(id) on delete set null,

  status text not null
    check (status in ('started', 'running', 'succeeded', 'failed', 'partial')),
  inserted_count integer not null default 0 check (inserted_count >= 0),
  updated_count integer not null default 0 check (updated_count >= 0),
  failed_count integer not null default 0 check (failed_count >= 0),
  error_message text,
  metadata jsonb not null default '{}',

  started_at timestamptz not null default now(),
  finished_at timestamptz
);

insert into public.external_sources (source_type, display_name, base_url)
values
  ('curated', 'DooriDoori curated dataset', null),
  ('manual', 'Manual editorial entries', null),
  ('fsq', 'FSQ OS Places', null),
  ('google_places', 'Google Places', 'https://places.googleapis.com'),
  ('meetup', 'Meetup', 'https://api.meetup.com'),
  ('eventbrite', 'Eventbrite', 'https://www.eventbriteapi.com'),
  ('luma', 'Luma', 'https://lu.ma'),
  ('city_open_data', 'City of Vancouver Open Data', 'https://opendata.vancouver.ca')
on conflict (source_type) do update
set
  display_name = excluded.display_name,
  base_url = excluded.base_url;

create index if not exists idx_content_items_source_type on public.content_items(source_type);
create index if not exists idx_content_items_source_refs on public.content_items using gin(source_refs);
create index if not exists idx_saved_items_content_id on public.saved_items(content_id);
create index if not exists idx_user_interactions_interaction_type on public.user_interactions(interaction_type);
create index if not exists idx_api_import_logs_source_type on public.api_import_logs(source_type);
create index if not exists idx_api_import_logs_status on public.api_import_logs(status);
create index if not exists idx_api_import_logs_source_status on public.api_import_logs(source_type, status);
create index if not exists idx_api_import_logs_started_at on public.api_import_logs(started_at);

alter table public.external_sources enable row level security;
alter table public.api_import_logs enable row level security;

drop trigger if exists set_external_sources_updated_at on public.external_sources;
create trigger set_external_sources_updated_at
before update on public.external_sources
for each row
execute function public.set_updated_at();
