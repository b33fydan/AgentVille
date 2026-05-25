# Adversarial NPC Layered Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build AgentVille's first adversarial NPC layer: funny, sarcastic, visible NPC irritation and fourth-wall reactions driven by local event receipts, with a clean path to bounded AI model sessions later.

**Architecture:** Start with deterministic local reactions because the current Godot prototype already has `GameEventLog.gd`, `AgentActor.gd`, `AgentManager.gd`, and `UtilityAgentDecisionModel.gd`. Add a small reaction/scoring layer that reads player events, updates NPC irritation/expression, and selects tagged dialogue. Later layers add bounded "argument match" sessions and optional API/model adapters without putting live model calls in the moment-to-moment farm loop.

**Tech Stack:** Godot 4.6, GDScript, existing smoke tools under `godot/tools`, optional future HTTP/API adapter behind explicit settings.

---

## Layer Roadmap

### Layer 0: Checkpoint Current Prototype

Purpose: Keep the already-fixed UI field-targeting bug separate from adversarial NPC work.

Scope:
- Commit the current UI input fix and new smoke test before starting NPC changes.
- Do not mix UI bug-fix history with the new AI design branch.

Verification:
- `Godot --headless --path godot --quit`
- `smoke_ui_field_targeting.gd`
- `smoke_work_orders.gd`

### Layer 1: Local Adversarial Reactions

Purpose: Make NPCs visibly react when the player succeeds, fails, spams bad actions, ignores work, or creates annoying orders. No LSTM, no API.

Player-visible result:
- NPC face/expression changes: neutral, pleased, side-eye, annoyed, angry.
- Annoyed NPCs can turn reddish, shake briefly, stare at the camera, and drop short sarcastic lines.
- Crew panel shows mood/irritation signal.
- Field Log records the reaction receipt.

Why first:
- It is the cheapest version of the hook.
- It is testable.
- It reinforces the "NPCs are watching" fantasy immediately.
- It creates the structured event data that later AI/model layers need.

### Layer 2: Vibe Scoring And Daily Verdicts

Purpose: Convert raw receipts into an interpretable player "vibe profile" that powers roasts and longer memory.

Player-visible result:
- End Day produces a sharper day verdict.
- NPCs reference patterns like repeated failed placements, abandoned jobs, good harvest streaks, or chaotic overbuilding.

Implementation stance:
- Start with thresholds and running summaries.
- Do not use LSTM until there is enough event history and a concrete prediction problem.

### Layer 3: Bounded Adversarial Encounter Harness

Purpose: Prototype the "match health bar" idea as a finite-duration argument/negotiation encounter with an NPC.

Player-visible result:
- A small encounter panel opens with an NPC grievance.
- The session has a limited meter: patience, attention, or argument stamina.
- The player chooses or types responses.
- The NPC pushes back using local dialogue first.
- The session ends with a verdict and reward/penalty.

Implementation stance:
- First version can be local and menu-driven.
- Text input and model-backed responses come later.

### Layer 4: Optional Live Model Adapter

Purpose: Add a plug-in point for a cheap model or API model without making the game dependent on it.

Player-visible result:
- A warning/settings toggle says live AI costs money and may use external calls.
- The game can fall back to local dialogue if no key/model is configured.

Implementation stance:
- Never store API keys in repo.
- Never call model every frame or every NPC tick.
- Only call the model at bounded moments: encounter verdict, end-day roast, special NPC argument.

### Layer 5: LSTM/Classifier Research Harness

Purpose: Export action sequences and train/test a small intent or vibe predictor later.

Player-visible result:
- None initially. This is a research support layer.

Implementation stance:
- Export JSONL receipts first.
- Train from the deterministic system or captured play sessions later.
- LSTM suggests intent or vibe; deterministic validators decide what is legal.

### Layer 6: Crafting Integration

Purpose: Once NPCs can judge/react, connect crafting to their demands and grievances.

Player-visible result:
- NPCs ask for crafted things, complain about missing kits, judge wasteful crafting, and reward useful production.

---

## File Map For Layer 1

Create:
- `godot/scripts/ai/AgentReactionModel.gd`
  - Scores one event for one NPC.
  - Returns mood/irritation deltas, expression, optional line tag, and reaction intensity.
- `godot/scripts/ai/AgentDialogueLibrary.gd`
  - Stores first-pass local tagged lines for grizzled, hopeful, and chaotic personalities.
  - Keeps runtime free and deterministic.
