# AgentVille Sol Session Handoff

## 2026-07-12 — Session 1 baseline

- Hour-zero hygiene shipped in `d3ca710` with `AGENTS.md`, all three Sol session briefs, 52 Godot `.uid` sidecars, and `godot/tools/run_all_smokes.sh`.
- Godot 4.6.3 headless project sanity check passed.
- `godot/tools/run_all_smokes.sh` passed all 98 pre-session smoke scripts with zero failures.
- No earlier handoff file or deferred blocker existed. Session 1 can proceed directly into the live Workbench compiler mission.

## 2026-07-12 — Session 1 complete

- Shipped the live local Agent Workbench in `ba4bd75` (`Activate Agent Workbench compiler`) and its validation/capture packet in `8b5b616` (`Harden Workbench run receipts`). The branch has not been pushed; `AGENTS.md` requires confirmation before push.
- `SkillScriptParser` now hand-tokenizes/parses the bounded agent language into allowlisted Skill Specs with line/column teaching errors. Unknown tools and conditions reach `SkillSpecValidator`, and unsupported conditions hard-block.
- `COMPILE` and Cmd/Ctrl+Enter share one pipeline: parser → validator → runtime guard → named-agent crew order → post-world-state check. The trace renders player text as plain text and always reports the resolved `(x,y)` target and current lifecycle status.
- SELECT now persists `selected_tile` with an independent teal voxel frame. Template fallback targeting is used only when no tile is selected; crew-order targeting does not overwrite Workbench selection.
- `SkillCheckEvaluator` snapshots the tile plus inventory before dispatch and verifies `tile_state`, `crop_state`, or `inventory_delta` only after the correlated successful crew action. Failed attempts requeue; cancel, replacement, and two day advances fail with `order never completed`; stale events from replaced runs are ignored.
- Runtime conditions `always`, `inspect.has_brush`, `crop.needs_tending`, `crop.ready`, and `tile.empty` run before draft and again on agent arrival. Pre-Send target drift and arrival-time drift both close with a blocked receipt instead of leaving a pending run.
- Ready-corn demonstration at selected tile `(1,6)`: the canonical Marigold program drafted a Harvest order, stayed pending until execution, then passed with `Expected at least +1 grain, observed +1 grain.` The same source at empty tile `(0,0)` drafted no work and reported `Guard crop.ready blocked ... expected a ready crop, observed an empty tile.`
- Canonical source used for both demonstrations:

  ```text
  agent "Marigold" {
    observe selected_tile
    when crop.ready {
      use harvest_crop(selected_tile)
    }
    verify inventory_delta
    receipt "Harvest Crops run"
  }
  ```

- Added required smokes `smoke_skill_script_parser.gd`, `smoke_workbench_compile.gd`, `smoke_skill_check_evaluator.gd`, and `smoke_selected_tile_target.gd`, plus `smoke_workbench_ui_controls.gd` and `smoke_persistent_tile_selection.gd`. The final Godot 4.6.3 sanity check passed and `godot/tools/run_all_smokes.sh` passed `104/104` with zero failures.
- Visual review passed at 1600×900: `godot/artifacts/screenshots/agentville-workbench-compile.png` shows selected ready corn, the source, `ORDER DRAFTED`, and `PENDING · WORLD CHECK` from the actual Compile-button path.
- Half-done: nothing within Session 1. A few scene smokes still print their existing non-failing ObjectDB shutdown warning; no smoke or sanity failure remains.
- Exact next step: execute `docs/sol-sessions/SESSION-2.md` from a clean branch state, beginning with `SkillLessonLibrary.gd` and `smoke_skill_lessons.gd`; preserve the Session 1 parser, selection, guard, and honest receipt contracts while layering the curriculum.

## 2026-07-13 — Session 2 complete

