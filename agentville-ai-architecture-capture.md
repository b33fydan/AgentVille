# AgentVille — AI Architecture Capture

**Date:** April 30, 2026 **Status:** Parked until Breadstick \+ Skool Community ships **Context:** Live-build candidate for the community once active priorities clear **Source:** Conversation thread that started with an LSTM tangent and landed on a real architectural decision

---

## The Core Insight: Observer-Agent Pattern

Most "AI NPC" projects fail economically because they wire every NPC to a live LLM, firing API calls constantly. That's a money pit cosplaying as innovation.

**The flip:** Use *one* intelligent observer at the end of meaningful time windows, not many intelligent actors during play. The agents behave deterministically all day. At day-end, a single LLM call reads a structured summary and delivers a verdict in character.

Player walks away with a sharp, contextual roast that *feels* like the agents were watching the whole time. They weren't. The LLM read the receipts.

Why this works psychologically: players don't experience continuous intelligence — they experience *moments* of it. A great end-of-day roast lingers for days. Twenty mediocre live reactions during play lingers for zero. We're concentrating the AI budget where it makes memories.

---

## The Architecture (Four Layers)

1. **Behavior Trees** — moment-to-moment NPC actions (plant, water, harvest, sulk, leave). No ML. Battle-tested for 25+ years of game dev. Designer-readable, debuggable, deterministic.  
     
2. **LSTM (or simpler classifier) — Performance Scoring** — reads player action sequences and outputs a continuous "vibe score." Runs locally, no API calls. For a farming sim, running averages \+ thresholds may get us 80% there; LSTM earns its keep when patterns are subtle (e.g., detecting a pre-ragequit rhythm before the player rage-quits).  
     
3. **Pre-Generated Dialogue Library** — use Claude *once at build time* to generate \~5,000 lines per character, tagged by severity, topic, and mood. A weighted-lookup picker selects context-appropriate lines based on LSTM score \+ recent events. Tiny, fast, free at runtime.  
     
4. **Live LLM — The Observer** — fires only at meaningful moments: end-of-day roast, end-of-week review, season recap, first-quit, milestone reactions. Maybe 2–3 API calls per player per session. This is where personality and intelligence land hardest.

---

## Cost Model (The Real Unlock)

- Per-agent live API calls at scale: 1000 players × 10 agents × calls every few minutes \= bankruptcy.  
- Observer-agent pattern: \~3 API calls per player per session, \~$0.005 each \= \~$0.015 per player per session.  
- Pre-gen library \= one-time generation cost upfront, near-zero runtime.

This is the difference between a real game business and a venture-funded demo.

---

## The Structured Summary Is The Actual Product

The end-of-day prompt looks like this:

You are Bert, a 58-year-old farmhand who's seen it all

and is tired of watching this player squander good soil.

Today's farm summary:

\- 4 crops planted, 2 harvested on time, 1 left to rot

\- Cow \#3 not fed for 6 in-game hours

\- Player logged off mid-irrigation (third time this week)

\- Net profit: \-$340

\- Bert's mood after today: disgusted (4/10)

Deliver a 2-3 sentence end-of-day roast in Bert's voice.

Reference at least one specific failure. Be funny, not cruel.

The depth of the burn is bottlenecked by how observant the logging layer is. "Player abandoned watering at 4:32pm" is decent. "Player started watering, got distracted opening the seed shop, never came back" is gold.

**Build the logging layer with the roast in mind from day one.** The signals are the moat.

---

## Memory & Compounding

Cache the daily summaries. Now:

- End-of-week roast references the week.  
- End-of-season roast references the season.  
- Bert remembers you let the tomatoes rot three Tuesdays in a row.

Same architecture, longer summary fed in. Memory becomes a feature, not an infrastructure problem.

---

## Multiple Perspectives, Same Day

Same structured summary, three prompts, three personalities:

- **Bert** — disgusted, 4/10  
- **Marigold** — disappointed but hopeful  
- **Chuck** — thinks the chaos is hilarious, rooting for it

Player feels witnessed by a crew, not narrated by a single voice. Negligible cost increase, big perceived-aliveness payoff.

---

## Portable Pattern

The observer-agent pattern works for anything where dumb-but-believable actors run a system and you want intelligent narration / verdict on top:

- AI coach reviewing a workout session  
- AI manager reviewing a sales day  
- AI tutor reviewing a study session  
- AI DM reviewing a play session  
- AI farmhand crew reviewing a farm day (← us)

Worth keeping in the back pocket for non-game applications too.

---

## The Pushback (Don't Forget)

**The architecture is plumbing. The voice is the moat.** What will make AgentVille good is not the elegance of this stack — it is the dialogue craft, personality differentiation, and timing of the burns. Same lesson as Breadstick: niche selection and persona credibility are the moat, not the pipeline.

Someone has to write 50,000 words of grumpy AI farmhand monologue with actual bite. Budget for that work — or budget for the prompts that generate it well — at the same priority as the engineering.

---

## Open Questions for Build Time

- LSTM vs. simpler statistical scoring — which is genuinely needed? Start with thresholds, upgrade only if patterns demand it.  
- How granular should the action-logging schema be? (Pre-design this — it's the limiter on roast quality.)  
- Character roster size at launch — 3 sharply differentiated, or 8 blurry ones? (3.)  
- Pre-gen library refresh cadence — quarterly drops to keep dialogue fresh? Tied to community releases?  
- Live-build implications: which parts of this are interesting to *show* the community vs. boring backend? The dialogue generation runs and observer prompt iteration are the watchable parts.

---

## When To Pick This Back Up

- Breadstick funnel proving out with Hank ✅  
- Skool community shipped and onboarding paying members ✅  
- 16-gami strategic role decided ✅  
- SkyframePOV LUT business proven (or shelved) ✅

**Then** start AgentVille live-build. Not before.  