- `godot/tools/smoke_adversarial_reactions.gd`
  - Feeds repeated bad player actions into the scene and asserts that a focused NPC becomes annoyed/angry and emits a reaction.

Modify:
- `godot/scripts/ai/AgentActor.gd`
  - Add `irritation`, `expression`, and `reaction_intensity` to state.
  - Apply reaction results during `observe_event`.
  - Update the voxel rig with face label, red tint, and shake.
- `godot/scripts/ai/AgentManager.gd`
  - Keep focused-agent routing, but support stronger visible reaction from the focused agent.
  - Avoid every NPC roasting every single click.
- `godot/scripts/ui/GameUI.gd`
  - Show irritation/expression in crew rows without expanding the panel too much.
- `godot/scripts/core/Game.gd`
  - Ensure reaction-relevant receipts include action, success, item, target tile, resources, and crafted cost.
- `godot/README.md`
  - Document adversarial reaction smoke and current non-API stance.

---

## Layer 1 Task Plan

### Task 0: Commit Current UI Field-Targeting Fix

**Files:**
- Stage existing modified UI/input files only.

- [ ] **Step 1: Verify current bug fix still passes**

Run:
```bash
/Users/beefymacmini/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Volumes/beefybackup/AgentVille/godot --script res://tools/smoke_ui_field_targeting.gd
```

Expected: exit code 0.

- [ ] **Step 2: Commit the bug fix separately**

Run:
```bash
git add godot/README.md godot/scripts/tools/PlacementTool.gd godot/scripts/ui/GameUI.gd godot/tools/smoke_ui_field_targeting.gd godot/tools/smoke_ui_field_targeting.gd.uid
git commit -m "Fix field targeting after UI crew order clicks"
```

Expected: one clean commit containing only the field-targeting fix.

### Task 1: Add The Reaction Model

**Files:**
- Create: `godot/scripts/ai/AgentReactionModel.gd`
- Test: `godot/tools/smoke_adversarial_reactions.gd`

- [ ] **Step 1: Write the model smoke**

The smoke should:
- Instantiate `AgentReactionModel.gd`.
- Feed one successful player action.
- Feed three failed player actions.
- Assert that failures create positive irritation and an annoyed/angry expression.

Expected assertions:
- success reaction expression is `pleased` or `neutral`.
- repeated failures produce `side_eye`, `annoyed`, or `angry`.
- repeated failures increase irritation by at least 18.

- [ ] **Step 2: Implement minimal reaction model**

Core contract:
```gdscript
class_name AgentReactionModel
extends RefCounted

func score_event(agent_state: Dictionary, event: Dictionary, focus: bool = false) -> Dictionary:
	var event_type := str(event.get("type", ""))
	if event_type != "player_action" and event_type != "work_order":
		return {}

	var success := bool(event.get("success", true))
	var action := str(event.get("action", "work"))
	var multiplier := 1.35 if focus else 1.0
	var irritation_delta := 0.0
	var mood_delta := 0.0
	var expression := "neutral"
	var tag := ""

	if success:
		mood_delta = 1.5 * multiplier
		irritation_delta = -2.0 * multiplier
		expression = "pleased"
		tag = "approve_%s" % action
	else:
		mood_delta = -2.5 * multiplier
		irritation_delta = 8.0 * multiplier
		expression = "side_eye"
		tag = "fail_%s" % action

	var current_irritation := float(agent_state.get("irritation", 0.0)) + irritation_delta
	if current_irritation >= 55.0:
		expression = "angry"
	elif current_irritation >= 28.0:
		expression = "annoyed"

	return {
		"mood_delta": mood_delta,
		"irritation_delta": irritation_delta,
		"expression": expression,
		"line_tag": tag,
		"intensity": clampf(abs(irritation_delta) / 10.0, 0.0, 1.0)
	}
```

- [ ] **Step 3: Run the smoke and confirm it passes**

Run:
```bash
/Users/beefymacmini/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Volumes/beefybackup/AgentVille/godot --script res://tools/smoke_adversarial_reactions.gd
```

Expected: exit code 0.

### Task 2: Add Local Dialogue Tags

**Files:**
- Create: `godot/scripts/ai/AgentDialogueLibrary.gd`
- Modify: `godot/scripts/ai/AgentActor.gd`
- Test: `godot/tools/smoke_adversarial_reactions.gd`

- [ ] **Step 1: Add dialogue library**