- Shipped the ten-lesson curriculum and local progress/program shelf in `9063361` (`Build AgentVille lesson curriculum`), then its acceptance packet in `4286eaf` (`Harden lesson mastery persistence`). The adjacent viewport-navigation request shipped separately in `ac393e1` (`Harden camera viewport navigation`).
- `SkillLessonLibrary` now orders ten mastery-gated lessons across run/read, modify, debug, and author tiers. A lesson completes only from the player's own terminal Workbench run when the real agent, action, target, guard, verification, receipt, and required failure evidence match its condition; legacy Skill Forge runs cannot grant mastery.
- `SkillTutorLibrary` now layers authored farmhand-mentor copy above technical trace detail for parser classes, every validator code, drift, guards, order lifecycle, and world checks. Lesson failures escalate deterministically from concept nudge to targeted hint to a fix diff; a retrying crew attempt does not incorrectly spend another hint.
- The `AGENT` tab now shows `NOW`, `LOCK`, and `DONE` lesson states plus the named program shelf. The Workbench shows the current goal, successful lessons add a Field Log completion receipt, and exact parser/validator-valid compiled source can be saved and loaded without execution.
- `PlayerProgress` persists completed/current lessons, exact named program source, and Grid/Shadows/AO settings at `user://agentville_progress.json`. Missing, malformed, non-dictionary, invalid-shaped, and inconsistent mastery state recover safely; boot normalization keeps only the contiguous mastered prefix, selects the first incomplete lesson, and preserves unrelated programs/view settings.
- Cold-start walkthrough used the isolated `user://agentville_session2_walkthrough.json` path. Each run pressed the production CREW ORDERS `Send` button: Chuck, Chuck, then Bert accepted the exact correlated directive, advanced through the `AgentActor` movement/work loop, cleared brush through the real world action, emitted matching queued-order and `agent_world_action` events, returned idle, and passed the terminal verifier. The three runs completed at `(0,1)`, `(0,2)`, and `(0,5)` in 22, 13, and 14 fixed simulation steps and produced the receipts `Lesson complete: 01 · Run the brush starter`, `Lesson complete: 02 · Name the proof`, and `Lesson complete: 03 · Reassign the farmhand`.
- Lesson 1 program:

  ```text
  agent "Chuck" {
    observe selected_tile
    when inspect.has_brush {
      use clear_brush(selected_tile)
    }
    verify tile_state
    receipt "Clear Patch run"
  }
  ```

- Lesson 2 program:

  ```text
  agent "Chuck" {
    observe selected_tile
    when inspect.has_brush {
      use clear_brush(selected_tile)
    }
    verify tile_state
    receipt "Brush Proof run"
  }
  ```

- Lesson 3 program:

  ```text
  agent "Bert" {
    observe selected_tile
    when inspect.has_brush {
      use clear_brush(selected_tile)
    }
    verify tile_state
    receipt "Brush Proof run"
  }
  ```

- A second Godot process restored exactly lessons 1–3 as `DONE`, lesson 4 as `NOW`, lesson 5 as `LOCK`, the exact `Session 2 Brush Proof` Bert source, and `{grid: true, shadows: false, ambient_occlusion: false}` in progress, UI, and world state; it then removed only the isolated walkthrough file.
- Camera navigation remains fixed-isometric and selection-safe: wheel or `WORLD` buttons zoom from `4.4` to `15.0`; right/middle drag, `FARM` → `View` left-drag, or WASD/arrows pan within X `±6.0` and Z `±5.5`; `Center` restores target zero and size `7.6`. View drag now starts correctly over tiles, text fields block keyboard pan, and releasing over a panel cannot leave the camera latched.
- Added required smokes `smoke_skill_lessons.gd`, `smoke_lesson_completion.gd`, `smoke_player_progress.gd`, and `smoke_tutor_copy.gd`. After replacing the acceptance shortcut with the production Send/NPC path, both cold-start walkthrough processes and the Godot 4.6.3 project sanity check passed; `godot/tools/run_all_smokes.sh` passed `108/108` with zero failures.
- Visual review passed at 1600×900. `godot/artifacts/screenshots/agentville-skill-lessons.png` simultaneously shows the ladder/current goal plus `TUTOR`, `TECHNICAL`, and `stage ORDER DRAFTED`; `godot/artifacts/screenshots/agentville-camera-navigation.png` shows corner `(10,0)` shifted clear of the fixed panels with the `WORLD` camera controls visible. Camera corner clearance and ray selection also pass at 1280×720.
- Half-done: nothing within Session 2 or the camera-navigation slice. A few older scene smokes can still print their existing non-failing ObjectDB shutdown warning when run directly; there are no sanity, smoke, walkthrough, capture, persistence, or diff failures.
- Exact next step: execute `docs/sol-sessions/SESSION-3.md`, beginning with the windowed `tools/qa_cold_start.gd` harness and its fresh-progress lesson/run/save-reload screenshot sequence. Preserve the Session 2 mastery, tutor, exact-source persistence, and viewport-navigation contracts while fixing each cold-start failure it exposes.

