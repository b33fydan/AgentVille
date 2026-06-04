# Skill Forge PRD

Status: pre-implementation vision
Scope: final foundation slice before Skill Forge implementation
Codebase: AgentVille Godot 4 prototype

## Product Summary

Skill Forge is a cozy agent-harness learning mode inside AgentVille. Players write safe, structured skill specs and watch NPCs or helper bots execute those specs on the farm. The mode should teach the shape of agent skills through play: triggers, context, tools, ordered steps, receipts, verification, memory, and failure handling.

The Forge is not a general programming IDE. It is a readable, forgiving farm workshop where a player can describe a useful routine, see how an agent interprets it, inspect what happened, and revise the routine with confidence.

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

### 1. Structured Before Freeform

The first Forge should use safe structured specs, not arbitrary scripts. Players can author fields and steps, but the runtime only executes known farm tools and deterministic checks.

### 2. Visible Runs

Every run should leave a readable trail: why it started, what context it used, what tool calls happened, what succeeded, what failed, and what the next revision might change.

### 3. Cozy Competence

The Forge should feel like learning by tending a farm, not debugging a compiler. Errors should be specific, friendly, and actionable.

### 4. Local First

The MVP should stay deterministic and local. No live API dependency is required for the first playable Forge loop.

### 5. Existing Systems Win

If a Forge concept can map to missions, work orders, Field Log receipts, day summaries, NPC comments, or smoke-style validation, it should use those paths first.

## MVP Concept

The first playable MVP is a single Forge panel that lets the player assemble one safe skill spec and run it on the farm.

Example skill:

```text
Name: Clear a pressure patch
Trigger: Manual
Context: Use the current target tile and recent Mission Momentum reason
Tools: inspect_tile, clear_brush
Steps:
  1. Inspect the target tile.
  2. If it contains brush, clear it.
  3. Record a receipt with the source context.
Success check: Target tile no longer has brush.
Failure handling: If the tile is not brush, write a blocked receipt and suggest retargeting.
```

The player presses Run, a helper/NPC executes the routine through existing work-order and agent-action systems, then the Forge shows a pass/fail recap.

## Skill Spec v0

The first spec should be a dictionary-shaped object that can be serialized and validated.

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

The first Forge only needs manual triggers. Later triggers can include day start, Mission Momentum, memory consequence, inventory threshold, or crop-ready events.

### context

Defines what the skill can see. Context should be explicit. A skill should not silently read the whole world.

### tools

An allowlist of tool actions. A skill can only call tools listed here.

### steps

Ordered execution plan. MVP steps should be simple, deterministic, and visible.

### success_check

The pass/fail condition for the run. This should be concrete enough to render as a visible validation chip.

### failure_handling

What the run does when blocked, invalid, or incomplete. This is a first-class part of the skill, not an afterthought.

### receipt

What gets written to the Field Log and day summary.

## Existing System Mapping

| Forge Concept | Existing AgentVille System | MVP Reuse |
| --- | --- | --- |
| Skill spec | Dictionary resource or saved data | New validator, no arbitrary code |
| Trigger | Player action or day event | Manual trigger first |
| Context | Mission/source/memory snapshots | Reuse preference/source context vocabulary |
| Tool call | Work order or agent directive | Reuse work-order assignment |
| Step | Mission step or directive step | Reuse demand/work-order progression where possible |
| Receipt | Field Log event | Reuse readable source/origin receipt helpers |
| Success check | Smoke-style assertion | Start with tile/inventory state checks |
| Failure handling | Failed receipt and blocked order copy | Reuse failed receipt context |
| Run recap | Day summary run recap | Extend recent Mission Momentum recap patterns |
| Observer verdict | NPC summary comment/vibe scorer | Reuse local deterministic observers |

## First Playable Flow

1. Player opens Skill Forge from the existing UI.
2. Player chooses a starter template.
3. Player fills safe fields: name, target context, allowed tool, success check.
4. Forge validates the spec and shows warnings before running.
5. Player presses Run.
6. A helper/NPC receives a deterministic directive or work order.
7. Field Log records trigger, tool call, result, and source context.
8. Forge shows pass/fail with a compact run recap.
9. Player revises the spec and runs again.

