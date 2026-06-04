class_name SkillSpecValidator
extends RefCounted

const ALLOWED_TOOLS := [
	"inspect_tile",
	"tend_crop",
	"harvest_crop",
	"plant_seed",
	"clear_brush"
]
const SUPPORTED_CONTEXT_TARGETS := ["selected_tile"]
const SUPPORTED_STEP_TARGETS := ["context.target", "selected_tile"]
const SUPPORTED_SUCCESS_CHECKS := ["tile_state", "crop_state", "inventory_delta"]
const SUPPORTED_CONDITIONS := [
	"always",
	"inspect.has_brush",
	"crop.needs_tending",
	"crop.ready",
	"tile.empty"
]
const SUPPORTED_SOURCE_CONTEXT := [
	"completed_mission",
	"ignored_ask",
	"truce",
	"remembered_help",
	"completed_order"
]
const MAX_MVP_STEPS := 3
const MAX_COMPACT_NAME_LENGTH := 36


func validate(spec: Dictionary) -> Dictionary:
	var errors := []
	var warnings := []
	var normalized := _normalize_spec(spec)

	_validate_identity(normalized, errors, warnings)
	_validate_trigger(normalized, errors)
	_validate_context(normalized, errors, warnings)
	_validate_tools(normalized, errors, warnings)
	_validate_steps(normalized, errors, warnings)
	_validate_success_check(normalized, errors, warnings)
	_validate_failure_handling(normalized, errors, warnings)
	_validate_receipt(normalized, errors, warnings)

	var can_run := errors.is_empty()
	var drift := _build_drift_state(errors, warnings)
	return {
		"valid": can_run,
		"hard_blocked": not can_run,
		"can_run": can_run,
		"can_run_with_override": can_run and not warnings.is_empty(),
		"errors": errors,
		"warnings": warnings,
		"drift": drift,
		"normalized": normalized
	}


func allowed_tools() -> Array:
	return ALLOWED_TOOLS.duplicate()


func supported_success_checks() -> Array:
	return SUPPORTED_SUCCESS_CHECKS.duplicate()


func _normalize_spec(spec: Dictionary) -> Dictionary:
	var normalized := spec.duplicate(true)
	normalized["id"] = str(normalized.get("id", "")).strip_edges()
	normalized["name"] = str(normalized.get("name", "")).strip_edges()

	if normalized.has("receipt_template") and not normalized.has("receipt"):
		normalized["receipt"] = {
			"label": normalized.get("name", ""),
			"template": str(normalized.get("receipt_template", "")).strip_edges()
		}

	var receipt = normalized.get("receipt", {})
	if typeof(receipt) == TYPE_DICTIONARY:
		normalized["receipt_template"] = str(receipt.get("template", receipt.get("label", ""))).strip_edges()
	else:
		normalized["receipt_template"] = str(receipt).strip_edges()

	return normalized


func _validate_identity(spec: Dictionary, errors: Array, warnings: Array) -> void:
	var id := str(spec.get("id", "")).strip_edges()
	if id == "":
		_add_issue(errors, "missing_id", "id", "Give the skill a stable snake_case id.")
	elif not _is_snake_case(id):
		_add_issue(errors, "invalid_id", "id", "Skill ids must use lowercase snake_case.")

	var skill_name := str(spec.get("name", "")).strip_edges()
	if skill_name == "":
		_add_issue(errors, "missing_name", "name", "Give the skill a short player-facing name.")
	elif skill_name.length() > MAX_COMPACT_NAME_LENGTH:
		_add_issue(warnings, "long_name", "name", "Long names may not fit compact Forge rows.")


func _validate_trigger(spec: Dictionary, errors: Array) -> void:
	var trigger = spec.get("trigger", null)
	if typeof(trigger) != TYPE_DICTIONARY:
		_add_issue(errors, "missing_trigger", "trigger", "The MVP Forge needs a manual trigger.")
		return
	if str(trigger.get("type", "")).strip_edges() != "manual":
		_add_issue(errors, "unsupported_trigger", "trigger.type", "Only manual triggers are allowed in the first Forge.")


