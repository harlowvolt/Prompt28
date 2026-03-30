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

-- Seed the full catalog of prompts
WITH json_data AS (
  SELECT $json$
{
  "categories": [
    {
      "key": "school",
      "name": "School",
      "items": [
        {
          "id": "s1",
          "title": "Argue Against Your Own Essay",
          "prompt": "I just wrote an essay arguing [your position] about [topic]. Now I want you to play a brilliant, ruthless critic and make the strongest possible case AGAINST my argument. Don't hold back. Find every weakness, logical gap, missing evidence, and assumption I made. Then tell me exactly which parts I need to fix to make my essay bulletproof."
        },
        {
          "id": "s2",
          "title": "Teach It Wrong So I Learn It Right",
          "prompt": "I'm studying [concept] in [subject]. I'm going to explain it to you as if I understand it, but I probably have some things wrong or incomplete. Here's my explanation: [your explanation]. Tell me exactly where I'm wrong, what I'm missing, and what the common misconceptions are that students have about this — then give me the correct understanding in plain language."
        },
        {
          "id": "s3",
          "title": "Socratic Tutor Mode",
          "prompt": "I need to deeply understand [concept/topic] for [class]. Don't explain it to me directly. Instead, ask me a series of Socratic questions that guide me to figure it out myself. Start with what I already know, then push me deeper. If I get something wrong, don't correct me — just ask a question that helps me discover the flaw in my thinking. Keep going until I've arrived at a solid understanding on my own."
        },
        {
          "id": "s4",
          "title": "Grade My Work Like My Professor Will",
          "prompt": "Here is my [essay/assignment/answer]: [paste your work]. My professor is [describe their style — harsh, detail-focused, cares about thesis clarity, etc.] and the rubric/criteria is [describe it]. Grade this exactly like my professor would. Give it a letter grade, mark every weakness they would mark, and tell me the 3 most important things I need to fix before I submit it tomorrow."
        },
        {
          "id": "s5",
          "title": "Turn Any Textbook Into a Story",
          "prompt": "I have to learn [topic] from [subject] but the textbook is putting me to sleep. Take this concept and turn it into a compelling, memorable story or narrative with real characters, tension, and stakes. The story should make the key ideas impossible to forget. Then at the end, bullet-point the actual facts I need to remember for the exam. Here's the concept: [paste it or describe it]."
        },
        {
          "id": "s6",
          "title": "Pre-Exam Weak Spot Finder",
          "prompt": "I have an exam on [subject/topic] in [X days]. I've been studying, but I know there are gaps in my knowledge I'm not even aware of. Ask me 15 increasingly difficult questions that cover the most commonly tested and most commonly missed concepts in this topic. After I answer each one, tell me if I'm right, what I got wrong, and what the correct understanding is. At the end, give me a list of my top 3 weak areas to focus on before the exam."
        },
        {
          "id": "s7",
          "title": "The 5-Year-Old to PhD Pipeline",
          "prompt": "Explain [concept] to me starting at the absolute simplest possible level — like I'm 5. Then explain it again like I'm in high school. Then like I'm a college student. Then like I'm a grad student. Each explanation should add a layer of real depth and nuance. I want to feel the concept click at every level before I move on."
        },
        {
          "id": "s8",
          "title": "Find the Hidden Pattern",
          "prompt": "I'm struggling to see the bigger picture in [subject/unit]. I've learned [list the topics or chapters], but they feel like disconnected facts. Show me the underlying pattern or framework that connects all of these ideas together. What's the one big idea that, once I understand it, makes all of these smaller concepts make sense? Then draw me a simple mental map of how everything connects."
        },
        {
          "id": "s9",
          "title": "Make Me a Devil's Advocate",
          "prompt": "The topic for my class debate/essay is [topic] and I have to argue [position you've been assigned — even if you disagree with it]. I don't personally believe this position. Help me become a true believer for the next [time period]. Give me the most compelling arguments, the best evidence, the strongest emotional framing, and the key counterarguments I need to have ready. Make me so prepared that I could convince anyone."
        },
        {
          "id": "s10",
          "title": "The Night-Before Cheat Sheet",
          "prompt": "My exam on [subject/topic] is tomorrow and I only have [X hours] left to study. Based on what's typically most important and most commonly tested in this subject, build me the most strategic, high-density study cheat sheet possible. Prioritize: concepts that show up most on exams, formulas or frameworks I must have memorized, common trick questions and how to spot them, and the 5 things students always forget. One page only. Make every word count."
        },
        {
          "id": "s11",
          "title": "Rewrite My Notes Into a Narrative",
          "prompt": "Here are my messy class notes from [subject]: [paste notes]. They're all over the place. Rewrite them as a clean, flowing narrative that tells the story of what was taught — like a well-written textbook section. Fill in any obvious gaps, connect the ideas logically, and highlight the 3 most important takeaways in bold. I want notes I'd actually want to read."
        },
        {
          "id": "s12",
          "title": "Find My Blind Spots Before My Professor Does",
          "prompt": "I'm writing a [research paper/essay] on [topic] and I think my argument is solid. Here it is: [paste your thesis or outline]. What are the most obvious counterarguments a smart, skeptical professor would raise that I haven't addressed? What evidence am I probably missing? What assumptions am I making without realizing it? Give me the 5 most dangerous weaknesses in my argument right now."
        },
        {
          "id": "s13",
          "title": "The Memory Palace Builder",
          "prompt": "I need to memorize [list of facts, dates, terms, formulas] for [class/exam]. Build me a vivid, weird, specific memory palace or story that encodes all of these facts in a way my brain won't forget. Make it bizarre and visual — the stranger the better. Then test me at the end by asking me to recall each item using the cues you built."
        },
        {
          "id": "s14",
          "title": "Simulate My Oral Exam",
          "prompt": "I have an oral exam / presentation / defense on [topic] coming up. Play the role of a tough but fair professor or panel member. Ask me real questions you'd expect in this kind of exam — start with broad conceptual questions, then get specific, then try to trip me up with edge cases and follow-up questions. After I answer, give me feedback on what I got right, what was weak, and what a top student would have said instead."
        },
        {
          "id": "s15",
          "title": "Turn My Struggle Into a System",
          "prompt": "I keep failing at [specific academic struggle — e.g., procrastinating on papers, blanking on exams, not retaining readings]. I've tried [what you've already tried] and it hasn't worked. Don't give me generic advice. Diagnose the actual root cause of my specific problem based on what I've described, then give me a concrete, step-by-step system I can start using this week — with exact times, triggers, and what to do when I fall off."
        }
      ]
    },
    {
      "key": "work",
      "name": "Work",
      "items": [
        {
          "id": "w1",
          "title": "Pre-Mortem Your Project",
          "prompt": "I'm about to launch / present / start [project or initiative]. Before I do, I want to run a pre-mortem. Imagine it's 6 months from now and this project has completely failed. Walk me through the most likely reasons it failed — be specific and brutally honest. What warning signs would have been there early? What did I probably overlook or underestimate? Now help me build a plan to prevent each of those failure modes before they happen."
        },
        {
          "id": "w2",
          "title": "Play My Toughest Stakeholder",
          "prompt": "I have to present [idea/proposal/project] to [person or group — e.g., a skeptical executive, a budget committee, a client who hates change]. Before I do, play that person. Ask me every hard question they would ask, push back on every weak point, bring up every objection and concern they'd raise. After the simulation, tell me the 3 places where my pitch fell apart and exactly what I should say instead."
        },
        {
          "id": "w3",
          "title": "Write Your Boss's Review of You",
          "prompt": "I have my performance review coming up. Based on what I'm about to describe about my work and my relationship with my manager, write the performance review my boss is likely to write about me — both the positive parts they'll highlight and the criticism they're too polite to say directly. Here's my situation: [describe your role, your wins, your relationship with your boss, any tension]. Then tell me what I should say in my self-review to get ahead of the criticism and reframe my weaknesses before they do."
        },
        {
          "id": "w4",
          "title": "Kill the Meeting",
          "prompt": "I have a meeting scheduled about [topic] with [attendees]. Before I send the invite, help me figure out if this meeting actually needs to happen. Ask me questions to determine if this could be an email, a Slack message, or a 5-minute async video instead. If the meeting is truly necessary, tell me exactly how to structure it so it takes half the time it normally would, with a clear agenda, a decision to be made, and an action owner for every outcome."
        },
        {
          "id": "w5",
          "title": "The Feedback You're Too Scared to Give",
          "prompt": "I need to give difficult feedback to [person — colleague, direct report, boss] about [issue]. I've been avoiding it because [reason — I don't want conflict, they get defensive, I'm not sure how to say it]. Help me figure out: 1) whether my feedback is actually fair and well-founded or if I'm missing something, 2) the exact words I should use to open the conversation without triggering defensiveness, 3) how to handle the 3 most likely reactions they'll have, and 4) how to end the conversation with the relationship intact."
        },
        {
          "id": "w6",
          "title": "Rewrite Your Job Around Your Strengths",
          "prompt": "Here's what my job officially requires me to do: [job description or list of responsibilities]. Here's what I'm actually good at and energized by: [your strengths]. Here's what drains me: [your weaknesses or drains]. Help me figure out how to subtly reshape my role so I'm doing more of what I'm great at without officially changing my title or asking permission. What tasks can I reframe, delegate, automate, or volunteer for that would shift my day-to-day toward my strengths?"
        },
        {
          "id": "w7",
          "title": "The Difficult Email You Keep Avoiding",
          "prompt": "I've been putting off sending an email to [person] about [situation]. Every draft I write either sounds too aggressive, too passive, or too long. Here's the situation: [explain everything]. Here's what I need the outcome to be: [desired result]. Write me 3 versions of this email — one direct and no-nonsense, one diplomatic and warm, one firm but professionally cautious. Tell me which one you'd recommend and why."
        },
        {
          "id": "w8",
          "title": "Find What's Actually Wasting Your Day",
          "prompt": "Here's how I typically spend my workday: [describe your schedule, tasks, meetings, and interruptions]. I feel busy all the time but I'm not making progress on what actually matters. Audit my day and tell me: what tasks am I probably overinvesting in that aren't moving the needle, what should I be doing more of, what should I stop doing entirely, and what's one structural change I could make this week that would have the highest impact on my output?"
        },
        {
          "id": "w9",
          "title": "Turn Conflict Into Alignment",
          "prompt": "I'm in a conflict with [person/team] at work over [issue]. My position is [your view]. Their position is [their view]. I think they're wrong but I know pushing harder isn't working. Help me do three things: 1) steelman their position — make the strongest version of their argument so I can understand what they actually care about, 2) find the hidden shared interest underneath our conflicting positions, and 3) give me a concrete opening to the next conversation that gets us into problem-solving mode instead of debate mode."
        },
        {
          "id": "w10",
          "title": "Make Your Work Undeniable",
          "prompt": "I'm doing great work but I don't think my manager or leadership notices. Here's what I've accomplished in the last [timeframe]: [list your wins, projects, contributions]. Help me do three things: 1) reframe these accomplishments in the business language my leadership cares about (impact, revenue, efficiency, risk reduction), 2) identify the wins I'm underselling, and 3) write me a brief that I could use in a 1:1 or send proactively that makes my value impossible to overlook."
        },
        {
          "id": "w11",
          "title": "The Promotion Conversation",
          "prompt": "I want to ask for a promotion to [target title/level]. I've been in my current role for [time], and here's what I've accomplished: [list]. My company's promotion criteria is [describe what you know about it]. Help me prepare for this conversation: what's the strongest case I can make, what will my manager likely push back on, what data or examples do I need to bring, and what's the exact opening I should use to start this conversation without it feeling like an ultimatum?"
        },
        {
          "id": "w12",
          "title": "Spot the Political Landmine",
          "prompt": "I'm about to [action — send a proposal, escalate an issue, hire someone, change a process] at work, and I have a feeling there's political complexity I'm not fully seeing. Here's the situation: [describe the context, the people involved, the org dynamics]. Help me map out who the key stakeholders are, who might feel threatened or bypassed, where the hidden resistance will come from, and what I should do before I move forward to avoid blowing up a relationship I can't afford to lose."
        },
        {
          "id": "w13",
          "title": "Say No Without Burning Bridges",
          "prompt": "I need to say no to [request — a project, a meeting, a favor, extra work] from [person — boss, colleague, client]. The problem is I can't afford to seem unhelpful or uncommitted. Help me craft a response that says no to the specific ask while keeping the relationship strong, offering something useful in its place if appropriate, and leaving them feeling respected rather than rejected. Give me 3 versions depending on how much I want to explain myself."
        },
        {
          "id": "w14",
          "title": "Build Your Reputation Without Bragging",
          "prompt": "I want people at work to know I'm excellent at [skill/area] without me having to tell them directly. I'm not good at self-promotion and it feels gross to me. Give me 5 specific, non-cringey strategies to build my reputation for [skill] organically — through how I show up in meetings, how I communicate, what I volunteer for, and how I help others — so that people arrive at the conclusion themselves."
        },
        {
          "id": "w15",
          "title": "What Your Exit Interview Should Have Said",
          "prompt": "I'm currently in a job I'm thinking about leaving, or I just left one. Here's my situation: [describe the job, the problems, what went wrong or what you're unhappy about]. I want to process this honestly. Help me figure out: what was actually wrong vs. what was just hard, what am I going to bring with me to my next role if I don't examine it, what would have needed to be true for me to stay, and what do I genuinely need in my next role that I've never actually asked for directly?"
        }
      ]
    },
    {
      "key": "business",
      "name": "Business",
      "items": [
        {
          "id": "b1",
          "title": "Kill Your Own Startup",
          "prompt": "Here's my startup idea: [describe your business]. I need you to try to kill it. Play the role of the most experienced, most skeptical venture capitalist who has seen a thousand companies fail. What's the fatal flaw in my business model? What assumption am I making that's almost certainly wrong? Who's going to eat my lunch, and why? What does the graveyard of companies who tried this look like? Then — after you've destroyed it — tell me what would need to be true for this to actually work."
        },
        {
          "id": "b2",
          "title": "The 1-Star Review You'll Get",
          "prompt": "My product/service is [describe it]. I want you to write the 5 most scathing, specific, realistic 1-star reviews I'm going to receive in my first year. Don't be generic — write them like a real frustrated customer who paid money and felt let down. Then tell me: which of these reviews represents the most dangerous problem for my business, and what would I need to change about my product, pricing, or expectations-setting to prevent each one?"
        },
        {
          "id": "b3",
          "title": "The Anti-Pitch",
          "prompt": "I'm building [business/product]. I want you to help me make the strongest possible case for why someone should NOT invest in, buy from, or partner with me. What are the real risks? What are the honest weaknesses? What would a brilliant, well-informed person say to talk someone OUT of working with my company? Once you've made that case, help me figure out which of those concerns are legitimate things I need to fix and which ones are just FUD I can address with better communication."
        },
        {
          "id": "b4",
          "title": "Find the Customer Nobody's Serving",
          "prompt": "My industry is [describe your industry/market]. I want to find the underserved customer — the segment that every competitor is ignoring or serving badly. Walk me through a framework for mapping who the current customers are, who's frustrated with existing solutions, who's been priced out or talked down to, and where there's a real gap between what people need and what they can actually get. Then give me your best hypothesis for the most promising underserved segment in my market."
        },
        {
          "id": "b5",
          "title": "The Pricing Gut-Check",
          "prompt": "I'm pricing my [product/service] at [your price]. My target customer is [describe them] and my main competitors charge [range]. I want you to pressure-test this. Tell me: is this price anchoring me as a commodity or a premium product, what does this price signal about my brand, what's the psychological response my ideal customer will have when they see it, and what would happen to my conversion, my positioning, and my profit margin if I raised my price by 3x? Make a case for why I'm probably undercharging."
        },
        {
          "id": "b6",
          "title": "What's Your Unfair Advantage?",
          "prompt": "Here's my background, my network, my resources, and my business idea: [describe everything honestly]. I want you to identify my genuine unfair advantages — the things I have access to that most people starting this business wouldn't. Not generic stuff like 'passion' or 'work ethic.' Real, specific advantages. Then tell me where my business model doesn't actually leverage those advantages — because that's where I'm leaving money on the table."
        },
        {
          "id": "b7",
          "title": "Map the Real Decision Maker",
          "prompt": "I'm trying to sell [product/service] to [target company type or customer]. I think the decision maker is [who you think it is]. Help me map the real buying process: who's the economic buyer, who's the technical buyer, who's the champion who will sell internally for me, who's the blocker I haven't identified yet, and what does each of them actually care about? Then help me build a sales strategy that addresses each person's real concern, not just the person I'm pitching to."
        },
        {
          "id": "b8",
          "title": "Reverse-Engineer a Competitor's Strategy",
          "prompt": "My competitor is [name or describe them]. They're winning in [specific area] and I want to understand why. Based on what I can observe about them — their pricing, their marketing, their product, their customers — help me reverse-engineer what their strategy actually is. What are they optimizing for that I'm not? What trade-offs have they made? What's the thing they're doing that looks obvious in hindsight that I could apply to my business right now?"
        },
        {
          "id": "b9",
          "title": "The 10x Revenue Question",
          "prompt": "My business currently does [describe your revenue/stage]. I want you to ask me the 10x question: what would have to be true for my business to do 10 times more revenue? Don't tell me to 'work harder' or 'get more customers.' I want you to help me identify: is this a distribution problem, a pricing problem, a product problem, or a market size problem? Then give me the one lever that, if I pulled it correctly, would have the most dramatic effect on my growth."
        },
        {
          "id": "b10",
          "title": "Turn Your Weakness Into a Brand",
          "prompt": "Here's something about my business that I consider a weakness or limitation: [describe it — you're small, you're expensive, you're slow, you're new, you only serve a niche]. Most businesses try to hide this. Help me figure out how to turn this into my biggest differentiator. Show me examples of how other brands have made their apparent weakness their most powerful positioning, then help me craft the language that turns my limitation into a reason to choose me over everyone else."
        },
        {
          "id": "b11",
          "title": "The First 100 Customers Plan",
          "prompt": "My business is [describe it] and I have zero customers yet. I don't have a big budget and I don't want to run ads. Walk me through the most direct, creative, non-scalable way to get my first 100 customers — the kind of tactics that don't work at scale but work incredibly well when you're small and scrappy. Be specific about where to find these people, exactly what to say to them, and what offer or hook would make them say yes right now."
        },
        {
          "id": "b12",
          "title": "Design Your Referral Engine",
          "prompt": "My business is [describe it] and my best customers come from word of mouth, but it's happening randomly. I want to turn it into a system. Help me design a referral engine: when in the customer journey is someone most likely to refer, what friction is stopping them from doing it, what incentive actually works for my type of customer (hint: it's probably not a discount), and what's the exact script or moment I should create to turn a happy customer into an active advocate?"
        },
        {
          "id": "b13",
          "title": "The Honest SWOT",
          "prompt": "I'm going to do a real SWOT analysis on my business: [describe your business, market, and situation]. But I don't want the polished version — I want the honest, uncomfortable version. For every strength I list, help me identify the hidden weakness underneath it. For every opportunity, help me see the threat hiding inside it. I want to finish this exercise knowing exactly where my business is most vulnerable and most full of potential — not just feel good about where I am."
        },
        {
          "id": "b14",
          "title": "Fire Your Worst Customer",
          "prompt": "I want to identify and stop serving my worst customers — the ones who drain my team, pay the least, complain the most, and refer no one. Here's what my customer base looks like: [describe your customers, the problems you have with some of them, the pricing tiers if any]. Help me: 1) build a profile of my nightmare customer so I can stop attracting them, 2) figure out what in my marketing or positioning is attracting them in the first place, and 3) design an ideal customer profile that helps me only attract the people I actually want to work with."
        },
        {
          "id": "b15",
          "title": "What Would You Do If You Were Starting Over?",
          "prompt": "I've been running my business for [time period]. Here's what I've learned, what's working, and what isn't: [describe your situation honestly]. If you were me, starting this business over from scratch today with everything I know now, what would you do differently? What would you cut immediately? What would you double down on? What mistake am I probably still making right now that I can't see because I'm too close to it? Don't be gentle — I need the honest version."
        }
      ]
    },
    {
      "key": "fitness",
      "name": "Fitness",
      "items": [
        {
          "id": "f1",
          "title": "The Minimum Effective Dose",
          "prompt": "I want to get [specific result — lose fat, build muscle, get stronger, more energy] but I'm being honest: I can realistically commit to [X hours per week]. I don't want an aspirational plan I'll abandon in 2 weeks. Give me the minimum effective dose — the smallest amount of the right work that would actually produce real results for my goal. What's the 20% of effort that produces 80% of the outcome? Build me a plan around my actual life, not an imaginary one."
        },
        {
          "id": "f2",
          "title": "Audit Why You're Not Seeing Results",
          "prompt": "I've been working out for [time period] doing [describe your routine] and eating [describe your diet roughly]. I should be seeing better results by now but I'm not. Don't give me a new plan yet. First, help me diagnose what's actually going wrong. Ask me a series of targeted questions about my sleep, stress, consistency, nutrition timing, training intensity, and recovery — and based on my answers, tell me the real reason I'm stuck. Then tell me the ONE thing that would make the biggest difference if I fixed it first."
        },
        {
          "id": "f3",
          "title": "Design Around Your Actual Schedule",
          "prompt": "Here's my real weekly schedule: [describe your week — work hours, commute, family, energy levels at different times]. I want a fitness plan that fits INTO this life, not one that requires me to change my life to fit it. Based on when I actually have time and energy, design the most effective training split possible. Be realistic about how much time each session actually takes including warmup and shower. I want something I'd genuinely still be doing 6 months from now."
        },
        {
          "id": "f4",
          "title": "What's Actually Sabotaging Your Recovery",
          "prompt": "I train hard but I never feel fully recovered. I'm always a little tired, a little sore, and my performance isn't improving as fast as it should. Here's my lifestyle: [describe sleep, stress levels, diet, alcohol, training frequency, work schedule]. I want a full recovery audit. Tell me the top 3 things I'm doing — or not doing — that are actively undermining my recovery, ranked by impact. Then give me specific, realistic changes I can make starting this week that don't require me to overhaul my entire life."
        },
        {
          "id": "f5",
          "title": "The Body Recomp Masterplan",
          "prompt": "I want to lose fat and build muscle at the same time — body recomposition. I know people say it's hard. My stats: [height, weight, rough body fat estimate, training history, how long you've been training]. Be honest with me about whether recomp is realistic for my situation or whether I should focus on one goal at a time. If it is realistic, give me a precise plan — calorie target, protein target, training approach, and the specific things I need to track to know if it's actually working."
        },
        {
          "id": "f6",
          "title": "Fix Your Posture From Your Actual Life",
          "prompt": "I sit at a desk for [X hours] a day, I [sleep on my side/back], and I have [describe any pain or postural issues — rounded shoulders, forward head, lower back pain, tight hips]. I want to fix my posture and eliminate this discomfort, but I don't have time for a 45-minute corrective routine. Build me the most targeted, high-impact 10-minute daily routine that addresses my specific issues. Explain WHY each exercise helps so I actually understand what I'm fixing."
        },
        {
          "id": "f7",
          "title": "The Travel Workout System",
          "prompt": "I travel for work [X days/month] and my fitness always falls apart when I'm on the road. I can't rely on having a gym. Build me a complete travel fitness system: a no-equipment routine I can do in a hotel room in under 30 minutes that maintains my strength and conditioning, how to handle eating when I'm at airports and client dinners, how to stay on track with sleep and recovery across time zones, and what metrics to track to make sure I'm not losing ground while I'm away."
        },
        {
          "id": "f8",
          "title": "Progressive Overload for Real People",
          "prompt": "I understand the concept of progressive overload but I don't know how to actually apply it to my training. My current program is [describe your workout]. Show me exactly how to progressively overload each of my main exercises over the next 12 weeks — the specific rep, set, and weight progressions I should follow, what to do when I hit a wall, how to know the difference between a bad day and an actual plateau, and how to deload without losing progress."
        },
        {
          "id": "f9",
          "title": "The Sustainable Fat Loss Formula",
          "prompt": "I've lost weight before and gained it all back. I don't want to do that again. My history: [describe your past diets and what happened]. I don't want another aggressive cut. I want the most sustainable, psychologically tolerable fat loss approach that I could actually maintain for 6 months without hating my life. What calorie deficit won't destroy my energy or trigger binging, how much protein do I actually need, and what's the single most important behavior change that separates people who keep it off from people who don't?"
        },
        {
          "id": "f10",
          "title": "The 10-Minute Morning Non-Negotiable",
          "prompt": "I want to build a 10-minute morning movement practice that I will actually do every single day — not just when I feel motivated. I'm not a morning person and I hate feeling like I HAVE to do something intense first thing. Design something that: wakes up my body without destroying me, targets my biggest physical weaknesses [describe them], can be done before coffee if necessary, and has a visible payoff within 30 days that will make me want to keep doing it."
        },
        {
          "id": "f11",
          "title": "Eat More and Weigh Less",
          "prompt": "I'm always hungry when I'm trying to lose fat and it makes me miserable and I give up. I want to eat the maximum amount of food possible while still being in a calorie deficit. Teach me the actual science of food volume and satiety — which foods give the most fullness per calorie, how to structure my meals so I don't feel deprived, and build me a full day of eating that feels generous and satisfying but stays under [your target calories]. I want to feel full for the first time while dieting."
        },
        {
          "id": "f12",
          "title": "Train Around Your Injury",
          "prompt": "I have a [injury/pain — bad knee, shoulder impingement, lower back issues, etc.] and I'm worried that training will make it worse, but I also don't want to stop making progress. Help me understand what I can and can't do safely, what movements I should avoid and what I can substitute, how to train the rest of my body aggressively while protecting the injured area, and what I should be doing to actively rehabilitate the injury so I can eventually get back to full training. I want a plan I could start tomorrow."
        },
        {
          "id": "f13",
          "title": "The Longevity Fitness Protocol",
          "prompt": "I don't just want to look good — I want to be athletic, pain-free, and mobile when I'm 70. I'm currently [age]. Based on the latest research on what actually predicts healthspan and physical function in later life, build me a training protocol that optimizes for longevity. What does the science say about cardio vs. strength vs. mobility for long-term health? What are the most important physical capacities to build now while it's easy? And what are the specific things most people neglect in their 20s, 30s, and 40s that they bitterly regret at 60?"
        },
        {
          "id": "f14",
          "title": "What Elite Athletes Do That You Don't",
          "prompt": "I train consistently and eat reasonably well, but I feel like there's a ceiling I can't break through. Tell me the top 5 things that elite athletes and people in truly exceptional shape do differently from regular gym-goers — not the obvious stuff like 'they work hard,' but the specific habits, mindsets, recovery protocols, and training principles that most people never learn. Then tell me which one of these I could realistically implement first, given what I've told you about my life: [describe your current routine and lifestyle]."
        },
        {
          "id": "f15",
          "title": "Build a Home Gym That Actually Gets Used",
          "prompt": "I want to build a home gym but I've wasted money on equipment before that ended up as expensive furniture. My space is [describe it], my budget is [amount], and my goals are [your fitness goals]. Don't give me a fantasy list. Give me the most strategically prioritized equipment list that will give me the most training options per dollar, ranked by what to buy first. For each item, tell me why it makes the list, what training it unlocks, and what I should skip entirely that's usually a waste of money."
        }
      ]
    },
    {
      "key": "email",
      "name": "Email & Outreach",
      "items": [
        {
          "id": "email-cold-intro",
          "title": "Cold Intro Email",
          "prompt": "Write a concise, personalized cold email introducing myself to [Name] at [Company]. My name is [Your Name], I work at [Your Company], and I want to explore [specific opportunity or collaboration]. Keep it under 120 words, lead with a genuine compliment about their work, and end with a low-friction ask like a 15-minute call."
        },
        {
          "id": "email-follow-up",
          "title": "Follow-Up After No Reply",
          "prompt": "Write a polite, non-pushy follow-up email to [Name] who hasn't responded to my message from [X days ago] about [topic]. Keep it under 60 words. Reference the original message briefly, restate the value clearly, and offer an easy way to decline if they're not interested."
        },
        {
          "id": "email-job-application",
          "title": "Job Application Cover Email",
          "prompt": "Write a professional cover email for a [Job Title] position at [Company Name]. I have [X years] of experience in [field], my top relevant accomplishments are [accomplishment 1] and [accomplishment 2], and I'm excited about this role because [specific reason tied to the company's mission or product]. Keep it to 4 short paragraphs."
        },
        {
          "id": "email-networking-request",
          "title": "Networking Coffee Chat Request",
          "prompt": "Write a warm, respectful email requesting a 20-minute virtual coffee chat with [Name], who works in [role/industry] at [Company]. I found them through [LinkedIn/event/mutual connection]. I want to learn about [specific topic]. Be genuine, not transactional, and make it easy for them to say yes or no."
        },
        {
          "id": "email-proposal",
          "title": "Business Proposal Email",
          "prompt": "Write a compelling email proposing [service or partnership] to [Company Name]. Our solution helps companies like theirs achieve [specific outcome] — recent clients saw [measurable result]. Keep it under 150 words. Include a clear subject line, one-sentence value proposition, three bullet-point benefits, and a specific call to action."
        },
        {
          "id": "email-apology",
          "title": "Professional Apology Email",
          "prompt": "Write a professional apology email to [Name] acknowledging that [describe the mistake or delay]. Take full responsibility without over-explaining. Briefly describe what I'm doing to fix it and prevent recurrence. End with a reassurance of my commitment to the relationship. Keep it sincere and under 100 words."
        },
        {
          "id": "email-salary-negotiation",
          "title": "Salary Negotiation Email",
          "prompt": "Write a confident, professional email negotiating the salary for a [Job Title] offer from [Company]. I received an offer of [amount]. Based on my [X years] of experience, my skills in [specific areas], and market data showing the range for this role is [range], I'd like to request [target amount]. Express genuine enthusiasm for the role throughout."
        },
        {
          "id": "email-client-update",
          "title": "Client Project Update",
          "prompt": "Write a clear client-facing project update email for [Project Name]. This week we completed [accomplishments]. Next we'll be working on [upcoming milestones]. Current status is [on track/slightly delayed] because [brief reason]. Include any decisions we need from the client. Professional, concise, no filler."
        }
      ]
    },
    {
      "key": "career",
      "name": "Career & Resume",
      "items": [
        {
          "id": "career-resume-bullet",
          "title": "Resume Bullet Points",
          "prompt": "Rewrite these job responsibilities as strong resume bullet points using the STAR format (Situation, Task, Action, Result). Start each with a powerful action verb. Add specific metrics where possible. Role: [Job Title]. Company: [Company]. Responsibilities to rewrite: [paste your bullets here]."
        },
        {
          "id": "career-linkedin-bio",
          "title": "LinkedIn About Section",
          "prompt": "Write my LinkedIn About section. I'm a [job title] with [X years] experience in [industry]. My expertise includes [top 3 skills]. I'm most proud of [career highlight]. I'm passionate about [what drives you]. Currently I'm [what you're doing/looking for]. Write it in first person, conversational but professional, 150–200 words. End with a call to connect."
        },
        {
          "id": "career-interview-prep",
          "title": "Interview Answer (STAR Method)",
          "prompt": "Write a strong, concise answer to the interview question: '[Question]'. Use the STAR method (Situation, Task, Action, Result). The role I'm interviewing for is [Job Title] at [Company]. My relevant experience includes [briefly describe]. Keep it under 2 minutes when spoken aloud. Sound confident, not scripted."
        },
        {
          "id": "career-performance-review",
          "title": "Self-Performance Review",
          "prompt": "Help me write my self-assessment for my annual performance review. This year, my key accomplishments were: [list them]. Areas I grew in: [list]. Challenges I faced: [list]. Goals for next year: [list]. Write it in a confident, professional tone that highlights impact without sounding arrogant. About 300 words."
        },
        {
          "id": "career-promotion-ask",
          "title": "Promotion Request Message",
          "prompt": "Write a professional message to my manager [Name] requesting a conversation about a promotion from [Current Role] to [Target Role]. I've been in my current role for [X time]. My key contributions this year include [accomplishments]. Reference how my scope has expanded beyond my current title. Keep it assertive but collaborative, under 150 words."
        },
        {
          "id": "career-reference-request",
          "title": "Reference Request Email",
          "prompt": "Write an email asking [Name], my former [manager/colleague/mentor], to be a professional reference for a [Job Title] role at [Company]. Briefly remind them of the projects we worked on together and the skills that are most relevant. Make it easy for them to say yes. Attach a summary of the role so they're prepared."
        },
        {
          "id": "career-resignation",
          "title": "Resignation Letter",
          "prompt": "Write a professional, gracious resignation letter to my manager [Name]. I'm resigning from [Job Title] at [Company], effective [date, giving X weeks notice]. I want to express genuine gratitude for the opportunities, offer to help with the transition, and leave on excellent terms. Keep it warm, brief, and professional. No burning bridges."
        }
      ]
    },
    {
      "key": "content",
      "name": "Content & Social",
      "items": [
        {
          "id": "c1",
          "title": "Mine Your Life for Content Gold",
          "prompt": "I want to create original content but I keep defaulting to the same generic topics everyone else is covering. Help me mine my own life for content no one else can make. Ask me about: the weirdest thing I know how to do that most people don't, the worst professional mistake I've made and what it actually taught me, the opinion I hold that most people in my field would disagree with, and the thing I wish someone had told me when I was starting out. Then turn each of my answers into 3 specific content angles I could develop."
        },
        {
          "id": "c2",
          "title": "The Contrarian Take That's Actually Right",
          "prompt": "My niche/industry is [describe it]. Everyone in this space keeps saying [common belief or piece of advice that dominates the conversation]. I disagree — or at least I think it's more complicated than that. Help me develop this into a strong, defensible contrarian take that will make people stop scrolling. I don't want to be contrarian for the sake of it — I want a real argument. Help me: sharpen my actual position, find the evidence that supports it, anticipate the strongest objections, and frame it in a way that's provocative but not just inflammatory."
        },
        {
          "id": "c3",
          "title": "Turn Your Failure Into Your Best Content",
          "prompt": "Here's something that went wrong for me recently — a failure, a mistake, a plan that didn't work out: [describe it]. I've been avoiding talking about this publicly because it's embarrassing or uncomfortable. Help me turn it into content. Find the universal lesson inside my specific story, help me frame it in a way that's vulnerable but not self-pitying, identifies what other people in my audience will recognize in their own lives, and ends with a genuine insight rather than a forced silver lining."
        },
        {
          "id": "c4",
          "title": "The 1 Idea, 30 Pieces Framework",
          "prompt": "I have one core idea or belief that's at the center of everything I create: [describe your big idea]. Help me extract 30 different pieces of content from this single idea. I want: 10 short-form takes (tweets, captions), 5 long-form angles (essays, videos), 5 story-based executions, 5 data or evidence angles, and 5 contrarian or provocative framings. Each one should feel fresh and different even though they all come from the same source. Show me how one idea can sustain an entire content strategy."
        },
        {
          "id": "c5",
          "title": "Write the Hook That Makes Them Stop",
          "prompt": "My content is genuinely valuable but people aren't clicking or stopping to read it. Here's a piece I made that underperformed: [describe or paste your content]. Help me understand why the hook failed — what signal was it sending to someone scrolling past in 0.3 seconds? Now write me 10 different opening hooks for this same piece using different techniques: curiosity gap, counterintuitive claim, specific result, personal story opener, pattern interrupt, direct challenge, and bold prediction. Explain why each one would work."
        },
        {
          "id": "c6",
          "title": "Build Your Point of View",
          "prompt": "I create content in [niche/topic area] and I feel like I don't have a strong enough point of view — I'm just reporting information instead of actually saying something. Help me develop a genuine POV. Ask me: what makes me angry about my industry, what do I think most people are getting wrong, what have I changed my mind about, and what do I believe that I couldn't prove but feel deeply. Then help me synthesize these answers into a 3-sentence statement of my actual perspective that could be the foundation of everything I create."
        },
        {
          "id": "content-linkedin-post",
          "title": "LinkedIn Story Post",
          "prompt": "Write a LinkedIn post that shares a lesson I learned from [experience or challenge]. Start with a one-line hook that stops the scroll. Share the story briefly (3–4 sentences), then the specific lesson, then a takeaway for others in [industry or profession]. Use short paragraphs, no hashtag spam. End with an engaging question to spark comments."
        },
        {
          "id": "content-twitter-thread",
          "title": "Twitter/X Thread",
          "prompt": "Write a 7-tweet thread about [topic]. Tweet 1: a bold, attention-grabbing claim or question. Tweets 2–6: one specific, actionable insight each, explained clearly. Tweet 7: a summary and call to follow for more. Each tweet under 260 characters. No filler. Use numbers and concrete examples."
        },
        {
          "id": "content-newsletter",
          "title": "Email Newsletter Section",
          "prompt": "Write one section of a weekly email newsletter for [audience type] about [topic]. The tone is [conversational/professional/witty]. Include a short anecdote or insight (3–4 sentences), one actionable tip, and a recommendation (tool, article, or resource) with a one-line explanation of why it's worth their time."
        }
      ]
    },
    {
      "key": "creative",
      "name": "Creative Writing",
      "items": [
        {
          "id": "creative-short-story",
          "title": "Short Story Opening",
          "prompt": "Write the opening 200 words of a short story with the following setup: genre is [genre], main character is [brief description], the setting is [place and time], and the central tension or mystery that will drive the story is [conflict]. Start in the middle of action or a striking sensory detail. No preamble. Make me want to keep reading."
        },
        {
          "id": "creative-poem",
          "title": "Modern Poem",
          "prompt": "Write a contemporary free-verse poem about [theme or subject]. The emotional tone should be [melancholic/joyful/tense/nostalgic]. Use concrete, specific imagery — avoid clichés. Length: 12–18 lines. Aim for a memorable final image or line that reframes everything before it. Do not rhyme unless it happens naturally."
        },
        {
          "id": "creative-wedding-speech",
          "title": "Wedding Speech",
          "prompt": "Write a heartfelt, funny, and memorable wedding speech for [your role: best man/maid of honor/parent]. The couple is [Name 1] and [Name 2]. Key stories or memories to include: [list 2–3]. A running theme or inside joke: [optional]. Length: 3–4 minutes when spoken. Open with a laugh, build to a genuine emotional moment, end with the toast."
        },
        {
          "id": "creative-toast",
          "title": "Toast or Tribute",
          "prompt": "Write a 60-second toast honoring [Name] for [occasion: retirement/birthday/award/promotion]. This person is known for [2–3 qualities]. A specific moment that captures who they are: [anecdote]. Include genuine warmth, one light-hearted moment, and a memorable closing line for the toast. Suitable to say in front of [professional/family/close friends] audience."
        },
        {
          "id": "creative-personal-statement",
          "title": "Personal Statement",
          "prompt": "Write a compelling personal statement for [college/graduate school/scholarship/fellowship] application. I am applying for [program] at [institution]. My background: [key experiences]. My defining moment or turning point: [story]. Why this specific program: [specific reasons tied to the curriculum, faculty, or mission]. My goal: [what I want to do with this]. 500 words, first person, authentic voice."
        },
        {
          "id": "creative-bio",
          "title": "Third-Person Speaker Bio",
          "prompt": "Write a polished third-person bio for [Name] to be used for [conference/podcast/website]. They are a [title] who [core expertise in one sentence]. Notable achievements: [list 2–3]. They've been featured in or worked with [brands/publications/organizations]. Currently: [what they're working on]. Personal note: [hobby or interest that humanizes them]. Length: 100 words for short version, 200 words for long."
        }
      ]
    },
    {
      "key": "productivity",
      "name": "Productivity & Planning",
      "items": [
        {
          "id": "productivity-weekly-review",
          "title": "Weekly Review Template",
          "prompt": "Help me do a structured weekly review. Ask me the following (one at a time or all at once): What were my biggest wins this week? What didn't get done, and why? What drained my energy? What gave me energy? What's the one thing I need to prioritize next week? Then summarize my answers into a clear 'start/stop/continue' and a top-3 priority list for next week."
        },
        {
          "id": "productivity-project-brief",
          "title": "Project Brief",
          "prompt": "Write a one-page project brief for [Project Name]. Sections to include: Background (why this project exists), Goal (what success looks like in measurable terms), Scope (what's in and out of scope), Key Deliverables with owners and due dates, Dependencies and risks, Stakeholders and decision-makers, and Budget/Resources required. Keep each section to 2–4 sentences."
        },
        {
          "id": "productivity-daily-plan",
          "title": "Daily Prioritization Plan",
          "prompt": "Help me plan my day. I have these tasks: [paste your task list]. My working hours are [start]–[end]. My must-do appointment or meeting is at [time]. I work best on deep work in the [morning/afternoon]. Group similar tasks, protect 2 hours for my most important project, batch emails/messages into one slot, and leave a 30-minute buffer. Give me a time-blocked schedule."
        },
        {
          "id": "productivity-sop",
          "title": "Standard Operating Procedure",
          "prompt": "Write a clear Standard Operating Procedure (SOP) for [process name] at [company type]. The process goal: [what it accomplishes]. Audience: [who will use it]. Format: numbered steps, clear action verbs, decision points highlighted in bold. Include: purpose, scope, prerequisites, step-by-step instructions, common mistakes to avoid, and revision date. Keep technical jargon minimal."
        },
        {
          "id": "productivity-retrospective",
          "title": "Team Retrospective",
          "prompt": "Facilitate a sprint/project retrospective for [team name] on [project or sprint name]. Duration: [X] weeks. Use the 4Ls framework: Liked (what went well), Learned (new insights), Lacked (what was missing), Longed For (what we wished we had). For each section, write 3–4 starter prompts to get the team talking. End with a template for capturing 3 action items with owners."
        },
        {
          "id": "productivity-decision-framework",
          "title": "Decision Framework",
          "prompt": "Help me make a structured decision about [decision I'm facing]. I need to choose between: [Option A], [Option B], [Option C if applicable]. The most important factors to me are: [list 3–5 criteria]. Constraints: [time, budget, risk tolerance]. Create a weighted decision matrix, score each option against my criteria, and give a recommendation with a 2-sentence rationale. Then tell me the top risk of the recommended option."
        },
        {
          "id": "productivity-habit-plan",
          "title": "Habit Building Plan",
          "prompt": "Create a realistic 30-day plan to build the habit of [habit]. My current behavior: [what I do now]. My goal: [what I want to do consistently]. My biggest obstacle: [what gets in the way]. Use implementation intention format ('I will [behavior] at [time] in [location]'). Include a weekly check-in structure, a way to track streaks, and what to do when I miss a day."
        }
      ]
    }
  ]
}
$json$::jsonb AS payload
)
INSERT INTO trending_prompts (category, title, prompt)
SELECT 
  cat->>'name' as category,
  item->>'title' as title,
  item->>'prompt' as prompt
FROM 
  json_data,
  jsonb_array_elements(payload->'categories') as cat,
  jsonb_array_elements(cat->'items') as item;
