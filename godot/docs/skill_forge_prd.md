# Skill Forge PRD

Status: implemented and playable
Scope: shipped Agent Workbench, Skill Forge, curriculum, and sandbox contract
Codebase: AgentVille Godot 4.6

## Product Summary

Skill Forge is the deterministic agent-runtime layer behind AgentVille's learn-to-code game. Players type bounded Skill Script v1 programs into the Agent Workbench, compile them into data-only Skill Specs, and watch named NPC farmhands execute the resulting crew work. A starter-template panel exposes the same contracts without requiring source authoring.

The Workbench is a real code editor and teaching compiler for the shipped language. It is deliberately not a general-purpose IDE or arbitrary-script host: the language exposes only the farm context, tools, guards, and checks documented below. Every run remains inspectable from authored source through validation, order execution, observed world state, and receipt.

## Player Promise

The player should feel:

- "I can teach an agent a small farm skill."
- "I understand what the agent is allowed to do."
- "I can see why the agent chose each step."
- "I can tell whether the run passed, failed, or needs revision."
- "The farm, NPCs, and receipts remember enough context to make the run feel grounded."

## Why This Fits Now

The current foundation already has most of the ingredients for an agent-skill harness:

- Missions act like small learning objectives.
- Work orders act like tool calls.
- Field Log lines act like run receipts.
- Day summaries act like compact run recaps.
- Vibe and NPC verdicts act like local observers.
- Smoke scripts act like pass/fail validation.
- Mission Momentum now carries source, origin, queue, active, success, failure, and recap context through the game.

Skill Forge should reuse those systems instead of introducing a parallel simulation.

## Design Pillars

### 1. Bounded Source, Structured Runtime

Players author small programs, but the compiler emits only schema-validated Skill Spec dictionaries. The runtime executes known farm tools and deterministic checks; source text is never evaluated as GDScript or shell code.

### 2. Visible Runs

Every run should leave a readable trail: why it started, what context it used, what tool calls happened, what succeeded, what failed, and what the next revision might change.

### 3. Cozy Competence

The Forge should feel like learning by tending a farm, not debugging a compiler. Errors should be specific, friendly, and actionable.

### 4. Local First

The runtime is deterministic and local. The playable Forge loop has no live API dependency.

### 5. Existing Systems Win

If a Forge concept can map to missions, work orders, Field Log receipts, day summaries, NPC comments, or smoke-style validation, it should use those paths first.

## Shipped Authoring Surfaces

The primary product surface is the bottom-center Agent Workbench. The player selects a farm tile and writes or modifies a Skill Script v1 program. Without an `on` statement, `COMPILE` preserves the manual route and the player sends the drafted crew order. With `on day_start`, Compile validates and arms one in-memory activation against the selected tile; the next End Day advances the world, consumes the arm, and auto-dispatches valid work without Send. Parse and validation failures stop safely with teaching diagnostics. A valid run stays pending until its named NPC performs the action and the post-action world check passes or fails.

The `AGENT` command tab also contains five starter templates—Tend Crops, Plant Seed, Clear Patch, Harvest Crops, and Build Fence—with readable contract previews and a bounded Check/Fix revision loop. Both surfaces route through the same validator, run harness, work-order system, Field Log, and day-summary receipts.

## Skill Script v1 Grammar

Skill Script v1 is hand-tokenized and parsed by `scripts/systems/SkillScriptParser.gd`. This EBNF describes the accepted source shape; whitespace between tokens is optional, while statements must be separated by a newline or semicolon unless a closing brace ends the statement.

```ebnf
program       = separators, "agent", string, "{", separators,
                statement, { separators, statement }, separators,
                "}", separators ;
statement     = trigger | observe | use | guarded_use | verify | receipt ;
trigger       = "on", identifier ;
observe       = "observe", identifier ;
use           = "use", identifier, "(", identifier, ")" ;
guarded_use   = "when", identifier, "{", separators,
                use, separators, "}" ;
verify        = "verify", identifier ;
receipt       = "receipt", string ;
separators    = { newline | ";" } ;
identifier    = ( letter | "_" ), { letter | digit | "_" | "." } ;
string        = '"', { string_character | escape }, '"' ;
escape        = BACKSLASH, ( '"' | BACKSLASH ) ;
BACKSLASH     = Unicode U+005C ;
string_character = any character except '"', BACKSLASH, CR, or LF ;
letter        = "A" ... "Z" | "a" ... "z" ;
digit         = "0" ... "9" ;
```

