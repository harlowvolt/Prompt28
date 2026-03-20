-- Fix migration: ensure events and telemetry_errors have all required columns.
--
-- WHY: The initial migration (20240101000000_core_tables.sql) used CREATE TABLE IF NOT EXISTS.
-- If these tables already existed in your Supabase project with a different schema,
-- the CREATE was silently skipped and required columns were never added.
-- This migration adds the missing columns safely (ALTER TABLE ... ADD COLUMN IF NOT EXISTS).
--
-- Symptoms fixed:
--   [Analytics] Upload failed: Could not find the 'name' column of 'events'
--   [Telemetry] Upload failed: Could not find the 'app_state' column of 'telemetry_errors'
--
-- Safe to run even if the columns already exist.

-- ── events ─────────────────────────────────────────────────────────────────────

alter table events add column if not exists name       text;
alter table events add column if not exists properties jsonb;
alter table events add column if not exists timestamp  timestamptz;
alter table events add column if not exists user_id    uuid references auth.users(id) on delete set null;

-- Ensure RLS is on (no-op if already enabled)
alter table events enable row level security;

-- Add insert policy if not already present
do $$
begin
  if not exists (
    select 1 from pg_policies
    where tablename = 'events'
      and policyname = 'Authenticated users can insert events'
  ) then
    execute $policy$
      create policy "Authenticated users can insert events"
        on events for insert
        with check (auth.role() = 'authenticated' or auth.role() = 'anon')
    $policy$;
  end if;
end$$;

create index if not exists events_name_idx      on events(name);
create index if not exists events_timestamp_idx on events(timestamp desc);
create index if not exists events_user_id_idx   on events(user_id);

-- ── telemetry_errors ───────────────────────────────────────────────────────────

alter table telemetry_errors add column if not exists error_domain  text;
alter table telemetry_errors add column if not exists error_code    text;
alter table telemetry_errors add column if not exists error_message text;
alter table telemetry_errors add column if not exists stack_trace   text;
alter table telemetry_errors add column if not exists device_model  text;
alter table telemetry_errors add column if not exists ios_version   text;
alter table telemetry_errors add column if not exists app_version   text;
alter table telemetry_errors add column if not exists app_state     text;
alter table telemetry_errors add column if not exists timestamp     timestamptz;
alter table telemetry_errors add column if not exists user_id       uuid references auth.users(id) on delete set null;
alter table telemetry_errors add column if not exists session_id    text;

alter table telemetry_errors enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where tablename = 'telemetry_errors'
      and policyname = 'Authenticated users can insert telemetry'
  ) then
    execute $policy$
      create policy "Authenticated users can insert telemetry"
        on telemetry_errors for insert
        with check (auth.role() = 'authenticated' or auth.role() = 'anon')
    $policy$;
  end if;
end$$;

create index if not exists telemetry_user_id_idx   on telemetry_errors(user_id);
create index if not exists telemetry_domain_idx    on telemetry_errors(error_domain);
create index if not exists telemetry_timestamp_idx on telemetry_errors(timestamp desc);
