# AgentVille Sessions 1–4 Ship Log

## 2026-07-13 — What Shipped

AgentVille is now a Godot 4 learn-to-code game built on a cozy voxel farm. A player selects one farm tile, writes or modifies a bounded Skill Script v1 program in the Agent Workbench, compiles it into a data-only allowlisted Skill Spec, sends the resulting crew order, watches Bert, Marigold, or Chuck perform the work, and receives a pass/fail receipt checked against the resulting tile, crop, or inventory state. The ten-lesson ladder teaches that loop through real parser, validator, guard, dispatch, and world-check evidence; progress and exact named program source persist locally.

The surrounding farm remains part of the lesson rather than a backdrop. Crew demands, missions, Parley, day changes, resources, and utility-driven NPC work continue alongside Forge runs. A new player is initially held to the Lesson 1 path, while a returning graduate receives a small existing-system mission loop for continued free play.

## Session 1 — Make The Loop Real

Shipped in `ba4bd75` (`Activate Agent Workbench compiler`) and `8b5b616` (`Harden Workbench run receipts`), after the `d3ca710` hygiene/baseline checkpoint.

### Systems Added

- `scripts/systems/SkillScriptParser.gd`: hand-written tokenizer and parser for the bounded Workbench language; compiles authored source into safe Skill Spec data without `eval`.
- `scripts/systems/SkillCheckEvaluator.gd`: before/after tile, crop, and inventory snapshots; execution-time guards; plain-language observed-versus-expected verdicts.
- Live Workbench pipeline in `Game.gd` and `GameUI.gd`: Compile/Cmd-or-Ctrl+Enter → parser → validator → guard → named-agent crew order → correlated world check → terminal receipt.
- Persistent selected-tile targeting in `PlacementTool.gd` and `Tile.gd`, including an independent visible selection frame and template fallback only when no tile is selected.
- Honest Forge lifecycle correlation across `SkillForgeRunHarness`, work orders, `AgentActor`, and the event log: pending, retry, cancellation, replacement, two-day timeout, arrival-time guard recheck, and stale-event rejection.
- `tools/run_all_smokes.sh`: a single Godot 4.6 smoke runner with an aggregate pass/fail result.

### Smokes Added

- `smoke_skill_script_parser.gd`
- `smoke_skill_check_evaluator.gd`
- `smoke_workbench_compile.gd`
- `smoke_selected_tile_target.gd`
- `smoke_workbench_ui_controls.gd`
- `smoke_persistent_tile_selection.gd`

Session 1 closed with `104/104` smokes green, a Godot sanity pass, and the real `capture_workbench_compile.gd` artifact showing a selected crop and pending compiler trace.

## Session 2 — Make It Teach

Shipped in `9063361` (`Build AgentVille lesson curriculum`) and `4286eaf` (`Harden lesson mastery persistence`), with production Send/NPC evidence hardened in `b4323df` and documented in `d806f17`.

### Systems Added

- `scripts/systems/SkillLessonLibrary.gd`: ten ordered mastery-gated lessons across run/read, modify, debug, and author tiers, each with evidence-backed completion requirements.
- `scripts/systems/SkillTutorLibrary.gd`: deterministic farmhand-mentor copy for parser, validator, Drift, guard, order-lifecycle, and world-check states; failures escalate from concept nudge to targeted hint to a fix diff.
- `scripts/systems/PlayerProgress.gd`: local JSON persistence for completed/current lessons, exact named program source, and Grid/Shadows/AO settings, with safe missing/corrupt/inconsistent-state recovery.
- Lesson and Program Shelf UI in `GameUI.gd`: `NOW`/`LOCK`/`DONE` ladder states, current goal, tutor-over-technical trace, exact-source save/load, and Field Log mastery receipts.
- Mastery integration in `Game.gd`: only a player's terminal Workbench run with the required agent, action, target, guard, check, receipt, and failure evidence can complete a lesson; legacy Forge runs cannot grant mastery.
- Production cold-start walkthrough tooling in `walkthrough_skill_lessons.gd`: lessons 1–3 execute through the real CREW ORDERS Send button and named `AgentActor` work path, then restore exact progress/source/settings in a second process.
- Expanded fixed-isometric navigation in `CameraController.gd`, `GameUI.gd`, and `PlacementTool.gd`: wheel/button zoom, WASD/arrow and mouse/View-tool pan, recentering, editor-focus isolation, and farm-corner clearance from the fixed HUD.