Each program must contain exactly one `observe`, one `use`, one `verify`, and one `receipt`. A program may also contain zero or one `on` statement. Omitting `on` compiles to the existing `manual` trigger; the only authored event accepted by the validator is `on day_start`. The single `use` may appear directly, which implies the `always` guard, or inside one `when` block. Statement order is not otherwise significant. Keywords are lowercase and case-sensitive. Crew names are quoted and resolve case-insensitively to `Bert`, `Marigold`, or `Chuck`. Strings stay on one line and only escaped quotes (`\"`) and backslashes (`\\`) are supported. Comments, variables, arithmetic, user-defined functions, loops, and nested control flow are not part of v1.

### Shipped vocabulary

| Role | Accepted v1 values |
| --- | --- |
| Crew | `Bert`, `Marigold`, `Chuck` |
| Trigger | implicit `manual`, authored `day_start` |
| Context and call target | `selected_tile` |
| Farm action tools | `clear_brush`, `harvest_crop`, `plant_seed`, `tend_crop`, `build_fence` |
| Guards | `always`, `inspect.has_brush`, `crop.needs_tending`, `crop.ready`, `tile.empty` |
| Success checks | `tile_state`, `crop_state`, `inventory_delta` |

`inspect_tile` is an internal allowlisted template step, not a standalone player action that drafts farm work. The shipped action/check contracts with complete verifier metadata are:

| Action | Canonical guard | Canonical check | Observed proof |
| --- | --- | --- | --- |
| `clear_brush` | `inspect.has_brush` | `tile_state` | Target decor becomes empty. |
| `harvest_crop` | `crop.ready` | `inventory_delta` | Grain increases by at least one. |
| `plant_seed` | `tile.empty` | `crop_state` | A new crop exists on the target. |
| `tend_crop` | `crop.needs_tending` | `crop_state` | The same crop's growth stage increases. |
| `build_fence` | `tile.empty` | `tile_state` | Target decor becomes `fence`; a Fence Kit may be required. |

Identifiers outside these semantic allowlists can tokenize and parse so the validator can explain the problem; they cannot run. Parser failures return a one-based line and column, offending token, plain-language cause, and one fix suggestion. Validator failures are tied back to the authored field through the parser source map.

### Canonical example

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

This source compiles to a manual, selected-tile Skill Spec for Marigold. It does not pass merely because compilation succeeds: the guard must pass, the crew order must complete, and the inventory delta must be observed after the correlated NPC action.

A one-shot reactive program adds one statement:

```text
agent "Marigold" {
  on day_start
  observe selected_tile
  when tile.empty {
    use plant_seed(selected_tile)
  }
  verify crop_state
  receipt "Morning Plant run"
}
```

Compile validates this source and captures the selected tile, but performs no guard check, creates no work order, and mutates no world state. After the next End Day advances and grows the farm, the runtime consumes the arm, checks the guard against that new-day state, and auto-dispatches valid work through the same named-NPC route without Send.

## Compiled Skill Spec v1

The parser and template panel normalize authored intent into a dictionary-shaped, serializable data contract. The example below shows the fuller Clear Patch template form; Workbench programs emit the same required top-level contract with one authored action step.

```gdscript
{
	"id": "clear_pressure_patch",
	"name": "Clear Pressure Patch",
	"trigger": {
		"type": "manual"
	},
	"context": {
		"target": "selected_tile",
		"include_recent_source": true,
		"allowed_sources": ["completed_mission", "ignored_ask", "truce", "remembered_help"]
	},
	"tools": ["inspect_tile", "clear_brush"],
	"steps": [
		{
			"id": "inspect",
			"tool": "inspect_tile",
			"target": "context.target"
		},
		{
			"id": "clear",
			"tool": "clear_brush",
			"target": "context.target",
			"when": "inspect.has_brush"
		}
	],
	"success_check": {
		"type": "tile_state",
		"target": "context.target",
		"decor_id": ""
	},
	"failure_handling": {
		"on_blocked": "record_receipt",
		"suggestion": "Pick a brush tile or revise the condition."
	},
	"receipt": {
		"label": "Pressure patch cleared",
		"include_source_context": true
	}
}
```

## Field Definitions

### id

Stable internal identifier. Lowercase snake case. Used in smoke validation and saved runs.