Contract:
```gdscript
class_name AgentDialogueLibrary
extends RefCounted

func line_for(agent_state: Dictionary, reaction: Dictionary, event: Dictionary) -> String:
	var trait := str(agent_state.get("trait", "steady"))
	var expression := str(reaction.get("expression", "neutral"))
	var action := str(event.get("action", "work")).replace("_", " ")
	var lines := _lines(trait, expression, action)
	if lines.is_empty():
		return ""
	return str(lines[randi() % lines.size()])
```

Initial line direction:
- Bert/grizzled: dry, annoyed, practical.
- Marigold/hopeful: disappointed but still trying.
- Chuck/chaotic: amused, meme-ish, likes mess but still judges.

- [ ] **Step 2: Expand smoke assertions**

Add a focused failed action and assert that `comment_generated` emits a line containing the focused NPC name.

- [ ] **Step 3: Run smoke**

Run:
```bash
/Users/beefymacmini/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Volumes/beefybackup/AgentVille/godot --script res://tools/smoke_adversarial_reactions.gd
```

Expected: exit code 0.

### Task 3: Wire Reactions Into AgentActor

**Files:**
- Modify: `godot/scripts/ai/AgentActor.gd`
- Modify: `godot/scripts/ai/AgentManager.gd`
- Test: `godot/tools/smoke_adversarial_reactions.gd`

- [ ] **Step 1: Add state fields in setup**

Add to `state`:
```gdscript
"irritation": float(config.get("irritation", 0.0)),
"expression": "neutral",
"reaction_intensity": 0.0
```

- [ ] **Step 2: Apply reactions in `observe_event`**

Flow:
```gdscript
var reaction := reaction_model.score_event(state, event, focus)
if not reaction.is_empty():
	_apply_reaction(reaction, event)
```

`_apply_reaction` must:
- Clamp mood to 0..100.
- Clamp irritation to 0..100.
- Set expression.
- Set reaction intensity.
- Emit one comment only when dialogue library returns a line.
- Emit `state_changed`.

- [ ] **Step 3: Keep routing focused**

In `AgentManager.gd`, keep the current one-focused-agent model for `player_action` events. This prevents all three NPCs from shouting every click.

- [ ] **Step 4: Run existing and new smokes**

Run:
```bash
/Users/beefymacmini/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Volumes/beefybackup/AgentVille/godot --script res://tools/smoke_adversarial_reactions.gd
/Users/beefymacmini/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Volumes/beefybackup/AgentVille/godot --script res://tools/smoke_agents.gd
/Users/beefymacmini/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Volumes/beefybackup/AgentVille/godot --script res://tools/smoke_receipts.gd
```

Expected: all exit code 0.

### Task 4: Add Visible Face, Red Tint, And Shake

**Files:**
- Modify: `godot/scripts/ai/AgentActor.gd`
- Test: `godot/tools/smoke_adversarial_reactions.gd`
- Optional capture: create `godot/tools/capture_adversarial_reaction.gd`

- [ ] **Step 1: Add face label to visual rig**

In `_build_visual`, add a `Label3D` named `FaceLabel` near the head. Initial text: `o_o`.

Expression map:
- `neutral`: `o_o`
- `pleased`: `^_^`
- `side_eye`: `-_-`
- `annoyed`: `>_>`
- `angry`: `-_-!`

- [ ] **Step 2: Add visual reaction application**

Add `_update_expression_visuals()` that:
- Sets face text from expression.
- Tints head or mood pip warmer when irritation increases.
- Adds a small shake in `_update_visual_motion` when `reaction_intensity > 0.25`.

- [ ] **Step 3: Add smoke assertions**

After repeated failed player events:
- focused agent snapshot expression is `annoyed` or `angry`.
- focused agent snapshot irritation is greater than 20.

- [ ] **Step 4: Generate screenshot**

Run:
```bash
/Users/beefymacmini/Downloads/Godot.app/Contents/MacOS/Godot --path /Volumes/beefybackup/AgentVille/godot --script res://tools/capture_screenshot.gd
```

Expected: screenshot updates at `godot/artifacts/screenshots/agentville-current.png`. If the reaction is not visible enough, create a dedicated capture script for the angry NPC moment.

### Task 5: Surface Irritation In Crew UI

**Files:**
- Modify: `godot/scripts/ui/GameUI.gd`
- Test: `godot/tools/smoke_adversarial_reactions.gd`

- [ ] **Step 1: Extend agent snapshots**