func _validate_context(spec: Dictionary, errors: Array, warnings: Array) -> void:
	var context = spec.get("context", null)
	if typeof(context) != TYPE_DICTIONARY:
		_add_issue(errors, "missing_context", "context", "Choose explicit farm context for the skill.")
		return

	var target := str(context.get("target", "")).strip_edges()
	if target == "":
		_add_issue(errors, "missing_context_target", "context.target", "Choose the farm selection this skill can see.")
	elif not SUPPORTED_CONTEXT_TARGETS.has(target):
		_add_issue(errors, "unsupported_context_target", "context.target", "The first Forge only supports selected_tile context.")

	var allowed_sources = context.get("allowed_sources", [])
	if typeof(allowed_sources) == TYPE_ARRAY:
		for source in allowed_sources:
			if not SUPPORTED_SOURCE_CONTEXT.has(str(source)):
				_add_issue(warnings, "unknown_source_context", "context.allowed_sources", "Unknown source context will be ignored by the MVP Forge.")
	elif context.has("allowed_sources"):
		_add_issue(warnings, "invalid_source_context", "context.allowed_sources", "Source context should be an array of known source labels.")


func _validate_tools(spec: Dictionary, errors: Array, warnings: Array) -> void:
	var tools = spec.get("tools", null)
	if typeof(tools) != TYPE_ARRAY or tools.is_empty():
		_add_issue(errors, "missing_tools", "tools", "Choose at least one allowlisted farm tool.")
		return

	var seen := {}
	for tool_value in tools:
		var tool_name := str(tool_value).strip_edges()
		if tool_name == "":
			_add_issue(errors, "empty_tool", "tools", "Tool names cannot be blank.")
			continue
		if seen.has(tool_name):
			_add_issue(warnings, "duplicate_tool", "tools", "Duplicate tools are ignored.")
		seen[tool_name] = true
		if not ALLOWED_TOOLS.has(tool_name):
			_add_issue(errors, "unknown_tool", "tools", "The tool '%s' is not allowlisted." % tool_name)


func _validate_steps(spec: Dictionary, errors: Array, warnings: Array) -> void:
	var steps = spec.get("steps", null)
	if typeof(steps) != TYPE_ARRAY or steps.is_empty():
		_add_issue(errors, "missing_steps", "steps", "Add at least one visible step.")
		return

	if steps.size() > MAX_MVP_STEPS:
		_add_issue(warnings, "too_many_steps", "steps", "Keep the first Forge skills to three steps or fewer.")

	var tools = spec.get("tools", [])
	var tool_allowlist := []
	if typeof(tools) == TYPE_ARRAY:
		for tool_value in tools:
			tool_allowlist.append(str(tool_value).strip_edges())

	for index in range(steps.size()):
		var step = steps[index]
		var field_prefix := "steps[%d]" % index
		if typeof(step) != TYPE_DICTIONARY:
			_add_issue(errors, "invalid_step", field_prefix, "Each step must be a dictionary.")
			continue

		var step_id := str(step.get("id", "")).strip_edges()
		if step_id == "":
			_add_issue(warnings, "missing_step_id", "%s.id" % field_prefix, "Step ids make receipts easier to read.")
		elif not _is_snake_case(step_id):
			_add_issue(warnings, "invalid_step_id", "%s.id" % field_prefix, "Step ids should use lowercase snake_case.")

		var tool_name := str(step.get("tool", "")).strip_edges()
		if tool_name == "":
			_add_issue(errors, "missing_step_tool", "%s.tool" % field_prefix, "Each step needs a tool.")
		elif not ALLOWED_TOOLS.has(tool_name):
			_add_issue(errors, "unknown_tool", "%s.tool" % field_prefix, "The step tool '%s' is not allowlisted." % tool_name)
		elif not tool_allowlist.has(tool_name):
			_add_issue(errors, "step_tool_not_listed", "%s.tool" % field_prefix, "Step tools must appear in the skill tool list.")

		var target := str(step.get("target", "")).strip_edges()
		if target == "":
			_add_issue(errors, "missing_step_target", "%s.target" % field_prefix, "Each step needs an explicit target.")
		elif not SUPPORTED_STEP_TARGETS.has(target):
			_add_issue(errors, "unsupported_step_target", "%s.target" % field_prefix, "Steps can only target context.target or selected_tile in the MVP Forge.")

		var condition := str(step.get("when", "always")).strip_edges()
		if condition == "":
			condition = "always"
		if not SUPPORTED_CONDITIONS.has(condition):
			_add_issue(warnings, "preview_condition_only", "%s.when" % field_prefix, "Unsupported conditions are preview-only until the run harness exists.")