## 2026-07-13 — Session 3 complete

- Cold-start find → fix: a fresh disk-backed boot did not reliably hold the player on Lesson 1. Onboarding now opens `AGENT`, loads the exact starter and tutor hint, silently preselects real brush, keeps `CREW` available for Send, and locks FARM mutation, free-play Forge, and End Day until the first verified run. A later QA pass caught that the automatic selection used the player-action path and triggered false NPC commentary; `select_tile_without_action()` now makes boot guidance evidence-neutral.
- Diagnostics find → fix: parser errors did not consistently name the offending token, validator fields had no source provenance, and runtime guard/order/retry/lifecycle/check failures lacked source locations. `SkillScriptParser` now emits token-bearing errors plus a source map, and every live error trace renders line/column, token, cause, and one repair suggestion. The malformed-program battery covers 36 parser cases; the integrated Workbench smoke covers runtime failures.
- Feel find → fix: validator Drift stopped at data copy and compile/run/proof/mastery feedback felt interchangeable. Drift now survives the harness and work-order bridge into bounded AgentActor face/tint/badge cues. A warning-only runtime block no longer rewrites `wobbly/sweating/crew_noticing` into an impossible mixed state. Compile, actual dispatch, passed receipt, and lesson completion have distinct pulses and SoundManager stamps, with onboarding proving the production wiring.
- Balance find → fix: curriculum progress persists while farm resources do not, leaving graduates without an affordable first loop. Bert's two-step `Graduate Field Loop` starts with exactly `2 Fiber + 1 Grain`; the smoke delivers the Fence Kit without changing money, advances to and completes the real brush demand through AgentActor work, receives the mission reward, and drafts another Forge run afterward. Demand, mission, End Day, Parley, and Forge identities remain stable while interleaved.
- Layout find → fix: the 1280×720 UI smoke found the Workbench overlapping the command dock by about 20 pixels. Its responsive left anchor moved from `0.21` to `0.23`; camera and UI smokes now pass at both 1280×720 and 1600×900. Existing wheel/button zoom, WASD/arrows, mouse/View-tool pan, and Center controls still shift every farm corner clear of the fixed panels and Workbench without breaking tile selection.
- Windowed evidence is final: `qa_cold_start.gd` passed the required second fresh-progress path through Lesson 1 → real Send/NPC completion → free-play Forge → End Day → teardown/reload and regenerated six clean 1600×900 frames. `capture_session3_portfolio.gd` regenerated and visually passed the mid-lesson, failed-trace, passed-receipt, and farm shots. `capture_skill_forge_drift_visuals.gd` visibly proves Bert's safely blocked hallucinating reaction; `capture_camera_navigation.gd` was refreshed against the final layout.
- Validation is green on Godot 4.6.3: focused onboarding/parser/Workbench/feedback/Drift/balance/UI/camera smokes passed, `godot/tools/run_all_smokes.sh` passed `113/113`, the second windowed cold-start QA exited `0`, and the final project sanity check exited `0`. A few existing direct smokes still print non-failing ObjectDB shutdown warnings.
- New Session 3 tools are `smoke_onboarding.gd`, `smoke_parse_error_battery.gd`, `smoke_skill_forge_drift_visuals.gd`, `smoke_workbench_feedback.gd`, `smoke_post_ladder_goal_loop.gd`, `qa_cold_start.gd`, `capture_session3_portfolio.gd`, and `capture_skill_forge_drift_visuals.gd`. Root/Godot README, Skill Forge PRD, AGENTS authority note, and `SHIPLOG.md` now tell the same live-product truth.
- Half-done: nothing within Session 3. The bounded-language, local-only assets, placeholder-audio, non-persisted farm-world, and no-export-build limits are recorded in `SHIPLOG.md`; pushing this checkpoint still requires owner confirmation.
- Exact next step: run an owner-led 20–30 minute playtest from a genuinely unfamiliar save, record only confusion that the scripted QA cannot perceive, then choose one bounded polish slice. For the camera immediately: wheel or `WORLD → Zoom + / Zoom -` zooms, WASD/arrows or right/middle drag pans, `FARM → View` enables left-drag, and `WORLD → Center` recenters.

## 2026-07-14 — Session 4 complete

