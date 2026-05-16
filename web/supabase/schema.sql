-- ============================================================
-- Tetamu App — Full Schema
-- Run this in Supabase SQL Editor to set up all tables.
-- ============================================================

-- Drop all tables (cascade removes dependent tables/policies/indexes)
drop table if exists public.photo_likes  cascade;
drop table if exists public.voice_notes  cascade;
drop table if exists public.photos       cascade;
drop table if exists public.guests       cascade;
drop table if exists public.contacts     cascade;
drop table if exists public.events       cascade;

-- ============================================================
-- Tables
-- ============================================================

-- 1. Events
create table public.events (
  id                    uuid primary key default gen_random_uuid(),
  user_id               uuid references auth.users(id) on delete set null,
  title                 text not null,
  host_name             text not null default '',
  location              text not null default '',
  starts_at             timestamp with time zone not null default now(),
  expires_at            timestamp with time zone,
  duration_hours        integer not null default 24,
  shots_per_guest       integer not null default 25,
  guest_limit           integer not null default 120,
  allow_voice_notes     boolean not null default true,
  voice_note_max_seconds integer not null default 120,
  filter_style          text not null default 'none' check (filter_style in ('none', 'vintage')),
  reveal_mode           text not null default 'At the end' check (reveal_mode in ('Immediately', 'At the end')),
  is_public             boolean not null default true,
  created_at            timestamp with time zone default now()
);

-- 2. Guests (no auth required)
create table public.guests (
  id          uuid primary key default gen_random_uuid(),
  event_id    uuid not null references public.events(id) on delete cascade,
  name        text not null,
  role        text not null default 'guest' check (role in ('organizer', 'guest')),
  shots_taken integer not null default 0,
  source      text default 'web',
  joined_at   timestamp with time zone default now()
);

-- 3. Photos (anonymous uploads)
create table public.photos (
  id            uuid primary key default gen_random_uuid(),
  event_id      uuid not null references public.events(id) on delete cascade,
  user_id       uuid references auth.users(id) on delete set null,
  guest_name    text,
  photo_url     text not null,
  source        text default 'web',
  is_deleted    boolean not null default false,
  expires_at    timestamp with time zone,
  created_at    timestamp with time zone default now()
);

-- 4. Voice notes
create table public.voice_notes (
  id         uuid primary key default gen_random_uuid(),
  event_id   uuid not null references public.events(id) on delete cascade,
  guest_name text not null,
  voice_url  text not null,
  source     text default 'web',
  created_at timestamp with time zone default now()
);

-- 5. Photo likes
create table public.photo_likes (
  id         uuid primary key default gen_random_uuid(),
  photo_id   uuid not null references public.photos(id) on delete cascade,
  guest_name text,
  created_at timestamp with time zone default now()
);

-- 6. Contact form submissions
create table public.contacts (
  id         uuid primary key default gen_random_uuid(),
  name       text not null,
  email      text not null,
  message    text not null,
  subjects   text[] not null default '{}',
  created_at timestamp with time zone default now()
);

-- ============================================================
-- Row Level Security
-- ============================================================

alter table public.events      enable row level security;
alter table public.guests      enable row level security;
alter table public.photos      enable row level security;
alter table public.voice_notes enable row level security;
alter table public.photo_likes enable row level security;
alter table public.contacts    enable row level security;

-- EVENTS
create policy "Anyone can view events"               on public.events for select using (true);
create policy "Anyone can create events"             on public.events for insert with check (true);
create policy "Hosts can update their events"        on public.events for update using (auth.uid() = user_id);
create policy "Hosts can delete their events"        on public.events for delete using (auth.uid() = user_id);

-- GUESTS
create policy "Anyone can view guests"               on public.guests for select using (true);
create policy "Anyone can join as guest"             on public.guests for insert with check (true);
create policy "Anyone can update guest record"       on public.guests for update using (true);

-- PHOTOS
create policy "Anyone can view photos"               on public.photos for select using (true);
create policy "Anyone can upload photos"             on public.photos for insert with check (true);
create policy "Anyone can delete photos"             on public.photos for delete using (true);

-- VOICE NOTES
create policy "Anyone can insert voice notes"        on public.voice_notes for insert with check (true);
create policy "Anyone can view voice notes"          on public.voice_notes for select using (true);

-- PHOTO LIKES
create policy "Anyone can view likes"                on public.photo_likes for select using (true);
create policy "Anyone can like photos"               on public.photo_likes for insert with check (true);

-- CONTACTS
create policy "Anyone can submit contact form"       on public.contacts for insert with check (true);

-- ============================================================
-- Indexes
-- ============================================================

create index events_created_at_idx      on public.events(created_at);
create index guests_event_id_idx        on public.guests(event_id);
create index photos_event_id_idx        on public.photos(event_id);
create index photos_created_at_idx      on public.photos(created_at);
create index voice_notes_event_id_idx   on public.voice_notes(event_id);
create index photo_likes_photo_id_idx   on public.photo_likes(photo_id);

-- ============================================================
-- Storage buckets + policies
-- ============================================================

insert into storage.buckets (id, name, public)
  values ('event-photos', 'event-photos', true)
  on conflict (id) do nothing;

insert into storage.buckets (id, name, public)
  values ('event-voice', 'event-voice', true)
  on conflict (id) do nothing;

-- Allow anyone to upload photos (iOS + web guests)
create policy "Anyone can upload event photos"
  on storage.objects for insert
  with check (bucket_id = 'event-photos');

-- Allow anyone to read photos (public gallery)
create policy "Anyone can read event photos"
  on storage.objects for select
  using (bucket_id = 'event-photos');

-- Allow anyone to upload voice notes
create policy "Anyone can upload voice notes"
  on storage.objects for insert
  with check (bucket_id = 'event-voice');

-- Allow anyone to read voice notes
create policy "Anyone can read voice notes"
  on storage.objects for select
  using (bucket_id = 'event-voice');
