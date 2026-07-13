# Session 1 — Make the loop real

## Mission
Turn the Agent Workbench from a stub into a working compiler, and make Skill Forge verification true. By session end a player can type a skill program, compile it, watch a farmhand execute it on a tile they selected, and receive an honest pass/fail receipt checked against actual world state.

## Ground truth (verified 2026-07-12 — trust these over doc claims)
- The Workbench (`GameUI.gd` `_build_code_workbench`, ~line 1279) is a visual stub: its only wired behavior is `_on_workbench_text_changed` flipping a status label; the COMPILER TRACE panel is hardcoded bbcode fiction; there is no Run control and no parser anywhere in the repo (zero `Expression`/tokenizer usage).
- The pre-filled CodeEdit text (`GameUI.gd:1335`) is the canonical surface syntax — statements are **newline-separated, no semicolons** (accept a trailing semicolon as optional, never require it):
  ```
  agent "Marigold" {
    observe selected_tile
    when crop.ready {
      use harvest_crop(selected_tile)
    }
    verify inventory_delta
    receipt "Harvest Crops run"
  }
  ```
  Keywords `agent/observe/when/use/verify/receipt` are already registered in the CodeHighlighter. Field mapping: `observe`→`context.target`, `when`→`steps[].when`, `use`→`steps[].tool/target`, `verify`→`success_check`, `receipt`→`receipt`; `agent "Name"` → the run request's agent identity, resolved against Bert/Marigold/Chuck (unknown name = parse-stage error).
- **The surface syntax expresses only part of Skill Spec v0.** The validator hard-errors on fields the grammar has no form for: `id` (snake_case), `name`, `trigger.type == "manual"`, `failure_handling.on_blocked` + `suggestion`, `success_check.target`, and for `inventory_delta` both `item` and `min_delta`. The parser must synthesize these deterministically: id/name from the agent header + receipt label; trigger `{type: "manual"}`; failure_handling generated from the guard; `success_check.target = context.target`; inventory_delta defaults from the matching starter template. Do not extend the grammar or relax the validator this session.
- Pass/fail is fake: `Game.gd` ~line 349 calls `complete_run(start_result, true, …)` — hardcoded `passed=true`, recorded **before** the crew executes. `success_check` is carried in the directive but never evaluated by anyone.
- The harness collapses specs to one action: `_primary_action` scans steps in reverse and ignores `when` guards; per-step execution doesn't exist.
- `selected_tile` is not real: the SELECT tool (`PlacementTool.gd` ~197) only emits a toast and stores nothing; forge targets come from `_skill_forge_target_for_template` (`Game.gd` ~438) — open demand tiles, else hardcoded per-template fallbacks.
- The forge→crew bridge IS real: `_maybe_draft_skill_forge_work_order` (`Game.gd` ~577) inserts genuine work orders the crew executes. Build on it, don't replace it.
- `smoke_ui_overhaul.gd` `_assert_editor_contract` (~lines 330–370) pins the offline-stub copy verbatim ("TUTOR RUNTIME OFFLINE", "Game state is disconnected"). Updating those assertions to the new live-workbench contract is expected and in scope — keep its input-isolation assertions (WASD blocked while editor focused, no click-through) intact.
- Validator warning copy "preview-only until the run harness exists" (`SkillSpecValidator.gd` ~198) is stale — update it when conditions become real.
- Baseline: all 98 existing smokes pass headless (~2 minutes total).

## Deliverables (in order)
1. **Hour-zero hygiene:** commit the 52 untracked `.uid` sidecars, plus `AGENTS.md` and `docs/sol-sessions/` (they belong in the repo); add `godot/tools/run_all_smokes.sh` (runs every `smoke_*.gd` headless, prints a pass/fail table, exits nonzero on any failure); run it and record the baseline in the handoff.
2. **`SkillScriptParser.gd`** (`scripts/systems/`, RefCounted): hand-rolled tokenizer + recursive-descent parser for the workbench grammar → Skill Spec v0 dictionary. Parse errors return `{line, col, message, suggestion}`. Unknown tools/conditions parse fine and flow to the validator, which already rejects them with teaching copy.
3. **Wire the Workbench:** Run/Compile button (and Cmd+Enter). Flow: editor text → parser → on parse error, render in the trace panel; on success → `SkillSpecValidator` → render errors/warnings/drift in the trace → if runnable, `start_manual_run` and dispatch as today. The trace panel always shows the real pipeline output — delete the hardcoded fiction.
4. **Real tile selection:** SELECT tool stores a persistent selected tile with a visible highlight frame; `selected_tile` in a program resolves to it; forge runs fall back to the current targeting only when nothing is selected; compiler trace names the resolved tile coordinates.
5. **Honest verification:** a `SkillCheckEvaluator` (RefCounted) that evaluates `success_check` (`tile_state`/`crop_state`/`inventory_delta`) against world state after the drafted work order completes; `complete_run` is called with the evaluator's verdict, not `true`. Snapshot inventory/tile state at run start so `inventory_delta` is a real delta. Run lifecycle: evaluate on the first completion event for the drafted order (hook `_update_work_order_from_agent_action`, `Game.gd` ~2885, correlate via a `forge_run_id` on the order); note failed crew attempts re-queue the order (`status` back to "ready"), so a cancelled order — or one still open after two day-advances — yields a failed receipt naming "order never completed"; one pending workbench run at a time, and compiling again while pending cancels and replaces it. Failed checks produce a receipt with the observed-vs-expected difference in plain words.
6. **`when` guards honored:** evaluate step conditions (`crop.ready`, `crop.needs_tending`, `tile.empty`, `inspect.has_brush`, `always`) at execution time; a guard that blocks produces a "blocked" receipt explaining which condition failed on which tile.

## Acceptance
- New smokes: `smoke_skill_script_parser.gd` (valid programs, each error class with line numbers), `smoke_workbench_compile.gd` (scene-integration: set editor text, trigger compile, assert trace + dispatched run), `smoke_skill_check_evaluator.gd` (each check type passing AND failing), `smoke_selected_tile_target.gd`.
- `run_all_smokes.sh` fully green, including all pre-existing skill_forge and work-order smokes.
- The pre-filled sample program, compiled against a selected ready-corn tile, yields a **passed** receipt; the same program on an empty tile yields a **blocked/failed** receipt that names the reason. Demonstrate both in the handoff notes.

## Out of scope this session
Curriculum/lessons, save/load, tutor personality copy, visual polish, new farm content. If Deliverable 6 threatens the session budget, ship 1–5 and log 6 as the first item in the handoff.
