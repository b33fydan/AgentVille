class_name SkillTutorLibrary
extends RefCounted

const PARSE_CLASSES := ["lexical", "syntax", "structure", "identity"]
const DRIFT_LEVELS := ["steady", "wobbly", "hallucinating"]
const GUARD_CONDITIONS := ["always", "inspect.has_brush", "crop.needs_tending", "crop.ready", "tile.empty"]
const LIFECYCLE_STATES := ["order", "order_blocked", "pending", "retrying", "replaced", "cancelled", "timeout", "armed", "fired", "skipped", "disarmed"]
const CHECK_TYPES := ["tile_state", "crop_state", "inventory_delta"]

const PARSE_COPY := {
	"lexical": "The parser found a character or string it cannot read. Repair the marked text before checking the program structure.",
	"syntax": "The parser found unfinished punctuation or statement syntax. Fix the marked line, then compile again.",
	"structure": "The statements do not form one complete agent program. Keep one observe, use, verify, and receipt path.",
	"identity": "The declaration names an unknown farmhand or blank receipt. Use Bert, Marigold, or Chuck and give the run a label."
}

const VALIDATOR_COPY := {
	"duplicate_tool": "The tool allowlist repeats the same tool. Keep one copy of each allowed tool.",
	"empty_tool": "The tool allowlist contains a blank entry. Replace it with a named farm tool or remove it.",
	"invalid_id": "The skill id is not lowercase snake_case. Rewrite the id with lowercase words joined by underscores.",
	"invalid_source_context": "The source context is not a list. Use a list of known source labels.",
	"invalid_step": "One step is not a structured step record. Replace it with a step that names an id, tool, and target.",
	"invalid_step_id": "A step id is not lowercase snake_case. Rename the step with lowercase words and underscores.",
	"long_name": "The skill name is too long for the compact Forge row. Shorten the receipt label before compiling again.",
	"missing_blocked_action": "The skill has no blocked-run action. Add record_receipt so a stopped run still leaves evidence.",
	"missing_context": "The skill has no farm context. Add selected_tile context before using a tool.",
	"missing_context_target": "The context has no target. Set its target to selected_tile.",
	"missing_crop_state": "The crop-state check has no expected state. Use planted or growth_advanced for the matching tool.",
	"missing_failure_handling": "The skill has no blocked-run handling. Add a record_receipt action and a concrete revision suggestion.",
	"missing_failure_suggestion": "The blocked-run handler has no revision step. Name the target, guard, or tool the player should change.",
	"missing_id": "The skill has no stable id. Add a short lowercase snake_case id.",
	"missing_inventory_delta": "The inventory check has no minimum change. Add the smallest acceptable item delta.",
	"missing_inventory_item": "The inventory check has no item id. Name the resource the tool should change.",
	"missing_name": "The skill has no player-facing name. Give the receipt a short description of the run.",
	"missing_receipt": "The skill cannot leave a receipt. Add one quoted receipt label after verification.",
	"missing_receipt_label": "The receipt has no readable label. Name the result the run is meant to prove.",
	"missing_step_id": "A step has no stable id. Add a short lowercase snake_case step id.",
	"missing_step_target": "A step has no target. Point it at context.target or selected_tile.",
	"missing_step_tool": "A step has no tool call. Choose one tool from the skill allowlist.",
	"missing_steps": "The skill contains no visible work step. Add one allowlisted tool call.",
	"missing_success_check": "The skill has no pass or fail check. Add a check that measures the tool's farm effect.",
	"missing_success_check_type": "The success check has no type. Choose tile_state, crop_state, or inventory_delta.",
	"missing_success_target": "The success check has no target. Point it at context.target or selected_tile.",
	"missing_tile_decor": "The tile-state check does not name expected decor. Set decor_id to the state the tool should leave behind.",
	"missing_tools": "The skill has no tool allowlist. Add the farm tool used by its step.",
	"missing_trigger": "The skill has no trigger. Use manual, or add on day_start for one reactive run.",
	"step_tool_not_listed": "The step calls a tool outside its own allowlist. Add that tool to the list or change the step call.",
	"too_many_steps": "This skill carries more than three steps. Split the job into smaller verifiable skills.",
	"unknown_source_context": "The source context label is unknown. Replace it with a supported farm history source.",
	"unknown_tool": "That tool is outside the farm allowlist. Replace it with a listed local farm tool.",
	"unsupported_condition": "The guard condition has no local evaluator. Replace it with a supported farm condition.",
	"unsupported_context_target": "The context target is outside this Forge. Use selected_tile for the current lesson.",
	"unsupported_step_target": "The step target is outside this Forge. Use context.target or selected_tile.",
	"unsupported_success_check": "The verifier cannot run that check type. Use tile_state, crop_state, or inventory_delta.",
	"unsupported_success_target": "The verifier cannot read that target. Use context.target or selected_tile.",
	"unsupported_trigger": "That event is outside the local allowlist. Use manual, or add on day_start for one reactive run.",
	"vague_receipt_label": "The receipt label is too vague to audit later. Rename it after the result the run proves.",
	"weak_failure_suggestion": "The blocked-run suggestion does not name a repair. Point to the target, guard, tool, or check to revise."
}

