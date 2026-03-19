-- Migration: trending_prompts table
-- Phase 4: Real-Time Trending — curated prompts surfaced in the Trending tab.
-- Changes to this table are broadcast via Supabase Realtime to connected clients.
-- Run via: supabase db push  (or paste into Supabase Dashboard → SQL Editor)

create table if not exists trending_prompts (
    id           uuid         primary key default gen_random_uuid(),
    category     text         not null,          -- e.g. 'Work', 'School', 'Business', 'Fitness'
    title        text         not null,
    prompt       text         not null,
    use_count    bigint       not null default 0,
    is_active    boolean      not null default true,
    created_at   timestamptz  not null default now(),
    updated_at   timestamptz  not null default now()
);

-- Enable Supabase Realtime on this table (required for live updates)
alter publication supabase_realtime add table trending_prompts;

-- Indexes for common query patterns
create index if not exists trending_prompts_category_idx    on trending_prompts(category);
create index if not exists trending_prompts_use_count_idx   on trending_prompts(use_count desc);
create index if not exists trending_prompts_is_active_idx   on trending_prompts(is_active) where is_active = true;

-- RLS: read-only for all authenticated and anonymous users (curated content)
alter table trending_prompts enable row level security;

create policy "Trending prompts are publicly readable"
    on trending_prompts
    for select
    using (is_active = true);

-- Only service role (admin) can insert/update/delete
-- (Supabase Dashboard → service_role key, or Edge Functions with service client)

-- Seed a few starter prompts (optional — remove before production migration)
insert into trending_prompts (category, title, prompt) values
    ('Work',     'Cold Email Opener',      'Write a concise, personalized cold email opening line for [prospect] at [company] that references their recent [achievement/news] and connects it to how we can help them [goal].'),
    ('School',   'Essay Thesis Builder',   'Generate a strong thesis statement for an essay about [topic] that takes a clear stance, previews three supporting arguments, and is written for a [audience] audience.'),
    ('Business', 'Executive Summary',      'Write an executive summary for [project/product] aimed at [stakeholder type]. Highlight the problem, proposed solution, key metrics, timeline, and resource requirements. Keep it under 200 words.'),
    ('Fitness',  'Workout Plan Prompt',    'Design a 4-week progressive overload workout plan for someone who is [experience level] and wants to [goal]. Include sets, reps, and rest periods. Assume access to [equipment].'),
    ('Work',     'Meeting Agenda Drafter', 'Create a structured 45-minute meeting agenda for a [meeting type] with [attendees]. Include time blocks, talking points, decision items, and a clear goal for what "done" looks like.');
