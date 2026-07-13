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