- Shipped the first reactive Skill Script in `0358234` (`Add day-start skill triggers`) and its focused acceptance packet in `d12c9d0` (`Harden day-start trigger lifecycle`). The branch has not been pushed; pushing still requires owner confirmation.
- An optional `on day_start` statement now compiles to the allowlisted `day_start` trigger. Omitting `on` remains the exact manual Compile → guard → draft → Send → AgentActor → world-check route, and the generic harness rejects declared/fired trigger mismatches without creating a directive.
- Compile validates a day-start program and captures the current selected tile, named farmhand, source, and source map in one deterministic in-memory arm. It performs no guard check, drafts no order, assigns no actor, and mutates no farm or inventory state. Moving selection cannot retarget the arm; loading a lesson or saved program never arms source.
- The Workbench shows `ARMED ONCE · DAY START`, its captured target, and a compact `DISARM` control. Editing source while armed says `EDITED · TRIGGER STILL ARMED`; replacement, explicit disarm, fired, blocked, skipped, failed, and passed states leave correlated technical trace, Field Log, and `GameEventLog` evidence.
- End Day remains authoritative: it builds the prior-day summary, grows/advances the world, records `day_advanced`, applies existing demand/order aging and pending-run timeout behavior, then consumes the arm. A free runtime checks the new-day guard and auto-dispatches the existing named crew-order route without Send. A busy Forge runtime is never cancelled or replaced; the one-shot records a source-linked skip and is consumed.
- Arrival guards and post-action world checks remain unchanged. A real automatic action failure is terminal for that activation and removes its order instead of falling into the manual retry state. Automatic runs carry `origin = workbench_trigger`, an empty `lesson_id`, and cannot complete any of the ten manual lessons.
- New tools are `smoke_skill_trigger_scheduler.gd`, `smoke_workbench_trigger_controls.gd`, `smoke_day_start_trigger.gd`, and `capture_day_start_trigger.gd`. The integration smoke covers real Main/UI/End Day/AgentActor pass, immutable target, one-shot dedupe, DISARM, busy skip, fire-time guard block, and real failed-action cleanup.
- Validation is green on Godot 4.6.3: the final project sanity check exited `0`; `godot/tools/run_all_smokes.sh` passed `116/116` with zero failures; the windowed capture exited `0` after Chuck completed in 22 fixed steps and wrote a 1600×900 `agentville-day-start-trigger.png`. Visual review confirmed Day 2, authored `on day_start`, `PASSED · DAY START`, Chuck, and captured tile `(0,1)` in one frame.
- Half-done: nothing within the bounded one-shot trigger slice. Arms intentionally do not persist or repeat, no other event is accepted, and no Lesson 11 or separate Automation panel was added. Existing generated `.uid` and screenshot `.import` sidecars remain untracked and untouched.
- Exact next step: run a short owner playtest that alternates one manual program with one armed day-start program, edits the source after arming, moves selection, and deliberately creates one busy-runtime skip. The remaining uncertainty is human comprehension of “captured once, fires once”; only after that read should the next bounded slice be either clearer armed-target visualization or one additional event such as `crop_ready`.

## 2026-07-15 — Session 5A checkpoint truth complete

