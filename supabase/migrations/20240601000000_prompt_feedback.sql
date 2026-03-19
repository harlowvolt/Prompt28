-- Migration: prompt_feedback table
-- Phase 4: RLHF data flywheel — stores thumbs up/down signals on generated prompts.
-- Run via: supabase db push  (or paste into Supabase Dashboard → SQL Editor)

create table if not exists prompt_feedback (
    id                uuid         primary key default gen_random_uuid(),
    user_id           uuid         references auth.users(id) on delete cascade,
    history_item_id   uuid,        -- references prompts(id) — nullable for orb-generated items
    input             text,        -- the raw user input
    professional      text,        -- the generated expert prompt that was rated
    thumbs_up         boolean      not null,
    created_at        timestamptz  not null default now()
);

-- Index for quick per-user lookups and analytics queries
create index if not exists prompt_feedback_user_id_idx on prompt_feedback(user_id);
create index if not exists prompt_feedback_created_at_idx on prompt_feedback(created_at desc);

-- RLS: users can only see and insert their own feedback rows
alter table prompt_feedback enable row level security;

create policy "Users own their feedback"
    on prompt_feedback
    for all
    using  (auth.uid() = user_id)
    with check (auth.uid() = user_id);

-- Optional: allow service role reads for analytics dashboards
-- (service role bypasses RLS by default — no extra policy needed)