## Starter Templates

### Clear Patch

Use a target tile, inspect it, clear brush if present, validate open ground.

### Tend Growth

Find a ready crop or prepared soil, harvest or plant when valid, validate inventory/resource change.

### Restock Kit

Choose an NPC kit need, check inventory, craft or gather support resources, validate item count.

### Boundary Check

Inspect a fence or open boundary tile, build when valid, validate fence placement.

## MVP UI Surfaces

### Forge Panel

Compact tool panel with template choice, spec fields, validation warnings, run button, and latest result.

### Run Preview

Shows trigger, context, tool allowlist, ordered steps, and success check before execution.

### Field Log

Continues to be the immediate receipt stream.

### Crew Row

Shows when an NPC/helper is running a Forge-authored skill.

### Day Summary

Adds run recap lines for completed Forge runs.

## Validation Rules

The validator should reject:

- Unknown tools.
- Missing success checks.
- Steps that reference unavailable context.
- Specs with no receipt.
- Specs that require arbitrary code execution.
- Specs that try to mutate unrelated world state.
- Specs that cannot produce a pass/fail result.

The validator should warn on:

- Very broad context.
- A success check that does not match the tool.
- More than three steps in the MVP.
- A receipt label that is too vague.
- A failure handler that only says "try again."

## Safety Model

The first Forge must be safe by construction.

- No arbitrary scripting.
- No eval.
- No shell access.
- No network access.
- No file writes from player-authored specs.
- Only allowlisted tools.
- Tool parameters must be schema-validated.
- Context reads must be explicit.
- Runs must produce receipts.

## Success Criteria

The first Forge slice is successful when:

- A player can author or choose one structured skill spec.
- The spec validates before running.
- The run executes through existing deterministic farm systems.
- The Field Log shows trigger, tool action, and result.
- The run records pass or fail.
- A failed run gives a specific revision suggestion.
- A day-summary recap names the run and outcome.
- A smoke script can prove the full local loop without live APIs.

## Non-Goals For MVP

- Natural-language freeform skill generation.
- Live model calls.
- General code editing.
- Multi-agent planning.
- Long-term skill marketplace.
- Persistent cloud sync.
- Complex branching logic.
- Arbitrary loops.

## Open Product Questions

- Is Skill Forge a literal place on the farm, a UI panel, or both?
- Does the player write specs as themselves, or as an in-world apprentice?
- Are NPCs the executors, or is there a separate helper bot?
- Should bad specs be funny, instructive, or quietly corrective?
- How much should the Forge teach real agent-building terms?
- Should the first Forge run require an existing Mission Momentum context?
- Should skill specs be collectible objects, recipes, or notebook entries?

## Questionnaire Direction

The first answered direction is:

- Fantasy: the player is an apprentice learning how agents work by teaching NPCs safe task specs.
- Place: the Forge should feel like a lab connected to the farm, not a generic automation editor.
- First task: Tend Crops, using manual trigger, selected farm context, visible success checks, required failure handling, and templated receipts.
- Failure tone: early failures can be funny, but repeated bad specs should produce visible Hallucination Drift.
- Hallucination Drift starts as data, not animation: validation warnings create a wobbly state with sweating/crew-noticing hints, while hard blockers create a hallucinating state with glitched/crew-worried hints.

## Risks

### Too Abstract

If the Forge feels like filling forms disconnected from the farm, it will lose the cozy AgentVille texture.

Mitigation: every field should map to a visible farm consequence or receipt.

### Too Programmery

If the MVP exposes too much syntax, it may feel like homework.

Mitigation: use templates, constrained fields, and readable previews.

### Too Magical

If the agent just does things without receipts, players will not learn the skill shape.

Mitigation: make every run leave a visible trace.

### Too Broad

If the first Forge supports many tools and triggers, it may blur before it becomes fun.