- Published baseline is reconciled: before this slice, local `HEAD` and `origin/agentville-v4-godot-fresh` both resolved to `7f7ddd5`. Session 4 was pushed after owner approval, so the earlier “not pushed” statements above remain historical snapshots rather than current remote truth.
- Committed the product-identity correction in `d1fe16e` (`Clarify AgentVille product identity`) and its focused evidence packet in `dc3d0bc` (`Harden checkpoint truth`). The complete Session 5A packet and publication handoff were pushed to `origin/agentville-v4-godot-fresh` after owner approval; local, tracking, and server refs matched after publication.
- The runtime window now reads `AgentVille — Learn-to-Code Voxel Farm`, while `application/config/name` intentionally remains `AgentVille Voxel Farm Prototype`. Godot derives the default `user://` namespace from that internal name, and the existing progress file lives there; changing it would have made returning progress appear lost.
- The title card promise is now `Build agents. Prove their work.` and is contained at both 1600×900 and 1280×720. The Compile tooltip says `Compile Skill Script · Cmd/Ctrl+Enter`, the live day reads `DAY N · MORNING`, and the static Command Dock `READY` chip plus meaningless hardcoded 38% Field Desk bar are gone. The Workbench's `READY · LOCAL COMPILER` label remains because it reports real compiler state.
- Root `CLAUDE.md` now opens with a prominent warning that its React/Three.js architecture is retired legacy material. `godot/README.md` records the current identity contract and correctly assigns captured target/selection-move evidence to `smoke_day_start_trigger.gd`, not the UI-only trigger-controls smoke.
- Added `smoke_product_identity.gd` and `capture_product_identity.gd`. The smoke boots real Main with isolated unlocked progress, protects the internal save namespace, checks the visible window/title/subtitle/tooltip and both placeholder removals, proves responsive title containment, and exercises the production End Day transition from `DAY 1 · MORNING` to `DAY 2 · MORNING`.
- Validation is green on Godot 4.6.3: the focused identity, UI-overhaul, Workbench-controls, day-start-trigger, and onboarding smokes each exited `0`; `godot/tools/run_all_smokes.sh` passed `117/117`; the project sanity check exited `0`; both updated windowed harnesses passed `--check-only`; and `git diff --check` passed. The new windowed capture exited `0`, wrote a complete 1600×900 `agentville-product-identity.png`, and visual review confirmed contained copy, the live Workbench, `DAY 2 · MORNING`, and no fake status decoration.
- Half-done: product truth is now explicit, but independent learning transfer is still unmeasured. Generated Godot `.uid` and screenshot `.import` files remain intentionally untracked, and no gameplay behavior changed in this slice.
- Exact next step: run a 2–3 person unfamiliar-player checkpoint from fresh saves. Observe Lessons 1–4 without coaching, then test a blank recombination using only already-taught vocabulary. Treat “make it happen tomorrow morning” first as a discoverability probe; for comprehension, supply only `on day_start`, ask the player to predict Compile, edit source and move selection after arming, End Day, then explain which captured program/tile ran and why it fired once. Use a stage-0 or stage-1 crop so day growth does not contaminate the trigger mental-model result.

## 2026-07-16 — AgentVille QC protocol complete

- The published product baseline was verified before this slice: local `HEAD` and `origin/agentville-v4-godot-fresh` both resolved to `33160831ed9b03c9941c292b006e33623b332968`. The documentation feature is committed locally in `664efd8` (`Define AgentVille QC protocol`) and has not been pushed.
- Added the paste-ready Breadstick/Sol 5.6 implementation brief `docs/sol-sessions/AGENTVILLE-QC-DASHBOARD-SOL-5.6-SPEC.md`. It specifies a standalone `/agentville-qc` application, namespaced Express API, built-in Node SQLite, immutable protocol/build campaigns, anonymous participant sessions, atomic observations, structured errors/evidence, linked findings/tasks, and deterministic materialized Markdown/JSON checkpoints with agent-safe redaction.
- Added the human protocol `docs/sol-sessions/PLAYTEST-1.md` and its machine seed `docs/sol-sessions/agentville-qc-playtest-1.json`. The seed is self-contained: build freeze, launch, save safety, campaign order, prerequisite handling, facilitator rules, answer concealment, and all assignment/step instructions are baked into version `agentville-playtest-1@1.0.0`.
- Playtest 1 contains five ordered assignments and 27 steps: cold-start manual lifecycle; Lessons 2–4 plus blank transfer; captured-once `day_start` mental model; optional busy-pipeline/camera recovery; and the required final resume-selection truth probe. Required time is 40–52 minutes per participant; including optional Run 4 is 48–62 minutes.
- The protocol treats the current resumed-save selection concern as a code-derived hypothesis, not a confirmed defect. A returning unlocked save may expose TILL without an obvious side-effect-free Select route; the final assignment measures that route strictly and stops on mutation.
- Cross-file validation passed: JSON parsed; assignment/step IDs were unique and sequential; dependency edges pointed backward; campaign order matched all five assignments; every one of the 27 machine step codes appeared exactly once in the human protocol; required/full duration maxima matched 52/62 minutes; operator setup, answer visibility, canonical capture fields, and route contracts passed; `git diff --cached --check` passed.
- Godot 4.6.3 project sanity exited `0`. The first sandboxed smoke attempt failed `0/117` before test logic because Godot could not write `user://logs` and crashed in `RotatedFileLogger`; rerunning with normal user-log access passed `117/117` with zero smoke failures. No game code changed.
- Existing generated Godot `.uid` and screenshot `.import` files remain untracked and untouched. The separate Breadstick repository was inspected read-only and already contained unrelated dirty Reactive Visual Lab work plus AppleDouble sidecars; the Sol brief requires live re-verification and narrowly scoped staging there.
- Half-done: the Breadstick QC dashboard is specified but not implemented, and no human participant evidence exists yet. No finding should be promoted from the protocol hypotheses before the frozen cohort runs.
- Exact next step: open a fresh Sol 5.6 session rooted at `/Volumes/beefybackup/breadstick-codex`, paste `docs/sol-sessions/AGENTVILLE-QC-DASHBOARD-SOL-5.6-SPEC.md`, and implement its bounded local-first vertical slice while preserving the dirty Breadstick worktree. After dashboard acceptance, run `P01` through `P03` on one frozen AgentVille campaign without changing the build between participants.

