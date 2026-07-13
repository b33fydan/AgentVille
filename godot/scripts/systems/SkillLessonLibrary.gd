class_name SkillLessonLibrary
extends RefCounted

const LESSON_IDS := [
	"run_brush_starter",
	"name_brush_receipt",
	"reassign_brush_agent",
	"retarget_selected_tile",
	"guard_ready_harvest",
	"repair_unknown_tool",
	"repair_verification",
	"repair_syntax",
	"decompose_two_jobs",
	"author_plant_skill"
]

const TIER_ORDER := ["run_read", "modify", "debug", "author"]
const COMPLETION_KEYS := [
	"player_initiated",
	"allowed_origins",
	"status",
	"action",
	"agent_id",
	"guard_condition",
	"check_type",
	"check_passed",
	"receipt_label",
	"target_source",
	"requires_nonempty_source",
	"requires_source_change",
	"required_failure_keys"
]

const CLEAR_CHUCK_STARTER := "agent \"Chuck\" {\n  observe selected_tile\n  when inspect.has_brush {\n    use clear_brush(selected_tile)\n  }\n  verify tile_state\n  receipt \"Clear Patch run\"\n}"
const CLEAR_CHUCK_BRUSH_PROOF := "agent \"Chuck\" {\n  observe selected_tile\n  when inspect.has_brush {\n    use clear_brush(selected_tile)\n  }\n  verify tile_state\n  receipt \"Brush Proof run\"\n}"
const PLANT_MARIGOLD := "agent \"Marigold\" {\n  observe selected_tile\n  when tile.empty {\n    use plant_seed(selected_tile)\n  }\n  verify crop_state\n  receipt \"Seed Context run\"\n}"
const HARVEST_ALWAYS := "agent \"Marigold\" {\n  observe selected_tile\n  when always {\n    use harvest_crop(selected_tile)\n  }\n  verify inventory_delta\n  receipt \"Guarded Harvest run\"\n}"
const UNKNOWN_TOOL_SOURCE := "agent \"Chuck\" {\n  observe selected_tile\n  when inspect.has_brush {\n    use summon_rain(selected_tile)\n  }\n  verify tile_state\n  receipt \"Allowlist Repair run\"\n}"
const WRONG_CHECK_SOURCE := "agent \"Marigold\" {\n  observe selected_tile\n  when crop.ready {\n    use harvest_crop(selected_tile)\n  }\n  verify weather_state\n  receipt \"Verified Harvest run\"\n}"
const BROKEN_SYNTAX_SOURCE := "agent \"Marigold\" {\n  observe selected_tile\n  when tile.empty {\n    use plant_seed(selected_tile\n  }\n  verify crop_state\n  receipt \"Syntax Repair run\"\n}"
const TWO_JOB_SOURCE := "agent \"Chuck\" {\n  observe selected_tile\n  when inspect.has_brush {\n    use clear_brush(selected_tile)\n    use plant_seed(selected_tile)\n  }\n  verify tile_state\n  receipt \"One Job run\"\n}"


func get_lesson_ids() -> Array:
	return LESSON_IDS.duplicate()


func first_lesson_id() -> String:
	return str(LESSON_IDS[0]) if not LESSON_IDS.is_empty() else ""


func next_lesson_id(lesson_id: String) -> String:
	var index := LESSON_IDS.find(lesson_id)
	if index < 0 or index + 1 >= LESSON_IDS.size():
		return ""
	return str(LESSON_IDS[index + 1])


func get_lesson(lesson_id: String) -> Dictionary:
	for lesson in _lessons():
		if str(lesson.get("id", "")) == lesson_id:
			return lesson.duplicate(true)
	return {}


func list_lessons(completed: Array = []) -> Array:
	var result := []
	for lesson in _lessons():
		var snapshot: Dictionary = lesson.duplicate(true)
		var lesson_id := str(snapshot.get("id", ""))
		if completed.has(lesson_id):
			snapshot["state"] = "completed"
		elif is_unlocked(lesson_id, completed):
			snapshot["state"] = "unlocked"
		else:
			snapshot["state"] = "locked"
		result.append(snapshot)
	return result


func is_unlocked(lesson_id: String, completed: Array = []) -> bool:
	var lesson := get_lesson(lesson_id)
	if lesson.is_empty():
		return false
	for prerequisite in lesson.get("requires", []):
		if not completed.has(str(prerequisite)):
			return false
	return true


func completion_condition_evaluable(condition: Dictionary) -> bool:
	for key in condition.keys():
		if not COMPLETION_KEYS.has(str(key)):
			return false
	if typeof(condition.get("allowed_origins", [])) != TYPE_ARRAY or condition.get("allowed_origins", []).is_empty():
		return false
	for required_key in ["status", "action", "agent_id", "guard_condition", "check_type", "receipt_label", "target_source"]:
		if str(condition.get(required_key, "")).strip_edges() == "":
			return false
	if typeof(condition.get("required_failure_keys", [])) != TYPE_ARRAY:
		return false
	return true


