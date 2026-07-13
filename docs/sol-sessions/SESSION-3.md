# Session 3 — Make it a solid creation

## Mission
Ship quality. By session end AgentVille is something a stranger can open cold, learn from for thirty minutes without confusion, and leave having written working agent programs — with the repo's docs telling the truth about what it is.

## Context
This session is deliberately a wide sweep, ordered by player impact — cut from the bottom, never the top.

## Deliverables (in order)
1. **Cold-start QA sweep:** build `tools/qa_cold_start.gd` — a scripted SceneTree harness that drives the real boot path from a fresh `user://` (wipe progress file first): lesson 1 through lesson completion, a free-play forge run on a selected tile, day advance, save/reload — asserting no crashes, no stuck states, and correct tutor copy at each step, and capturing a screenshot per step (windowed run). Fix every failure it exposes; if the owner supplies manual playtest notes, fold those fixes in too. Log each find→fix pair in the handoff.
2. **First-five-minutes onboarding:** on first boot, land the player in lesson 1 with the Workbench open and one unmissable goal; the farm sandbox unlocks after the first successful run. Returning players resume where they left off.
3. **Compiler-trace excellence:** every error a player can trigger shows line/col, the offending token, a plain-language cause, and one suggestion. Audit by feeding the parser a battery of malformed programs; smoke the battery.
4. **Feel:** surface run drift visually — consume the validator's drift `face_hint`/`observer_hint` (currently produced but never rendered) on the executing agent via the existing `_update_expression_visuals()` pathway in `AgentActor.gd`, so a drifting/hallucinating run reads on the farmhand's face while it executes. Receipts and lesson completions get the pulse/tween/sound treatment consistent with existing `_pulse()` and SoundManager patterns; compile and run get distinct sounds.
5. **Balance pass:** money/resource costs vs lesson pacing so free play after the ladder has a goal loop (demands, missions, parley all still fire and interleave sanely with forge runs).
6. **Truth-telling docs:** rewrite root `README.md` for what AgentVille now is (Godot game, learn-to-code, how to run it; move the web-app description to a legacy section); amend `skill_forge_prd.md` non-goals to match the shipped reality (Skill Script v1 grammar documented); update `godot/README.md` system map and tool registry.
7. **Capture set:** windowed `capture_*.gd` runs producing a fresh screenshot suite of the Workbench mid-lesson, a failed-run trace, a passed receipt, and the farm — the game's portfolio shots.

## Acceptance
- `run_all_smokes.sh` fully green, including new `smoke_parse_error_battery.gd` and any smokes added during QA fixes.
- `qa_cold_start.gd` completes its full scripted path with zero assertion failures on the second pass.
- A dated `docs/sol-sessions/SHIPLOG.md` summarizing all three sessions: what the game now does, every system added, every smoke added, known limitations, and a short "next horizons" list (candidates: non-manual triggers, multi-tile targets, program sharing, the LLM-observer seam).

## Out of scope
New mechanics, new lesson tiers, export templates/distribution builds — note them in SHIPLOG next-horizons instead.