## 2026-07-16 — Godot Web export readiness complete

- The live Godot product is now browser-exportable without involving the retired root React/Vite prototype. `godot/export_presets.cfg` defines an unthreaded Web preset with a Web-only Compatibility renderer; desktop play remains Forward+.
- `godot/tools/export_web.sh` respects `$GODOT`, recreates `godot/build/web`, verifies the required HTML/JavaScript/WASM/PCK outputs, rejects any stored local MEGAVOX asset, and copies an artifact-local `vercel.json`. The generated build is ignored by Git.
- Licensed local MEGAVOX previews, tools, docs, and captured artifacts are excluded from the browser package. Missing MEGAVOX content continues to use the existing procedural-cube fallback.
- Compatibility rendering now skips unsupported camera depth of field. A headed-browser failure also exposed stale black regions after wheel zoom; zoom now invokes the full camera transform refresh used by pan, and the exact browser interaction subsequently rendered cleanly.
- Official Godot 4.6.3 unthreaded Web templates were installed locally. The final release export passed and produced a 42 MB artifact under `godot/build/web`.
- Validation is green: project sanity exited `0`; focused Web-export and camera-navigation smokes exited `0`; `godot/tools/run_all_smokes.sh` passed `118/118`; headed Chromium at 1600×900 passed clean boot, keyboard pan, wheel zoom, and a production Compile click with no console/page errors.
- Browser-local persistence is proven on localhost: changing Grid created the existing `agentville_progress.json` schema in IndexedDB-backed `user://`; a reload recovered byte-for-byte equivalent JSON with `grid: true`. Private browsing and restricted iframe contexts remain platform caveats.
- New shipping surfaces are `godot/tools/export_web.sh`, `godot/export_presets.cfg`, `godot/web/vercel.json`, `godot/docs/web_export.md`, and `godot/tools/smoke_web_export_config.gd`.
- Half-done: no external Vercel project has been linked or deployed, and no Git-triggered build environment installs Godot/templates yet. Those are intentionally separate from browser-runtime readiness.
- Exact next step: identify the intended existing Vercel project, deploy the already-generated `godot/build/web` directory as a preview, and validate the HTTPS URL. Only then choose whether production should publish reviewed artifacts or add a reproducible Godot-equipped CI build.

## 2026-07-16 — Godot Web production release gate

- Preserved the former React/Vite production source exactly at remote branch `legacy/react-v3@a93455a820340bacefa27a663b77d8e49dfdfb6b` before changing `main`.
- Published `agentville-v4-godot-fresh@7d440c4e1b51db1339e3669d69c3637992c78526`. Its root Vercel contract skips npm/Vite and serves the reviewed, hash-manifested artifact under `godot/deploy/vercel`.
- Vercel completed a feature-branch Preview deployment for that exact SHA. Anonymous requests redirect to Vercel SSO because Deployment Protection is enabled, so preview acceptance combines the provider's successful deployment status with the already-passed local browser run against byte-identical tracked files.
- Fast-forwarded `main` from archived legacy commit `a93455a` to reviewed Godot commit `7d440c4`. Vercel did not create a Production deployment for the reused preview SHA, and the production alias still served the legacy bundle at the time of this record.
- Validation remains green: all four artifact hashes pass, the focused publish smoke and project sanity exit `0`, and `godot/tools/run_all_smokes.sh` passes `118/118`. A real browser window passed boot, pan, zoom, and Compile with no user-visible redraw gap.
- Exact next step: publish this release-record commit to both the feature branch and `main` to give the Git integration a unique production SHA; then require a successful Production deployment plus browser validation at `https://agent-ville-kappa.vercel.app` before declaring the replacement live.
