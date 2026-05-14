-- Required extension for gen_random_uuid()
create extension if not exists "pgcrypto";

-- 1. User preferences
create table if not exists public.user_preferences (
  user_id uuid primary key references auth.users(id) on delete cascade,

  preferred_categories text[] not null default '{}',
  preferred_areas text[] not null default '{}',
  budget_level text not null default 'any'
    check (budget_level in ('low', 'medium', 'high', 'any')),

  vibe_tags text[] not null default '{}',
  activity_tags text[] not null default '{}',

  language_preference text not null default 'korean_friendly'
    check (language_preference in ('korean_friendly', 'english_okay', 'any')),
  travel_preference text not null default 'any'
    check (travel_preference in ('walking_friendly', 'transit_friendly', 'driving_friendly', 'any')),

  negative_tags text[] not null default '{}',
  onboarding_completed boolean not null default false,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- 2. Unified content items
create table if not exists public.content_items (
  id uuid primary key default gen_random_uuid(),

  title text not null,
  type text not null check (type in ('place', 'event', 'lifestyle')),
  category text not null check (category in ('food', 'events', 'lifestyle')),

  subcategories text[] not null default '{}',
  area text not null,
  city text,
  address text,

  lat double precision,
  lng double precision,

  budget_level text not null default 'any'
    check (budget_level in ('low', 'medium', 'high', 'any')),

  vibe_tags text[] not null default '{}',
  activity_tags text[] not null default '{}',

  short_description text,
  detail_description text,

  image_url text,

  source_type text not null default 'curated'
    check (source_type in ('curated', 'fsq', 'google_places', 'meetup', 'eventbrite', 'luma', 'city_open_data')),
  source_refs jsonb not null default '{}',

  quality_score numeric not null default 0
    check (quality_score >= 0 and quality_score <= 1),
  korean_community_fit numeric not null default 0
    check (korean_community_fit >= 0 and korean_community_fit <= 1),

  is_active boolean not null default true,
  is_approved boolean not null default false,

  view_count integer not null default 0 check (view_count >= 0),
  save_count integer not null default 0 check (save_count >= 0),
  review_count integer not null default 0 check (review_count >= 0),
  average_rating numeric not null default 0
    check (average_rating >= 0 and average_rating <= 5),

  start_at timestamptz,
  end_at timestamptz,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- 3. Saved items
create table if not exists public.saved_items (
  id uuid primary key default gen_random_uuid(),

  user_id uuid not null references auth.users(id) on delete cascade,
  content_id uuid not null references public.content_items(id) on delete cascade,

  created_at timestamptz not null default now(),

  unique (user_id, content_id)
);

-- 4. Reviews
create table if not exists public.reviews (
  id uuid primary key default gen_random_uuid(),

  user_id uuid not null references auth.users(id) on delete cascade,
  content_id uuid not null references public.content_items(id) on delete cascade,

  rating integer not null check (rating >= 1 and rating <= 5),
  comment text,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  unique (user_id, content_id)
);

-- 5. User interactions
create table if not exists public.user_interactions (
  id uuid primary key default gen_random_uuid(),

  user_id uuid references auth.users(id) on delete cascade,
  content_id uuid not null references public.content_items(id) on delete cascade,

  interaction_type text not null check (
    interaction_type in ('view', 'save', 'unsave', 'review', 'skip', 'click')
  ),

  metadata jsonb not null default '{}',

  created_at timestamptz not null default now()
);

-- 6. Recommendation results
create table if not exists public.recommendation_results (
  id uuid primary key default gen_random_uuid(),

  user_id uuid not null references auth.users(id) on delete cascade,
  content_id uuid not null references public.content_items(id) on delete cascade,

  rank integer not null check (rank >= 1),
  final_score numeric not null,
  deterministic_score numeric,
  gemini_confidence numeric check (gemini_confidence is null or (gemini_confidence >= 0 and gemini_confidence <= 1)),

  score_breakdown jsonb not null default '{}',
  reason text,
  model_name text,

  generated_at timestamptz not null default now()
);

-- Helpful indexes
create index if not exists idx_content_items_category on public.content_items(category);
create index if not exists idx_content_items_area on public.content_items(area);
create index if not exists idx_content_items_active_approved on public.content_items(is_active, is_approved);
create index if not exists idx_content_items_vibe_tags on public.content_items using gin(vibe_tags);
create index if not exists idx_content_items_activity_tags on public.content_items using gin(activity_tags);

create index if not exists idx_saved_items_user_id on public.saved_items(user_id);
create index if not exists idx_reviews_content_id on public.reviews(content_id);
create index if not exists idx_user_interactions_user_id on public.user_interactions(user_id);
create index if not exists idx_user_interactions_content_id on public.user_interactions(content_id);
create index if not exists idx_recommendation_results_user_id on public.recommendation_results(user_id);

-- Enable RLS
alter table public.user_preferences enable row level security;
alter table public.content_items enable row level security;
alter table public.saved_items enable row level security;
alter table public.reviews enable row level security;
alter table public.user_interactions enable row level security;
alter table public.recommendation_results enable row level security;

-- user_preferences
create policy "Users can read their own preferences"
on public.user_preferences
for select
using (auth.uid() = user_id);

create policy "Users can insert their own preferences"
on public.user_preferences
for insert
with check (auth.uid() = user_id);

create policy "Users can update their own preferences"
on public.user_preferences
for update
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

-- content_items
create policy "Users can read active approved content"
on public.content_items
for select
using (is_active = true and is_approved = true);

-- saved_items
create policy "Users can read their own saved items"
on public.saved_items
for select
using (auth.uid() = user_id);

create policy "Users can save their own items"
on public.saved_items
for insert
with check (auth.uid() = user_id);

create policy "Users can unsave their own items"
on public.saved_items
for delete
using (auth.uid() = user_id);

-- reviews
create policy "Users can read reviews"
on public.reviews
for select
using (true);

create policy "Users can create their own reviews"
on public.reviews
for insert
with check (auth.uid() = user_id);

create policy "Users can update their own reviews"
on public.reviews
for update
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

create policy "Users can delete their own reviews"
on public.reviews
for delete
using (auth.uid() = user_id);

-- user_interactions
create policy "Users can read their own interactions"
on public.user_interactions
for select
using (auth.uid() = user_id);

create policy "Users can create their own interactions"
on public.user_interactions
for insert
with check (auth.uid() = user_id);

-- recommendation_results
create policy "Users can read their own recommendation results"
on public.recommendation_results
for select
using (auth.uid() = user_id);