### name

Player-facing label. Should be short enough to fit in compact UI rows.

### trigger

Skill Script v1 accepts `{ "type": "manual" }` and `{ "type": "day_start" }`. `manual` is implicit when source has no `on` statement. `day_start` is an explicit, session-local, one-shot arm: Compile captures the current `selected_tile`; End Day advances the world first and then consumes the arm whether it passes, blocks, or skips because another Forge run is pending. Arms never persist, repeat, or restore merely because saved source is loaded. Mission Momentum, inventory-threshold, crop-ready, and every other trigger remain unsupported.

### context

Defines what the skill can see. Context should be explicit. A skill should not silently read the whole world.

### tools

An allowlist of tool actions. A skill can only call tools listed here.

### steps

Ordered, deterministic execution plan. A Workbench program emits one action step; starter templates can also include a preceding internal `inspect_tile` step.

### success_check

The pass/fail condition for the run. This should be concrete enough to render as a visible validation chip.

### failure_handling

What the run does when blocked, invalid, or incomplete. This is a first-class part of the skill, not an afterthought.

### receipt

What gets written to the Field Log and day summary.

## Existing System Mapping

| Forge concept | Shipped AgentVille system | Current route |
| --- | --- | --- |
| Skill source | `SkillScriptParser` | Hand-written parser emits a data-only Skill Spec and source map. |
| Skill spec | `SkillSpecValidator` | Schema and allowlists hard-block unsupported behavior. |
| Trigger | Compile/Run player action plus `SkillTriggerScheduler` | Manual source drafts on Compile; `on day_start` holds one immutable in-memory arm until a later day begins. |
| Context | Persistent `selected_tile` | One explicit farm tile flows into the order and verifier. |
| Tool call | Crew work order and `AgentActor` directive | Named NPC walks to and performs the requested farm action. |
| Guard | `SkillCheckEvaluator` | Checked before drafting and again when the agent arrives. |
| Success check | Before/after farm snapshots | Tile, crop, or inventory proof runs only after correlated work. |
| Failure handling | Compiler trace and Field Log | Parse, validation, guard, order, and world-check failures remain teaching receipts. |
| Run recap | `GameEventLog` and day summary | Final status, runner, target, result, and Drift survive the immediate trace. |
| Curriculum | `SkillLessonLibrary`, `SkillTutorLibrary`, `PlayerProgress` | Ten mastery-gated lessons, escalating local hints, exact-source program shelf. |

## Shipped Workbench Flow

1. On a fresh profile, the current lesson source and goal appear in the open Workbench.
2. The player selects one farm tile and edits the program.
3. `COMPILE` or Cmd/Ctrl+Enter runs the parser and validator.
4. Manual source continues through the existing runtime guard and drafts one named-NPC crew order; compilation alone is not success.
5. The player sends a manual order and the named farmhand walks to the target.
6. `on day_start` source instead deep-copies the selected target and source evidence into one in-memory arm. Compile performs no guard check, drafts no order, and mutates no world state; a visible `DISARM` control can consume it deliberately.
7. End Day grows and advances the farm first, then consumes the arm once. If another Forge run is pending, the activation records a skipped receipt and cannot cancel or replace that run. Otherwise its new-day guard runs and valid work auto-dispatches without Send.
8. The guard is checked again on arrival before either route's farm action executes. A correlated action event triggers the concrete after-state check; automatic crew-action failure is terminal for that activation.
9. The trace and Field Log record `PASSED`, `FAILED`, `BLOCKED`, `SKIPPED`, `REPLACED`, or `DISARMED` as appropriate. Automatic activations do not complete the ten manual lessons.
10. Exact parser/validator-valid source can be saved to and restored from the local program shelf without executing or arming it.

## Starter Templates

### Clear Patch

Use a target tile, inspect it, clear brush if present, validate open ground.

### Plant Seed

Inspect an open selected tile, plant a seed, and verify that a crop now exists.

### Tend Crops

Inspect a growing crop, tend it, and verify that the same crop advanced a growth stage.

### Harvest Crops

Inspect a ready crop, harvest it, and verify that Grain increased.

### Build Fence

Inspect an open tile, route a fence crew order, and verify fence decor after the action.

## Shipped UI Surfaces

### Forge Panel

Compact template panel with contract preview, validation warnings, Check/Fix revision controls, Run, lifecycle trace, and latest receipt.