func _validate_success_check(spec: Dictionary, errors: Array, warnings: Array) -> void:
	var success_check = spec.get("success_check", null)
	if typeof(success_check) != TYPE_DICTIONARY:
		_add_issue(errors, "missing_success_check", "success_check", "Add a concrete pass/fail check.")
		return

	var check_type := str(success_check.get("type", "")).strip_edges()
	if check_type == "":
		_add_issue(errors, "missing_success_check_type", "success_check.type", "Choose a success check type.")
	elif not SUPPORTED_SUCCESS_CHECKS.has(check_type):
		_add_issue(errors, "unsupported_success_check", "success_check.type", "Unsupported success checks cannot run safely.")

	var target := str(success_check.get("target", "")).strip_edges()
	if target == "":
		_add_issue(errors, "missing_success_target", "success_check.target", "Success checks need an explicit target.")
	elif not SUPPORTED_STEP_TARGETS.has(target):
		_add_issue(errors, "unsupported_success_target", "success_check.target", "Success checks can only target context.target or selected_tile in the MVP Forge.")

	if check_type == "crop_state" and str(success_check.get("state", "")).strip_edges() == "":
		_add_issue(errors, "missing_crop_state", "success_check.state", "Crop-state checks need the expected state.")
	if check_type == "tile_state" and not success_check.has("decor_id"):
		_add_issue(warnings, "missing_tile_decor", "success_check.decor_id", "Tile-state checks are clearer with an expected decor id.")
	if check_type == "inventory_delta":
		if str(success_check.get("item", "")).strip_edges() == "":
			_add_issue(errors, "missing_inventory_item", "success_check.item", "Inventory checks need an item id.")
		if not success_check.has("min_delta"):
			_add_issue(errors, "missing_inventory_delta", "success_check.min_delta", "Inventory checks need a minimum delta.")


func _validate_failure_handling(spec: Dictionary, errors: Array, warnings: Array) -> void:
	var failure_handling = spec.get("failure_handling", null)
	if typeof(failure_handling) != TYPE_DICTIONARY:
		_add_issue(errors, "missing_failure_handling", "failure_handling", "Every Forge skill needs blocked-run handling.")
		return

	if str(failure_handling.get("on_blocked", "")).strip_edges() == "":
		_add_issue(errors, "missing_blocked_action", "failure_handling.on_blocked", "Choose what happens when the run blocks.")

	var suggestion := str(failure_handling.get("suggestion", "")).strip_edges()
	if suggestion == "":
		_add_issue(errors, "missing_failure_suggestion", "failure_handling.suggestion", "Give the player a revision suggestion.")
	elif suggestion.to_lower() == "try again" or suggestion.length() < 16:
		_add_issue(warnings, "weak_failure_suggestion", "failure_handling.suggestion", "Suggestions should name what the player can revise.")


func _validate_receipt(spec: Dictionary, errors: Array, warnings: Array) -> void:
	var receipt = spec.get("receipt", null)
	var template := str(spec.get("receipt_template", "")).strip_edges()
	if typeof(receipt) != TYPE_DICTIONARY and template == "":
		_add_issue(errors, "missing_receipt", "receipt", "Runs must produce a templated receipt.")
		return

	if typeof(receipt) == TYPE_DICTIONARY:
		var label := str(receipt.get("label", "")).strip_edges()
		template = str(receipt.get("template", template)).strip_edges()
		if label == "":
			_add_issue(warnings, "missing_receipt_label", "receipt.label", "Receipt labels help the Field Log stay readable.")
		elif label.length() < 4:
			_add_issue(warnings, "vague_receipt_label", "receipt.label", "Receipt labels should describe the run result.")
	if template == "":
		_add_issue(errors, "missing_receipt", "receipt.template", "Runs must produce a templated receipt.")


func _build_drift_state(errors: Array, warnings: Array) -> Dictionary:
	var points := (errors.size() * 3) + warnings.size()
	var level := "steady"
	var face_hint := "focused"
	var observer_hint := "calm"
	if not errors.is_empty():
		level = "hallucinating"
		face_hint = "glitched"
		observer_hint = "crew_worried"
	elif not warnings.is_empty():
		level = "wobbly"
		face_hint = "sweating"
		observer_hint = "crew_noticing"

	return {
		"level": level,
		"points": points,
		"face_hint": face_hint,
		"observer_hint": observer_hint
	}


func _add_issue(issues: Array, code: String, field: String, message: String) -> void:
	issues.append({
		"code": code,
		"field": field,
		"message": message
	})


func _is_snake_case(value: String) -> bool:
	if value == "":
		return false
	if value.begins_with("_") or value.ends_with("_") or value.contains("__"):
		return false
	for index in range(value.length()):
		var character := value.substr(index, 1)
		if character == "_":
			continue
		if character >= "a" and character <= "z":
			continue
		if character >= "0" and character <= "9":
			continue
		return false
	return true
