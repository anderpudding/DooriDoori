-- Keep updated_at accurate for preference rows and mutable content tables.
-- This migration is additive and preserves existing data.
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists set_user_preferences_updated_at on public.user_preferences;
create trigger set_user_preferences_updated_at
before update on public.user_preferences
for each row
execute function public.set_updated_at();

drop trigger if exists set_content_items_updated_at on public.content_items;
create trigger set_content_items_updated_at
before update on public.content_items
for each row
execute function public.set_updated_at();

drop trigger if exists set_reviews_updated_at on public.reviews;
create trigger set_reviews_updated_at
before update on public.reviews
for each row
execute function public.set_updated_at();