### Smokes Added

- `smoke_skill_lessons.gd`
- `smoke_lesson_completion.gd`
- `smoke_player_progress.gd`
- `smoke_tutor_copy.gd`
- `smoke_camera_navigation.gd`

Session 2 closed with `108/108` smokes green, both cold-start walkthrough processes green, a Godot sanity pass, and the 1600×900 lesson capture. The adjacent camera-navigation hardening in `ac393e1` also made wheel/button zoom, mouse/View/WASD pan, recentering, text-focus isolation, and panel clearance part of the validated play surface.

## Session 3 — Make It A Solid Creation

Session 3 adds ship-quality behavior through the existing runtime rather than introducing a parallel game mode.

### Systems Added Or Extended

- Cold-start QA harness: `tools/qa_cold_start.gd` drives an isolated fresh boot, Lesson 1 compile/Send/NPC completion, a free-play Forge run, End Day, teardown/reload, exact tutor/progress assertions, and six windowed 1600×900 step captures.
- First-five-minutes onboarding: fresh progress opens AGENT and Lesson 1 with starter source, tutor trace, an obvious goal, and a selected brush target; FARM mutation, free-play Forge, and End Day remain locked until the first verified run. Returning players resume the saved current lesson and its exact authored starter; exact named programs remain separately reloadable from the shelf.
- Compiler-trace diagnostics: parser errors include line, column, offending token, cause, and fix; parser source provenance gives validator and runtime guard/order/retry/lifecycle/world-check failures the same authored-source contract.
- Forge Drift presentation: run directives preserve allowlisted `face_hint` and `observer_hint` data through the harness and work-order bridge; `AgentActor` renders bounded face, tint, badge, and snapshot cues during execution, with a timed reaction for safely blocked hallucinating runs. Runtime completion preserves the original warning cues unless all Drift hints are explicitly overridden together.
- Workbench feel: compile, actual crew dispatch, passed world-check receipt, and lesson completion use distinct SoundManager stamps and visible pulse/tween targets, proven through the production onboarding route.
- Post-ladder balance loop: a returning graduate receives the exact `2 Fiber + 1 Grain` stake needed for Bert's two-step `Graduate Field Loop`; the resource-only Fence Kit leaves money unchanged, real AgentActor brush work completes the mission, and a new Forge order remains draftable afterward while End Day and Parley interleave.
- Truth and capture tooling: the root README, Skill Forge PRD, AGENTS authority note, and Godot system/tool map describe the live Godot product and Skill Script v1 boundaries; `capture_session3_portfolio.gd` defines fresh mid-lesson, failed-trace, passed-receipt, and farm portfolio views, while `capture_skill_forge_drift_visuals.gd` proves the blocked hallucinating state on the farm.

### Smokes Added

- `smoke_onboarding.gd`
- `smoke_parse_error_battery.gd`
- `smoke_skill_forge_drift_visuals.gd`
- `smoke_workbench_feedback.gd`
- `smoke_post_ladder_goal_loop.gd`

### Release Gate At This Entry

Session 3 passed its release gate on Godot 4.6.3: `godot/tools/run_all_smokes.sh` completed `113/113`, the required second windowed `qa_cold_start.gd` pass exited `0`, the project sanity check exited `0`, and the regenerated cold-start, portfolio, camera, and Drift captures passed visual review at 1600×900. `HANDOFF.md` records the find→fix evidence and exact continuation point.