### Agent Workbench

Editable Skill Script v1 source, Compile control, current lesson goal, deterministic tutor layer, technical trace, exact-source save/load controls, pending/terminal run state, and the visible `ARMED ONCE · DAY START`/captured-target/`DISARM` state.

### Run Preview

Shows trigger, context, tool allowlist, ordered steps, and success check before execution.

### Field Log

Immediate receipt stream for compile, draft, execution, guard, verification, lesson, and Forge events.

### Crew Row

Shows when a named NPC is assigned or executing Forge-authored work.

### Day Summary

Includes compact terminal Forge run recaps.

## Validation Rules

The validator rejects:

- Missing or malformed skill identity.
- Missing, malformed, or unsupported triggers; only `manual` and `day_start` are allowed.
- Missing or unsupported context and step targets.
- Empty, unknown, or unlisted tools.
- Missing steps or unsupported guard conditions.
- Missing or unsupported success checks, including check-specific proof metadata.
- Missing blocked-run handling or a concrete revision suggestion.
- Missing receipt/template data.

Arbitrary code and unrelated world mutation are not expressible in Skill Script v1; they never become validator input from the Workbench.

The validator warns on:

- Long display names or duplicate tool entries.
- Unknown optional source-context labels.
- More than three compiled steps.
- Missing or non-snake-case step ids.
- Missing clarity metadata such as a tile-state `decor_id`.
- Missing or vague receipt labels.
- A failure suggestion that is too short or only says "try again."

## Safety Model

Skill Script v1 is safe by construction.

- No arbitrary scripting or GDScript execution.
- No `eval` or dynamic source execution.
- No shell access.
- No network access.
- No file writes from player-authored specs.
- Only allowlisted tools.
- Tool names, targets, guards, and success checks are schema-validated.
- Context reads must be explicit.
- Runs must produce receipts.

## Shipped Acceptance Contract

- A player can type, compile, save, reload, and execute a bounded agent program.
- Parser and validator failures stop before world mutation and return actionable diagnostics.
- A valid run uses the selected tile, named NPC, real crew-order route, arrival-time guard, and observed after-state check.
- A valid `on day_start` program captures its target without guard/order/mutation at Compile, fires once only after the next End Day advances the world, and never requires Send.
- A busy Forge runtime is never replaced by the activation; the arm records one skip and is consumed. Moving selection after Compile cannot retarget it, and loading saved source cannot restore it.
- A compiled or drafted order never fabricates a pass; only correlated world evidence closes the run.
- Field Log, technical trace, tutor copy, and day summary expose the run lifecycle and final outcome.
- Ten ordered lessons grant mastery only from qualifying player-authored terminal Workbench runs.
- Focused smokes and the cold-start QA harness prove the local loop without a network or model dependency.

## Current Non-Goals

These are product boundaries for Skill Script v1, not a rejection of code authoring—the bounded code editor and compiler are the product.

- Natural-language-to-program generation or live model calls.
- Arbitrary GDScript, JavaScript, shell, Python, plugins, imports, or user-defined functions.
- Variables, arithmetic, loops, recursion, exceptions, or general expression evaluation.
- Branching beyond one optional `when` guard around the single `use` statement.
- More than one farm action, selected tile, or executing agent in one player program.
- Repeating schedules, persisted arms, arbitrary timers, or any event trigger besides the one-shot `day_start` activation.
- Multi-agent planning, multi-tile targets, or long-running autonomous programs.
- Player-authored file/network access, persistent cloud sync, a skill marketplace, or program sharing.
- New lesson tiers, export templates, and distribution builds in the current Session 4 scope.

## Deferred Product Questions

- Should the Workbench eventually gain a physical in-world workshop or remain a UI surface?
- How should NPC personality alter future program critique without changing deterministic semantics?
- When should additional event triggers, multi-tile programs, and multi-agent coordination unlock?
- Should programs become collectible notebook objects or shareable artifacts?
- Where should the optional future LLM-observer seam add commentary without entering the deterministic execution path?

## Resolved Product Direction

The shipped foundation uses these decisions:

- Fantasy: the player is an apprentice learning how agents work by teaching NPCs safe task specs.
- Place: a compiler-like Workbench stays visibly connected to the live farm rather than becoming a generic automation editor.
- First lesson: Clear Patch with Chuck, using a manual trigger, selected-tile context, a brush guard, a tile-state check, and a named receipt.
- Failure tone: failures are specific teaching moments, with gentle personality copy layered above exact technical evidence.
- Hallucination Drift: validation warnings produce `wobbly`/`sweating`/`crew_noticing`; hard blockers produce `hallucinating`/`glitched`/`crew_worried`. These are data contracts for the farm and UI feedback layers.

## Risks

### Too Abstract

If the Forge feels like filling forms disconnected from the farm, it will lose the cozy AgentVille texture.

Mitigation: every field should map to a visible farm consequence or receipt.

### Too Much Syntax At Once

If the Workbench introduces every concept at once, it may feel like homework instead of a learn-to-code game.

Mitigation: the ten-lesson ladder starts from a working program, asks for one bounded change at a time, and pairs friendly tutor copy with exact trace evidence.

### Too Magical

If the agent just does things without receipts, players will not learn the skill shape.

Mitigation: make every run leave a visible trace.

### Too Broad

If v1 expands beyond one action, target, agent, and the documented manual/one-shot trigger boundary, its teaching contract may blur before the fundamentals are solid.

Mitigation: preserve the documented v1 boundary; add future capabilities as explicit bounded slices with their own smokes and teaching contract.

## Shipped Implementation Map

### Slice 1: PRD And Spec Validator

- Implemented in `scripts/systems/SkillSpecValidator.gd`.
- Validates one dictionary-shaped spec.
- Returns errors, warnings, run permission, normalized receipt template, and data-only Hallucination Drift state.
- Covered by `tools/smoke_skill_forge_spec_validator.gd` for valid Tend Crops specs, unknown tools, warning-only drift, and missing receipts.

### Slice 2: Forge Template Data

- Implemented in `scripts/systems/SkillForgeTemplateLibrary.gd`.
- Adds static starter specs for Tend Crops, Plant Seed, Clear Patch, Harvest Crops, and Build Fence.
- Provides compact template preview data for the live Forge panel without exposing full step data in preview rows.
- Covered by `tools/smoke_skill_forge_templates.gd`, which validates every starter spec through `SkillSpecValidator.gd`.

### Slice 3: Manual Run Harness

- Implemented in `scripts/systems/SkillForgeRunHarness.gd`.
- Converts a valid Tend Crops, Plant Seed, Clear Patch, Harvest Crops, or Build Fence spec into a deterministic local directive.
- Maps Tend Crops, Clear Patch, Plant Seed, Harvest Crops, and Build Fence to current work-order-shaped `tend_crop`, `clear_brush`, `plant_seed`, `harvest_crop`, and `build_fence` directives.
- Returns Field Log copy and event-log payloads for start, pass, fail, and blocked states.
- Covered by `tools/smoke_skill_forge_run_harness.gd`, including blocked-run Hallucination Drift copy.

### Slice 4: Minimal Forge Panel

- Implemented in `scripts/ui/GameUI.gd` and wired from `scripts/core/Game.gd`.
- Connects the template library and run harness to a compact panel with Tend Crops, Plant Seed, Clear Patch, Harvest Crops, and Build Fence preview selectors plus a Run button.
- Records returned Field Log lines and event-log payloads through existing game surfaces.
- Covered by `tools/smoke_skill_forge_panel.gd`, including template preview selection and started/passed receipt visibility.

### Slice 5: Revision Loop

- Implemented in `scripts/ui/GameUI.gd` and `scripts/core/Game.gd`.
- Adds a bounded Check/Fix template loop: Check runs a flawed copy of the selected starter spec, shows the validator issue, Hallucination Drift state, and concrete revision suggestion, then Fix reruns the clean starter spec.
- Records blocked and passed receipts through existing Field Log and event-log surfaces.
- Covered by `tools/smoke_skill_forge_revision_loop.gd`.

### Slice 6: Structured Spec Preview

- Implemented in `scripts/systems/SkillForgeTemplateLibrary.gd` and rendered in `scripts/ui/GameUI.gd`.
- Extends starter template previews with compact contract fields: trigger, context, ordered tools, step ids, success check, and receipt label.
- Shows those fields directly in the Forge panel so players can read the agent-skill shape alongside the source editor.
- Covered by `tools/smoke_skill_forge_spec_preview.gd`.

### Slice 7: Day Summary Forge Recaps

