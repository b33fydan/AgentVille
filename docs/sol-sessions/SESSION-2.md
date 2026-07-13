# Session 2 — Make it teach

## Mission
Turn the working compiler into a curriculum. By session end a brand-new player is guided from "click Run on a starter" to "write a skill from scratch," the tutor speaks through the compiler trace, and progress survives restarting the game.

## Context
Teaching content today is five one-line `lesson` strings in `SkillForgeTemplateLibrary.gd` and the scripted Check/Fix demo; there is no lesson ordering, no gating, and **no persistence of any kind in the project** (zero `user://` writes).

## Design decisions (made — don't reopen)
- Tutor copy is authored, keyed off real pipeline states (parse error class, validator code, drift level, check verdict). Voice: a farmhand mentor — at most two short sentences per line, no exclamation points, no generic praise; each line names the specific mistake and gives one concrete next step. The existing `AgentDialogueLibrary` trait/quip pattern is the model to follow.
- Curriculum teaches **both** real coding concepts (sequencing, conditionals, verification/debugging, decomposition) **and** agent-shaped concepts (trigger, context, tool allowlists, receipts) — each lesson names the concept it just taught in plain language.
- Progression is mastery-gated, not time-gated: a lesson completes when the player's own compiled run satisfies the lesson's check.

## Deliverables (in order)
1. **Lesson ladder** (`scripts/systems/SkillLessonLibrary.gd`, RefCounted + data): ~8–12 lessons in tiers — (a) run and read: execute a starter, read the receipt; (b) modify: change one field/step of a starter to hit a new goal (e.g. retarget, swap tool, change the check); (c) debug: fix a deliberately broken program (build on the Check/Fix drift loop); (d) author: write a program from a blank editor to satisfy a stated farm goal. Each lesson: id, title, concept taught, goal copy, starting editor text, completion condition evaluated from real run results, tutor copy for success/failure/first-hint.
2. **Tutor in the trace:** tutor lines layered above the technical detail (both visible). Hint escalation: first failure = concept nudge, second = targeted hint, third = show the fix diff. Wire "TUTOR RUNTIME OFFLINE" copy out of existence if any remains.
3. **Lesson UI:** current lesson goal visible beside the Workbench; lesson list with locked/unlocked/completed states in the AGENT tab; completing a lesson advances and celebrates via the existing receipt/field-log style.
4. **Persistence** (`scripts/systems/PlayerProgress.gd`): JSON at `user://agentville_progress.json` — completed lessons, current lesson, saved player programs (named), and the three view toggles (grid, shadows, AO). Load on boot, save on change. Corrupt/missing file → fresh start, never a crash.
5. **Program shelf:** players can name and save their compiled programs and reload them into the editor — their first "library of skills they wrote."

## Acceptance
- New smokes: `smoke_skill_lessons.gd` (ladder integrity: ids unique, gating order, every completion condition evaluable), `smoke_lesson_completion.gd` (scene-integration: a compiled run completes lesson 1 and unlocks lesson 2), `smoke_player_progress.gd` (save→reload roundtrip, corrupt-file recovery), `smoke_tutor_copy.gd` (every pipeline state has tutor copy; hint escalation sequence). `run_all_smokes.sh` fully green.
- Cold-start walkthrough recorded in the handoff: fresh `user://`, complete lessons 1–3 end-to-end (paste the programs used), restart the game, verify progress persisted.

## Out of scope this session
Visual/audio polish, onboarding cinematics, difficulty tuning, new crops/structures.