const VALIDATOR_FALLBACK := "The validator found an unmapped spec issue. Fix the first technical error, then compile again."
const PIPELINE_FALLBACK := "The local pipeline needs a specific repair before it can continue. Read the technical line, then revise that field."

const DRIFT_COPY := {
	"steady": "The spec is steady and ready for its declared trigger. Follow the runtime state to send or fire it.",
	"wobbly": "The spec can run, but a warning makes its contract wobbly. Read the warning before its trigger continues.",
	"hallucinating": "A hard validator blocker has pushed the spec into hallucinating drift. Fix the first error before arming or sending work."
}

const LIFECYCLE_COPY := {
	"order": "The program drafted a crew order from its tool call. Send that order so the farm can test the check.",
	"order_blocked": "The spec passed validation, but the target cannot accept its tool. Select a compatible tile and compile again.",
	"pending": "The crew is changing the farm. Wait for the world check.",
	"retrying": "The crew attempt missed, so the same order returned to ready. Send it again or repair the target condition.",
	"replaced": "A newer compile replaced the pending run. Use the newest order and ignore the retired receipt.",
	"cancelled": "The pending order was cancelled before verification. Compile again when a compatible target is selected.",
	"timeout": "The order never completed within two day advances. Retarget or simplify the run before compiling again.",
	"armed": "The program captured its selected tile and is armed once. End the day to fire it, or disarm it before then.",
	"fired": "Day start fired the armed program once. The crew order now follows the same guard and world checks as a manual run.",
	"skipped": "The day-start program was consumed without replacing active crew work. Compile it again after the current run finishes.",
	"disarmed": "The one-shot program was disarmed before day start. Its source remains available to revise or arm again."
}


func parse_classes() -> Array:
	return PARSE_CLASSES.duplicate()


func validator_codes() -> Array:
	return VALIDATOR_COPY.keys().duplicate()


func drift_levels() -> Array:
	return DRIFT_LEVELS.duplicate()


func guard_conditions() -> Array:
	return GUARD_CONDITIONS.duplicate()


func lifecycle_states() -> Array:
	return LIFECYCLE_STATES.duplicate()


func check_types() -> Array:
	return CHECK_TYPES.duplicate()


func registry() -> Dictionary:
	return {
		"parse_classes": parse_classes(),
		"validator_codes": validator_codes(),
		"drift_levels": drift_levels(),
		"guard_conditions": guard_conditions(),
		"lifecycle_states": lifecycle_states(),
		"check_types": check_types(),
		"lesson_escalation": [1, 2, 3]
	}


func has_parse_copy(error_class: String) -> bool:
	return PARSE_COPY.has(error_class)


func has_validator_copy(code: String) -> bool:
	return VALIDATOR_COPY.has(code)