func evaluate_completion(lesson_id: String, evidence: Dictionary) -> Dictionary:
	var lesson := get_lesson(lesson_id)
	if lesson.is_empty():
		return {"evaluable": false, "complete": false, "mismatches": ["unknown lesson"]}
	var condition: Dictionary = lesson.get("completion_condition", {})
	if not completion_condition_evaluable(condition):
		return {"evaluable": false, "complete": false, "mismatches": ["invalid completion condition"]}

	var mismatches: Array[String] = []
	var run: Dictionary = evidence.get("run", {}) if typeof(evidence.get("run", {})) == TYPE_DICTIONARY else {}
	var verdict: Dictionary = evidence.get("check_verdict", {}) if typeof(evidence.get("check_verdict", {})) == TYPE_DICTIONARY else {}
	_match_value(mismatches, "player_initiated", bool(condition.get("player_initiated", true)), bool(evidence.get("player_initiated", false)))

	var origin := str(evidence.get("origin", run.get("origin", ""))).strip_edges()
	if not condition.get("allowed_origins", []).has(origin):
		mismatches.append("origin")
	_match_value(mismatches, "status", str(condition.get("status", "")), str(evidence.get("status", run.get("status", ""))))
	_match_value(mismatches, "action", str(condition.get("action", "")), str(evidence.get("action", run.get("action", ""))))
	_match_value(mismatches, "agent_id", str(condition.get("agent_id", "")), str(evidence.get("agent_id", run.get("agent_id", ""))))
	_match_value(mismatches, "guard_condition", str(condition.get("guard_condition", "")), str(evidence.get("guard_condition", "")))
	_match_value(mismatches, "check_type", str(condition.get("check_type", "")), str(evidence.get("check_type", verdict.get("check_type", run.get("success_check_type", "")))))
	_match_value(mismatches, "check_passed", bool(condition.get("check_passed", true)), bool(evidence.get("check_passed", verdict.get("passed", false))))
	_match_value(mismatches, "receipt_label", str(condition.get("receipt_label", "")), str(evidence.get("receipt_label", run.get("receipt_label", ""))))
	_match_value(mismatches, "target_source", str(condition.get("target_source", "")), str(evidence.get("target_source", run.get("target_source", ""))))

	var source_text := str(evidence.get("source_text", "")).strip_edges()
	if bool(condition.get("requires_nonempty_source", false)) and source_text == "":
		mismatches.append("source_text")
	if bool(condition.get("requires_source_change", false)) and source_text == str(lesson.get("starting_editor_text", "")).strip_edges():
		mismatches.append("source_change")

	var seen_failures = evidence.get("failure_keys", [])
	if typeof(seen_failures) != TYPE_ARRAY:
		seen_failures = []
	for required_failure in condition.get("required_failure_keys", []):
		if not seen_failures.has(str(required_failure)):
			mismatches.append("failure:%s" % str(required_failure))

	return {
		"evaluable": true,
		"complete": mismatches.is_empty(),
		"mismatches": mismatches
	}


func _match_value(mismatches: Array[String], field_name: String, expected, observed) -> void:
	if expected != observed:
		mismatches.append(field_name)


func _condition(action: String, agent_id: String, guard_condition: String, check_type: String, receipt_label: String, origins: Array, require_source: bool, require_change: bool, failure_keys: Array = []) -> Dictionary:
	return {
		"player_initiated": true,
		"allowed_origins": origins.duplicate(),
		"status": "passed",
		"action": action,
		"agent_id": agent_id,
		"guard_condition": guard_condition,
		"check_type": check_type,
		"check_passed": true,
		"receipt_label": receipt_label,
		"target_source": "selected_tile",
		"requires_nonempty_source": require_source,
		"requires_source_change": require_change,
		"required_failure_keys": failure_keys.duplicate()
	}


func _tutor(success: String, failure: String, first_hint: String, targeted_hint: String, fix_diff: Array) -> Dictionary:
	return {
		"success": success,
		"failure": failure,
		"first_hint": first_hint,
		"targeted_hint": targeted_hint,
		"fix_diff": fix_diff.duplicate()
	}