- Implemented in `scripts/ai/GameEventLog.gd` and `scripts/core/Game.gd`.
- Aggregates `skill_forge_run` events into unique run receipts with final status, agent, skill name, result detail, and Drift state.
- Adds compact Forge recaps to formatted day summaries so passed and blocked starter runs persist beyond the immediate Field Log.
- Covered by `tools/smoke_skill_forge_day_summary.gd`.

### Slice 8: Work-Order Directive Drafts

- Implemented in `scripts/core/Game.gd` and `scripts/ui/GameUI.gd`.
- Turns valid Tend Crops, Clear Patch, Plant Seed, Harvest Crops, and Build Fence `work_order_directive` specs into ready crew-order rows with Forge metadata, run id, skill name, Field Log receipt, work-order event, and `Forge` context chip.
- Tend Crops targets a growing, not-ready crop and advances its growth once through the existing crop-growth path.
- Covered by `tools/smoke_skill_forge_work_order_directive.gd`.

### Slice 9: Forge Work Receipts

- Implemented in `scripts/core/Game.gd`, `scripts/ai/AgentActor.gd`, and `scripts/ai/GameEventLog.gd`.
- Carries Forge metadata from a sent Forge-authored work order into agent action/world-action events, active in-world reason badges, completed work receipts, and day-summary `forge work` recaps.
- Keeps Forge execution context separate from social preference context so a skill run does not appear as memory, truce, or Mission Momentum work.
- Covered by `tools/smoke_skill_forge_work_receipts.gd`.

### Slice 10: Skill Script v1 And Agent Workbench

- Implemented in `scripts/systems/SkillScriptParser.gd`, `scripts/core/Game.gd`, and `scripts/ui/GameUI.gd`.
- Parses the documented v1 source into allowlisted specs, preserves selected-tile and source provenance, drafts one named-agent order, and closes only from a correlated post-action check.
- Covered by `tools/smoke_skill_script_parser.gd`, `tools/smoke_parse_error_battery.gd`, `tools/smoke_workbench_compile.gd`, `tools/smoke_skill_check_evaluator.gd`, and the Workbench/selection UI smokes.

### Slice 11: Curriculum, Tutor, And Persistence

- Implemented in `scripts/systems/SkillLessonLibrary.gd`, `scripts/systems/SkillTutorLibrary.gd`, and `scripts/systems/PlayerProgress.gd` with `Game.gd`/`GameUI.gd` integration.
- Adds ten ordered mastery-gated lessons, deterministic three-stage hints, exact-source program saving, and safe local resume behavior.
- Covered by `tools/smoke_skill_lessons.gd`, `tools/smoke_lesson_completion.gd`, `tools/smoke_tutor_copy.gd`, `tools/smoke_player_progress.gd`, and the two-process lesson walkthrough.

### Slice 12: One-Shot Day-Start Trigger

- Implemented in `scripts/systems/SkillTriggerScheduler.gd`, `SkillScriptParser.gd`, `SkillSpecValidator.gd`, `SkillForgeRunHarness.gd`, `Game.gd`, and `GameUI.gd`.
- Adds optional `on day_start` syntax while preserving implicit `manual`; Compile captures one immutable selected-tile activation without a guard, order, or mutation, and End Day advances the world before consuming and auto-dispatching it once.
- A pending Forge run causes a truthful consumed skip instead of replacement. Explicit disarm, replacement, guard block, action failure, and pass states remain deterministic and receipt-backed; arms are not persisted and cannot complete manual lessons.
- Covered by `tools/smoke_skill_trigger_scheduler.gd`, `tools/smoke_workbench_trigger_controls.gd`, `tools/smoke_day_start_trigger.gd`, and `tools/capture_day_start_trigger.gd`.

## Historical Discovery Questionnaire

These questions drove the original Forge design session. They remain as decision history and as prompts for explicitly versioned future work; they are not evidence that the shipped v1 foundation is still unchosen.

### North Star

1. What should a player say after their first successful Forge run?
2. Is the fantasy "I taught an agent" or "I built a farm spell" or something else?
3. Should Skill Forge feel more like a workshop, notebook, schoolhouse, lab, shrine, terminal, or barn toolbench?
4. What emotion should a failed run create: curiosity, comedy, responsibility, or urgency?
5. What would make the Forge unmistakably AgentVille rather than a generic automation editor?

### Player Role

