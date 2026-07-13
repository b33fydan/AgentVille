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
