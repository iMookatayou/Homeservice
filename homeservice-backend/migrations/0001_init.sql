-- enable uuid if available
create extension if not exists "pgcrypto";

create table if not exists users (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  email text not null unique,
  password_hash text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists user_settings (
  user_id uuid primary key references users(id) on delete cascade,
  locale text default 'th-TH',
  unit_temp text default 'C',
  unit_distance text default 'km',
  home_lat double precision,
  home_lon double precision,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists weather_cache (
  id bigserial primary key,
  lat double precision not null,
  lon double precision not null,
  kind text not null check (kind in ('today','forecast')),
  provider text not null default 'openweather',
  payload jsonb not null,
  fetched_at timestamptz not null default now()
);
create index if not exists weather_cache_idx on weather_cache (lat, lon, kind, fetched_at desc);