## 2026-07-14 — Session 4: Wake An Agent On Day Start

Session 4 adds AgentVille's first reactive Skill Script without opening an unbounded automation system. A player can add `on day_start`, select one farm tile, and Compile to arm a single in-memory activation. Compile captures the target and source evidence but performs no guard check, drafts no work order, and mutates no farm state. The next End Day grows and advances the world first, then consumes the arm and auto-dispatches valid named-agent work through the existing crew path without Send.

### Systems Added Or Extended

- `scripts/systems/SkillTriggerScheduler.gd`: one deterministic in-memory arm with immutable Compile-time request/source snapshots, local counter IDs, explicit replacement/disarm results, and exactly-once later-day consumption.
- Skill Script grammar and validation: optional `on day_start` compiles to the allowlisted `day_start` trigger; omitting `on` preserves the manual route, while every other event is rejected with source-linked teaching guidance.
- Trigger-aware run harness: matching manual and day-start runs can start through one bounded entry point; trigger mismatches block without drafting a directive, and the existing manual wrapper remains compatible.
- Workbench lifecycle: the armed-once state, captured tile, explicit Disarm control, fired/blocked/skipped/replaced/disarmed trace, and Field Log evidence stay visible without adding a new lesson or automation panel.
- End-day integration: the world update remains first. A free runtime checks the authored guard and auto-dispatches through the real work-order/`AgentActor`/world-check route; a busy Forge runtime is never replaced and consumes the arm with one honest skipped receipt. Automatic action failure terminates instead of leaving a stuck order.

### Coverage Added

- `smoke_skill_trigger_scheduler.gd`
- `smoke_workbench_trigger_controls.gd`
- `smoke_day_start_trigger.gd`
- `capture_day_start_trigger.gd` at 1600×900

## Known Limitations

- Skill Script v1 is intentionally bounded to one named crew member, one selected tile, one farm action, one optional guard, one verification check, and one receipt. Its only routes are implicit manual dispatch and one optional, session-local, one-shot `on day_start` activation.
- Variables, arithmetic, comments, user-defined functions, loops, nested control flow, multi-agent planning, multi-tile programs, and general expression evaluation are not accepted by v1.
- Player programs cannot evaluate arbitrary code or reach file writes, network calls, or the game loop outside the validator/harness allowlist.
- Lesson/program/view progress persists locally, but the farm world itself is rebuilt at boot; the graduate stake compensates for that boundary rather than pretending resources persisted.
- Day-start arms do not persist, repeat, or survive source loading. Re-arming requires an explicit Compile, and passing an automatic activation does not complete the ten manual lessons.
- The tutor, NPC decisions, Drift cues, and observer-like summaries are deterministic. No LLM, LSTM, HTTP request, or live model participates in execution.
- Final sound assets are optional `.ogg` files; generated placeholder tones preserve distinct feedback when those files are absent.
- Licensed MEGAVOX GLBs are local-only and optional. Missing files silently use procedural cube fallbacks, so visual review must note which asset path was available.
- This four-session package does not include export templates, distribution builds, cloud saves, multiplayer, or a skill marketplace.

## Next Horizons

- **Next bounded triggers:** evaluate one explicit crop-ready, mission, or inventory event at a time, with the same deterministic scheduling, target capture, and receipt-correlation standard as `day_start`.
- **Repeating automation:** only consider opt-in repeat schedules after one-shot arming, cancellation, busy-runtime behavior, and player visibility have held up in real playtests.
- **Multi-tile targets:** teach iteration and decomposition across a small explicit tile set before considering long-running autonomy.
- **Program sharing:** export/import safe Skill Script text and metadata, then consider a moderated library once local authorship is solid.
- **LLM-observer seam:** let an optional observer enrich recaps or coaching from `GameEventLog` evidence while keeping compilation, validation, decisions, and world mutation entirely local and deterministic.