In `AgentActor.get_snapshot`, include:
```gdscript
"irritation": float(state.get("irritation", 0.0)),
"expression": str(state.get("expression", "neutral"))
```

- [ ] **Step 2: Update crew row copy**

In `GameUI.set_agent_snapshots`, show compact action text:
- normal: existing action text.
- annoyed/angry: prefix with face text or short state like `-_- Judging`.

Keep the right panel compact. Do not add a new large UI panel in Layer 1.

- [ ] **Step 3: Run UI and agent smokes**

Run:
```bash
/Users/beefymacmini/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Volumes/beefybackup/AgentVille/godot --script res://tools/smoke_adversarial_reactions.gd
/Users/beefymacmini/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Volumes/beefybackup/AgentVille/godot --script res://tools/smoke_work_orders.gd
```

Expected: all exit code 0.

### Task 6: Update Documentation And Commit Layer 1

**Files:**
- Modify: `godot/README.md`

- [ ] **Step 1: Document current stance**

README language:
- NPC adversarial reactions are local and deterministic.
- No API or LSTM is used in runtime yet.
- The event log is the future data source for observer/model layers.

- [ ] **Step 2: Run full relevant verification**

Run:
```bash
/Users/beefymacmini/Downloads/Godot.app/Contents/MacOS/Godot --headless --path godot --quit
/Users/beefymacmini/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Volumes/beefybackup/AgentVille/godot --script res://tools/smoke_adversarial_reactions.gd
/Users/beefymacmini/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Volumes/beefybackup/AgentVille/godot --script res://tools/smoke_agents.gd
/Users/beefymacmini/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Volumes/beefybackup/AgentVille/godot --script res://tools/smoke_receipts.gd
/Users/beefymacmini/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Volumes/beefybackup/AgentVille/godot --script res://tools/smoke_work_orders.gd
```

Expected: all exit code 0.

- [ ] **Step 3: Commit Layer 1**

Run:
```bash
git add godot/README.md godot/scripts/ai/AgentReactionModel.gd godot/scripts/ai/AgentDialogueLibrary.gd godot/scripts/ai/AgentActor.gd godot/scripts/ai/AgentManager.gd godot/scripts/ui/GameUI.gd godot/tools/smoke_adversarial_reactions.gd
git commit -m "Add local adversarial NPC reactions"
```

Expected: one commit for Layer 1 only.

---

## Layer 2 Design Notes

Create later:
- `godot/scripts/ai/PlayerVibeScorer.gd`
- `godot/tools/smoke_vibe_scorer.gd`

Responsibilities:
- Read summaries from `GameEventLog.gd`.
- Score player behavior into labels like `careful`, `productive`, `chaotic`, `wasteful`, `neglectful`.
- Feed stronger end-day lines without API.

Layer 2 should still avoid live model calls.

---

## Layer 3 Design Notes

Create later:
- `godot/scripts/ai/AdversarialSessionManager.gd`
- `godot/tools/smoke_adversarial_session.gd`

Responsibilities:
- Start a bounded encounter with one NPC.
- Track `patience_meter`, `turn_count`, `claims`, `npc_goal`, and `player_goal`.
- End by meter depletion or resolution.
- Produce a result event for `GameEventLog.gd`.

First version can use choice buttons before free text.

---

## Layer 4 Design Notes

Create later:
- `godot/scripts/ai/LiveModelAdapter.gd`
- `godot/scripts/ai/LocalDialogueModelAdapter.gd`
- `godot/tools/smoke_model_adapter_disabled.gd`

Responsibilities:
- Provide an interface like `generate_response(context: Dictionary) -> Dictionary`.
- Local adapter always works.
- Live adapter is disabled by default and must fail closed when no key/config is present.
- UI must warn that live AI can cost money.

---

## Self-Review

Spec coverage:
- Meme/sarcastic direction: covered by Layer 1 dialogue and expression work.
- NPC anger/red/shake/fourth-wall face: covered by Layer 1 Task 4.
- Cheap/local fake before API: covered by Layers 1 and 2.
- Bounded AI adversary/match health bar: covered by Layer 3.
- Optional API/pay-to-play harness: covered by Layer 4.
- LSTM as later possibility: covered by Layer 5 and design notes.
- Crafting after adversarial system: covered by Layer 6.

Execution recommendation:
- Execute Layer 0 and Layer 1 first.
- Stop for screenshot review after Layer 1 before building the bounded encounter harness.