6. Is the player a teacher, mayor, farmer, apprentice, designer, supervisor, or collaborator?
7. Do players write skills for themselves, for NPCs, or for a helper bot?
8. Should NPC personality affect how a skill is interpreted?
9. Should NPCs critique specs before running them?
10. Should a player ever be able to ignore validation and run anyway?

### Skill Shape

11. What fields are essential in the first skill spec?
12. What fields should wait until later?
13. Should triggers be manual-only at first?
14. Should context be chosen from chips, forms, text, or farm selection?
15. Should success checks be visible as test-like assertions?
16. Should failure handling be required for every skill?
17. Should receipts be player-authored, generated, or templated?
18. Should skills be named like recipes, spells, tasks, scripts, or missions?

### First Skill

19. What is the best first skill: clear brush, tend crops, restock kits, build fence, or inspect farm?
20. What is the smallest run that still feels meaningful?
21. Should the first run use a current Mission Momentum context?
22. Should the first run require selecting a tile?
23. Should the first run have an intentional failure case for teaching?
24. What should the first pass/fail recap say?

### UI And UX

25. Where should the Forge live in the UI?
26. Does it need a new panel, or can it start inside the crew/mission area?
27. Should the player see raw structured data?
28. Should there be a friendly form over the structured data?
29. Should the run preview look like a checklist, recipe card, trace, or mission plan?
30. Should validation errors appear inline, in the Field Log, or in a dedicated result panel?
31. How much screen space can the Forge claim without hurting the farm view?

### Agent Behavior

32. Who executes the skill?
33. Should the executor visibly walk and work like current NPCs?
34. Should execution reserve resources and targets like work orders do?
35. Should agents comment during skill runs?
36. Should a run pause for player confirmation before risky steps?
37. Should agents remember successful skills?
38. Should NPC trust affect whether they accept a player-authored skill?

### Receipts And Memory

39. What should a Forge run receipt include every time?
40. Should receipts distinguish trigger, tool call, success check, and recap?
41. Should failed runs become memory?
42. Should successful runs create Mission Momentum?
43. Should NPC verdicts mention Forge runs?
44. Should day summaries group Forge runs separately from normal crew work?
45. Should the player be able to replay a run trace?

### Progression

46. How does the player unlock more tools?
47. Are new spec fields unlocked through missions?
48. Do NPCs teach templates based on their personality?
49. Should the Forge have levels, badges, notebooks, or recipes?
50. What is the reward for improving a skill?

### Safety And Boundaries

51. What should the Forge never allow?
52. What is the friendliest way to explain "this spec is unsafe"?
53. Should the player see the allowlisted tools explicitly?
54. How strict should the validator be?
55. Should a skill be allowed to affect multiple tiles?
56. Should a skill be allowed to spend resources?
57. Should a skill be allowed to trigger social consequences?

### Tone

58. How whimsical should Forge copy be?
59. Should skill failures be played straight or funny?
60. Should NPCs use technical words like trigger, context, tool, and validation?
61. What words should the game avoid?
62. What metaphor best fits: forging, teaching, gardening, choreography, recipes, or field notes?

### Long-Term Vision

63. Do skills eventually become shareable?
64. Can NPCs propose skills to the player?
65. Can a mission require writing or revising a skill?
66. Can skills become part of daily farm automation?
67. Can skills interact with Parley, truces, and memory?
68. What would a "masterpiece" skill look like after many hours of play?

## Foundation Decisions Now Shipped

- Executor: one named NPC farmhand through the existing crew-order and `AgentActor` path.
- First lesson action: Chuck clears brush on `selected_tile` and proves the empty tile state.
- Primary UI: editable Agent Workbench; starter templates remain a secondary readable path.
- Success checks: explicit tile, crop, or inventory observations after correlated work.
- Failure copy: deterministic tutor guidance plus exact technical diagnostics and one repair suggestion.
- Raw data: players author the bounded language and read contract previews, not arbitrary runtime dictionaries.
- Mission Momentum: optional source context for relevant templates, not a prerequisite for Workbench programs.
- Triggers: implicit manual dispatch plus one optional, in-memory `on day_start` activation; no repeats, restoration, or other events.
- Receipts: immediate compiler/Field Log feedback plus terminal day-summary recaps.
- Original foundation slice: `SkillSpecValidator.gd` and `smoke_skill_forge_spec_validator.gd`; both shipped and became the base for the implementation map above.