func line_for(state_key: String, detail_key: String = "", context: Dictionary = {}) -> String:
	match state_key:
		"parse", "parse_error":
			return str(PARSE_COPY.get(detail_key, PIPELINE_FALLBACK))
		"validator", "validation":
			return str(VALIDATOR_COPY.get(detail_key, VALIDATOR_FALLBACK))
		"drift":
			return str(DRIFT_COPY.get(detail_key, PIPELINE_FALLBACK))
		"guard":
			return _guard_line(detail_key, bool(context.get("allowed", false)))
		"check":
			return _check_line(detail_key, bool(context.get("passed", false)))
		"lifecycle":
			return str(LIFECYCLE_COPY.get(detail_key, PIPELINE_FALLBACK))
		"order":
			return str(LIFECYCLE_COPY.get("order_blocked" if detail_key == "blocked" else "order", PIPELINE_FALLBACK))
		"pending", "retrying", "replaced", "cancelled", "timeout", "order_blocked", "armed", "fired", "skipped", "disarmed":
			return str(LIFECYCLE_COPY.get(state_key, PIPELINE_FALLBACK))
	return PIPELINE_FALLBACK


func lesson_hint(lesson: Dictionary, attempt: int, success: bool = false) -> String:
	return "\n".join(lesson_hint_lines(lesson, attempt, success))


func lesson_hint_lines(lesson: Dictionary, attempt: int, success: bool = false) -> Array[String]:
	var tutor: Dictionary = lesson.get("tutor", {}) if typeof(lesson.get("tutor", {})) == TYPE_DICTIONARY else {}
	if success:
		return [str(tutor.get("success", "The world check passed. Read the receipt and name the concept it proved."))]

	var lines: Array[String] = [str(tutor.get("failure", "The lesson check did not pass. Compare the goal with the technical result."))]
	if attempt <= 1:
		lines.append(str(tutor.get("first_hint", "Read the lesson concept, then revise one field.")))
	elif attempt == 2:
		lines.append(str(tutor.get("targeted_hint", "Revise the field named by the technical result.")))
	else:
		lines.append(str(tutor.get("targeted_hint", "Revise the field named by the technical result.")))
		var fix_diff = tutor.get("fix_diff", [])
		if typeof(fix_diff) == TYPE_ARRAY:
			for diff_line in fix_diff:
				var text := str(diff_line).strip_edges()
				if text != "":
					lines.append(text)
	return lines


func _guard_line(condition: String, allowed: bool) -> String:
	match condition:
		"always":
			return "The selected tile exists, so the always guard is open. Send the order to test its tool." if allowed else "The always guard still needs a real tile. Select a farm tile and compile again."
		"inspect.has_brush":
			return "The selected tile contains brush, so the brush guard is open. Send clear_brush to test the tile check." if allowed else "The brush guard found no tall grass or flowers. Select brush and compile again."
		"crop.needs_tending":
			return "The crop is still growing, so the tending guard is open. Send tend_crop and verify its stage." if allowed else "The tending guard needs a growing crop that is not ready. Select one before compiling again."
		"crop.ready":
			return "The crop is mature, so the harvest guard is open. Send harvest_crop and verify the inventory change." if allowed else "The harvest guard needs a ready crop. Select a mature crop before compiling again."
		"tile.empty":
			return "The tile has no crop, decor, or structure, so the empty guard is open. Send the planting or building tool." if allowed else "The empty-tile guard found an occupied target. Select open ground before compiling again."
	return PIPELINE_FALLBACK


func _check_line(check_type: String, passed: bool) -> String:
	match check_type:
		"tile_state":
			return "The tile-state check matched the farm. Read the receipt to see which decor state it proved." if passed else "The tile-state check did not match the farm. Compare expected decor with observed decor before revising."
		"crop_state":
			return "The crop-state check observed the requested crop change. Read the receipt to identify that transition." if passed else "The crop-state check saw a different transition. Compare the before and after crop stages before revising."
		"inventory_delta":
			return "The inventory-delta check observed the requested resource change. Read the receipt to identify the measured delta." if passed else "The inventory-delta check measured too little change. Compare the expected and observed item counts before revising."
	return PIPELINE_FALLBACK
