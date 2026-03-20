-- Core tables migration for Orion Orb (Prompt28)
-- Run this in Supabase SQL Editor (Dashboard → SQL Editor → New query).
--
-- Tables created:
--   prompts          — user prompt history (two-way synced from iOS HistoryStore)
--   events           — analytics events (batched from iOS AnalyticsService)
--   telemetry_errors — structured error telemetry (batched from iOS TelemetryService)
--
-- Migrations for prompt_feedback and trending_prompts are in separate files.

-- ── prompts ────────────────────────────────────────────────────────────────────

create table if not exists prompts (
  id            uuid primary key,
  user_id       uuid not null references auth.users(id) on delete cascade,
  created_at    timestamptz not null,
  mode          text not null,
  input         text not null,
  professional  text not null,
  template      text not null,
  favorite      boolean not null default false,
  custom_name   text,
  last_modified timestamptz not null
);

alter table prompts enable row level security;

create policy "Users own their prompts"
  on prompts for all
  using (auth.uid() = user_id);

create index if not exists prompts_user_id_idx       on prompts(user_id);
create index if not exists prompts_created_at_idx    on prompts(created_at desc);
create index if not exists prompts_last_modified_idx on prompts(last_modified desc);

-- ── events ─────────────────────────────────────────────────────────────────────
-- Analytics events batched from iOS AnalyticsService.
-- user_id is nullable — events can be logged before sign-in.

create table if not exists events (
  id         uuid primary key default gen_random_uuid(),
  name       text not null,
  properties jsonb,
  timestamp  timestamptz not null default now(),
  user_id    uuid references auth.users(id) on delete set null
);

alter table events enable row level security;

-- Service role (used by iOS SDK anon key with RLS bypass for inserts) handles writes.
-- Read access is admin-only (no user-facing RLS read policy).
create policy "Authenticated users can insert events"
  on events for insert
  with check (auth.role() = 'authenticated' or auth.role() = 'anon');

create index if not exists events_user_id_idx   on events(user_id);
create index if not exists events_name_idx      on events(name);
create index if not exists events_timestamp_idx on events(timestamp desc);

-- ── telemetry_errors ───────────────────────────────────────────────────────────
-- Structured error records batched from iOS TelemetryService.
-- user_id nullable — errors can occur before sign-in.

create table if not exists telemetry_errors (
  id            uuid primary key default gen_random_uuid(),
  error_domain  text not null,
  error_code    text not null,
  error_message text not null,
  stack_trace   text,
  device_model  text not null,
  ios_version   text not null,
  app_version   text not null,
  app_state     text not null,
  timestamp     timestamptz not null,
  user_id       uuid references auth.users(id) on delete set null,
  session_id    text not null
);

alter table telemetry_errors enable row level security;

create policy "Authenticated users can insert telemetry"
  on telemetry_errors for insert
  with check (auth.role() = 'authenticated' or auth.role() = 'anon');

create index if not exists telemetry_user_id_idx   on telemetry_errors(user_id);
create index if not exists telemetry_domain_idx    on telemetry_errors(error_domain);
create index if not exists telemetry_timestamp_idx on telemetry_errors(timestamp desc);