func _lessons() -> Array:
	return [
		{
			"id": "run_brush_starter",
			"order": 1,
			"tier": "run_read",
			"requires": [],
			"title": "Run the brush starter",
			"concept": "Sequencing and manual triggers",
			"goal": "Select a brush tile, run the starter, send its order, then read the receipt.",
			"starting_editor_text": CLEAR_CHUCK_STARTER,
			"completion_condition": _condition("clear_brush", "chuck", "inspect.has_brush", "tile_state", "Clear Patch run", ["workbench"], true, false),
			"tutor": _tutor(
				"The receipt proves the brush left the tile. That sequence is a manually triggered agent run.",
				"The starter did not clear brush and verify the tile. Select live brush before sending the order.",
				"A trigger starts the sequence. Select brush, then run and send the starter.",
				"The inspect.has_brush guard needs tall grass or flowers. Move selected_tile onto one of those patches.",
				["- target empty tile", "+ target brush tile"]
			)
		},
		{
			"id": "name_brush_receipt",
			"order": 2,
			"tier": "run_read",
			"requires": ["run_brush_starter"],
			"title": "Name the proof",
			"concept": "Receipts as run evidence",
			"goal": "Change the receipt label to Brush Proof run, then clear a second brush tile.",
			"starting_editor_text": CLEAR_CHUCK_STARTER,
			"completion_condition": _condition("clear_brush", "chuck", "inspect.has_brush", "tile_state", "Brush Proof run", ["workbench"], true, true),
			"tutor": _tutor(
				"Brush Proof run names the evidence the check produced. A receipt makes an agent run auditable.",
				"The farm changed, but the receipt label is not Brush Proof run. Rename that final line and compile again.",
				"A useful receipt says what the run proved. Edit only the quoted label on the final line.",
				"Keep the clear_brush sequence and replace Clear Patch run with Brush Proof run.",
				["- receipt \"Clear Patch run\"", "+ receipt \"Brush Proof run\""]
			)
		},
		{
			"id": "reassign_brush_agent",
			"order": 3,
			"tier": "modify",
			"requires": ["name_brush_receipt"],
			"title": "Reassign the farmhand",
			"concept": "Agent assignment",
			"goal": "Change Chuck to Bert, then have Bert clear a third brush tile with the same proof receipt.",
			"starting_editor_text": CLEAR_CHUCK_BRUSH_PROOF,
			"completion_condition": _condition("clear_brush", "bert", "inspect.has_brush", "tile_state", "Brush Proof run", ["workbench"], true, true),
			"tutor": _tutor(
				"Bert received the order and the same check still passed. Agent assignment changes the worker without changing the contract.",
				"The clear-brush contract passed under the wrong farmhand. Change the quoted agent name to Bert.",
				"The agent declaration chooses who receives the work. Leave the guard, tool, check, and receipt alone.",
				"Replace Chuck with Bert on the first line, then compile against a fresh brush tile.",
				["- agent \"Chuck\" {", "+ agent \"Bert\" {"]
			)
		},
		{
			"id": "retarget_selected_tile",
			"order": 4,
			"tier": "modify",
			"requires": ["reassign_brush_agent"],
			"title": "Move the context",
			"concept": "Context and selected targets",
			"goal": "Select an empty tile and use selected_tile context to plant a seed there.",
			"starting_editor_text": PLANT_MARIGOLD,
			"completion_condition": _condition("plant_seed", "marigold", "tile.empty", "crop_state", "Seed Context run", ["workbench"], true, false),
			"tutor": _tutor(
				"The new crop appeared on selected_tile. Context is the farm information the agent can read for this run.",
				"The selected context did not produce a new crop. Move selected_tile to ground with no crop, decor, or structure.",
				"Observe tells the agent which farm context it may read. Point selected_tile at open ground.",
				"Keep observe selected_tile and select a truly empty tile before compiling.",
				["- target occupied tile", "+ target empty selected_tile"]
			)
		},
		{
			"id": "guard_ready_harvest",
			"order": 5,
			"tier": "modify",
			"requires": ["retarget_selected_tile"],
			"title": "Guard the harvest",
			"concept": "Conditionals and runtime guards",
			"goal": "Replace always with crop.ready so harvesting runs only on a ready crop.",
			"starting_editor_text": HARVEST_ALWAYS,
			"completion_condition": _condition("harvest_crop", "marigold", "crop.ready", "inventory_delta", "Guarded Harvest run", ["workbench"], true, true),
			"tutor": _tutor(
				"The crop.ready guard opened only for a mature crop. A conditional keeps the tool call inside a safe boundary.",
				"The harvest ran without the crop.ready condition. Replace the broad always guard before compiling again.",
				"A conditional asks a question before using a tool. Make the question match a harvestable crop.",
				"Change when always to when crop.ready, then select a mature crop.",
				["- when always {", "+ when crop.ready {"]
			)
		},
		{
			"id": "repair_unknown_tool",
			"order": 6,
			"tier": "debug",
			"requires": ["guard_ready_harvest"],
			"title": "Stay on the allowlist",
			"concept": "Tool allowlists",
			"goal": "Let the validator catch summon_rain, then replace it with clear_brush and pass the run.",
			"starting_editor_text": UNKNOWN_TOOL_SOURCE,
			"completion_condition": _condition("clear_brush", "chuck", "inspect.has_brush", "tile_state", "Allowlist Repair run", ["workbench"], true, true, ["validation.unknown_tool"]),
			"tutor": _tutor(
				"clear_brush is inside the farm allowlist and the world check passed. Allowlists bound what an agent may do.",
				"summon_rain is outside the farm tool allowlist. Replace that tool call with clear_brush.",
				"The validator blocks tools the farm has not granted. Find the tool call that has no local implementation.",
				"Keep the brush guard and change only summon_rain to clear_brush.",
				["- use summon_rain(selected_tile)", "+ use clear_brush(selected_tile)"]
			)
		},
		{
			"id": "repair_verification",
			"order": 7,
			"tier": "debug",
			"requires": ["repair_unknown_tool"],
			"title": "Match the verifier",
			"concept": "Verification and debugging",
			"goal": "Let weather_state fail validation, then verify the harvest with inventory_delta.",
			"starting_editor_text": WRONG_CHECK_SOURCE,
			"completion_condition": _condition("harvest_crop", "marigold", "crop.ready", "inventory_delta", "Verified Harvest run", ["workbench"], true, true, ["validation.unsupported_success_check"]),
			"tutor": _tutor(
				"The inventory delta matched the harvested grain. Verification compares an expected result with observed farm state.",
				"weather_state is not a supported success check. Use inventory_delta to measure the grain change.",
				"A verifier must measure the effect of the tool. Harvesting changes inventory rather than weather.",
				"Replace verify weather_state with verify inventory_delta, then select a ready crop.",
				["- verify weather_state", "+ verify inventory_delta"]
			)
		},
		{
			"id": "repair_syntax",
			"order": 8,
			"tier": "debug",
			"requires": ["repair_verification"],
			"title": "Repair the tool call",
			"concept": "Syntax debugging",
			"goal": "Read the parser location, close the plant_seed call, then plant on an empty tile.",
			"starting_editor_text": BROKEN_SYNTAX_SOURCE,
			"completion_condition": _condition("plant_seed", "marigold", "tile.empty", "crop_state", "Syntax Repair run", ["workbench"], true, true, ["parse.syntax"]),
			"tutor": _tutor(
				"The closed tool call parsed and planted a crop. Syntax gives the compiler an exact structure to follow.",
				"The plant_seed call is missing its closing parenthesis. Close the call before the line ends.",
				"The parser location points to an unfinished tool call. Compare its opening and closing punctuation.",
				"Add the missing right parenthesis after selected_tile, then compile again.",
				["- use plant_seed(selected_tile", "+ use plant_seed(selected_tile)"]
			)
		},
		{
			"id": "decompose_two_jobs",
			"order": 9,
			"tier": "debug",
			"requires": ["repair_syntax"],
			"title": "Split the job",
			"concept": "Decomposition",
			"goal": "Let two use statements fail, then keep clear_brush as one focused skill.",
			"starting_editor_text": TWO_JOB_SOURCE,
			"completion_condition": _condition("clear_brush", "chuck", "inspect.has_brush", "tile_state", "One Job run", ["workbench"], true, true, ["parse.structure"]),
			"tutor": _tutor(
				"One focused tool call cleared the brush and passed its check. Decomposition turns a broad job into small verifiable skills.",
				"This program still holds more than one use statement. Keep clear_brush here and move planting into another skill.",
				"A small skill should own one farm job. Decide which result this receipt is meant to prove.",
				"Remove the plant_seed line so this skill only clears and verifies brush.",
				["- use plant_seed(selected_tile)"]
			)
		},
		{
			"id": "author_plant_skill",
			"order": 10,
			"tier": "author",
			"requires": ["decompose_two_jobs"],
			"title": "Author a planting skill",
			"concept": "Authoring an agent workflow",
			"goal": "From a blank editor, write Marigold a guarded planting skill with a crop-state check and First Plant Skill run receipt.",
			"starting_editor_text": "",
			"completion_condition": _condition("plant_seed", "marigold", "tile.empty", "crop_state", "First Plant Skill run", ["workbench"], true, true),
			"tutor": _tutor(
				"The blank page became a guarded, verified planting skill. The full workflow now belongs to your program library.",
				"The authored run is missing part of the planting contract. Include Marigold, selected_tile, tile.empty, plant_seed, crop_state, and the named receipt.",
				"Build the contract in order: agent, context, condition, tool, verification, receipt. Keep one use statement.",
				"Use tile.empty with plant_seed, verify crop_state, and finish with First Plant Skill run.",
				[
					"+ agent \"Marigold\" {",
					"+   observe selected_tile",
					"+   when tile.empty {",
					"+     use plant_seed(selected_tile)",
					"+   }",
					"+   verify crop_state",
					"+   receipt \"First Plant Skill run\"",
					"+ }"
				]
			)
		}
	]