Mitigation: start with one or two farm skills and one manual trigger.

## Implementation Plan

### Slice 1: PRD And Spec Validator

- Implemented in `scripts/systems/SkillSpecValidator.gd`.
- Validates one dictionary-shaped spec.
- Returns errors, warnings, run permission, normalized receipt template, and data-only Hallucination Drift state.
- Covered by `tools/smoke_skill_forge_spec_validator.gd` for valid Tend Crops specs, unknown tools, warning-only drift, and missing receipts.

### Slice 2: Forge Template Data

- Implemented in `scripts/systems/SkillForgeTemplateLibrary.gd`.
- Adds static starter specs for Tend Crops and Clear Patch.
- Provides compact template preview data for future UI without exposing full step data in preview rows.
- Covered by `tools/smoke_skill_forge_templates.gd`, which validates every starter spec through `SkillSpecValidator.gd`.

### Slice 3: Manual Run Harness

- Implemented in `scripts/systems/SkillForgeRunHarness.gd`.
- Converts a valid Tend Crops or Clear Patch spec into a deterministic local directive.
- Maps Clear Patch to a current work-order-shaped `clear_brush` directive, while Tend Crops remains a Forge-only directive until farm execution exists.
- Returns Field Log copy and event-log payloads for start, pass, fail, and blocked states.
- Covered by `tools/smoke_skill_forge_run_harness.gd`, including blocked-run Hallucination Drift copy.

### Slice 4: Minimal Forge Panel

- Implemented in `scripts/ui/GameUI.gd` and wired from `scripts/core/Game.gd`.
- Connects the template library and run harness to a compact panel with Tend Crops and Clear Patch preview selectors plus a Run button.
- Records returned Field Log lines and event-log payloads through existing game surfaces.
- Covered by `tools/smoke_skill_forge_panel.gd`, including template preview selection and started/passed receipt visibility.

### Slice 5: Revision Loop

- Implemented in `scripts/ui/GameUI.gd` and `scripts/core/Game.gd`.
- Adds a bounded Check/Fix loop before the full editor: Check runs a flawed copy of the selected starter spec, shows the validator issue, Hallucination Drift state, and concrete revision suggestion, then Fix reruns the clean starter spec.
- Records blocked and passed receipts through existing Field Log and event-log surfaces.
- Covered by `tools/smoke_skill_forge_revision_loop.gd`.

### Slice 6: Structured Spec Preview

- Implemented in `scripts/systems/SkillForgeTemplateLibrary.gd` and rendered in `scripts/ui/GameUI.gd`.
- Extends starter template previews with compact contract fields: trigger, context, ordered tools, step ids, success check, and receipt label.
- Shows those fields directly in the Forge panel so players can read the agent-skill shape before a full editor exists.
- Covered by `tools/smoke_skill_forge_spec_preview.gd`.

### Slice 7: Day Summary Forge Recaps

- Implemented in `scripts/ai/GameEventLog.gd` and `scripts/core/Game.gd`.
- Aggregates `skill_forge_run` events into unique run receipts with final status, agent, skill name, result detail, and Drift state.
- Adds compact Forge recaps to formatted day summaries so passed and blocked starter runs persist beyond the immediate Field Log.
- Covered by `tools/smoke_skill_forge_day_summary.gd`.

## Questionnaire For The Big PRD Session

Use these questions when you sit down to think through the full Forge vision.

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

## Decision Checklist For Starting Implementation

Before coding the Forge, choose:

- First executor: NPC or helper bot.
- First skill template.
- First UI surface.
- First success check type.
- First failure suggestion style.
- Whether the player sees raw spec data.
- Whether the first run requires Mission Momentum context.
- Whether Forge run recaps live in day summaries, Field Log, or both.

## Recommended First Implementation Slice

Add a local `SkillSpecValidator.gd` and one `smoke_skill_forge_spec_validator.gd`.

This is the safest next step because it lets the project define the rules of a skill before it asks agents to execute one.
