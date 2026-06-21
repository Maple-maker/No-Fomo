-- Community Trade Ideas schema
-- Run in Supabase SQL Editor (project jmtkygwvmrolfvwueggs)

create table if not exists user_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default 'Trader',
  avatar_url text,
  reputation_score int not null default 0,
  current_streak int not null default 0,
  longest_streak int not null default 0,
  ideas_posted int not null default 0,
  ideas_resolved int not null default 0,
  win_count int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists trade_ideas (
  id bigserial primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  ticker text not null,
  body text not null check (char_length(body) <= 500),
  direction text not null check (direction in ('long', 'short')),
  entry_price numeric not null,
  target_price numeric not null,
  timeframe_days int not null default 30 check (timeframe_days > 0),
  status text not null default 'open' check (status in ('open', 'won', 'lost', 'expired')),
  performance_score numeric,
  upvote_count int not null default 0,
  reported_at timestamptz,
  created_at timestamptz not null default now(),
  resolved_at timestamptz
);

create index if not exists trade_ideas_created_at_idx on trade_ideas (created_at desc);
create index if not exists trade_ideas_user_id_idx on trade_ideas (user_id);
create index if not exists trade_ideas_status_idx on trade_ideas (status);

create table if not exists idea_votes (
  idea_id bigint not null references trade_ideas(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (idea_id, user_id)
);

alter table user_profiles enable row level security;
alter table trade_ideas enable row level security;
alter table idea_votes enable row level security;

create policy "profiles_public_read" on user_profiles
  for select using (true);

create policy "profiles_owner_write" on user_profiles
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "ideas_public_read" on trade_ideas
  for select using (status in ('open', 'won', 'lost'));

create policy "ideas_owner_insert" on trade_ideas
  for insert with check (auth.uid() = user_id);

create policy "ideas_owner_update" on trade_ideas
  for update using (auth.uid() = user_id);

create policy "ideas_owner_delete" on trade_ideas
  for delete using (auth.uid() = user_id);

create policy "votes_public_read" on idea_votes
  for select using (true);

create policy "votes_owner_insert" on idea_votes
  for insert with check (auth.uid() = user_id);

create policy "votes_owner_delete" on idea_votes
  for delete using (auth.uid() = user_id);

create or replace function ensure_user_profile()
returns trigger language plpgsql security definer as $$
begin
  insert into user_profiles (user_id, display_name)
  values (new.user_id, coalesce(new.raw_user_meta_data->>'full_name', 'Trader'))
  on conflict (user_id) do nothing;
  return new;
end;
$$;

-- Optional: auto-create profile on signup (run once if trigger not present)
-- create trigger on_auth_user_created
--   after insert on auth.users
--   for each row execute function ensure_user_profile();
