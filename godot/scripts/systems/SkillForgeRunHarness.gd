class_name SkillForgeRunHarness
extends RefCounted

const SkillSpecValidatorScript := preload("res://scripts/systems/SkillSpecValidator.gd")

const CURRENT_WORK_ORDER_ACTIONS := {
	"clear_brush": {
		"agent_action": "clear_brush",
		"required_item": ""
	},
	"harvest_crop": {
		"agent_action": "harvest_crop",
		"required_item": ""
	},
	"plant_seed": {
		"agent_action": "plant_seed",
		"required_item": ""
	},
	"tend_crop": {
		"agent_action": "tend_crop",
		"required_item": ""
	},
	"build_fence": {
		"agent_action": "build_fence_order",
		"required_item": "fence_kit"
	}
}

var _validator = SkillSpecValidatorScript.new()
var _next_run_number: int = 1


func start_manual_run(spec: Dictionary, request: Dictionary = {}) -> Dictionary:
	var validation: Dictionary = _validator.validate(spec)
	var normalized: Dictionary = validation.get("normalized", spec)
	var run := _base_run(normalized, validation, request)
	if not bool(validation.get("valid", false)):
		run["status"] = "blocked"
		return _result_from_run(run, {}, "blocked", _blocked_field_log_line(run, validation), validation)

	var directive := _build_directive(run, normalized, request)
	run["status"] = "started"
	run["directive_id"] = str(directive.get("id", ""))
	run["directive_kind"] = str(directive.get("kind", ""))
	run["action"] = str(directive.get("action", ""))
	return _result_from_run(run, directive, "started", _start_field_log_line(run, directive), validation)


func complete_run(start_result: Dictionary, passed: bool, details: Dictionary = {}) -> Dictionary:
	var run: Dictionary = start_result.get("run", start_result).duplicate(true)
	var status_text := "passed" if passed else "failed"
	run["status"] = status_text
	if details.has("day"):
		run["day"] = int(details.get("day", run.get("day", 1)))
	run["result_detail"] = str(details.get("result_detail", "pass/fail recorded")).strip_edges()
	if run["result_detail"] == "":
		run["result_detail"] = "pass/fail recorded"
	var drift_override := str(details.get("drift_level", "")).strip_edges()
	if drift_override != "":
		var drift: Dictionary = run.get("drift", {})
		drift["level"] = drift_override
		run["drift"] = drift

	var directive: Dictionary = start_result.get("directive", {})
	return _result_from_run(run, directive, status_text, _completion_field_log_line(run, passed), start_result.get("validation", {}))


func block_run(start_result: Dictionary, details: Dictionary = {}) -> Dictionary:
	var run: Dictionary = start_result.get("run", start_result).duplicate(true)
	run["status"] = "blocked"
	if details.has("day"):
		run["day"] = int(details.get("day", run.get("day", 1)))
	run["result_detail"] = str(details.get("result_detail", "runtime guard blocked the run")).strip_edges()
	if run["result_detail"] == "":
		run["result_detail"] = "runtime guard blocked the run"
	var drift: Dictionary = run.get("drift", {})
	drift["level"] = str(details.get("drift_level", "steady"))
	run["drift"] = drift
	var directive: Dictionary = start_result.get("directive", {})
	return _result_from_run(run, directive, "blocked", _runtime_blocked_field_log_line(run), start_result.get("validation", {}))


func _base_run(spec: Dictionary, validation: Dictionary, request: Dictionary) -> Dictionary:
	var run_id := str(request.get("run_id", "")).strip_edges()
	if run_id == "":
		run_id = "forge_run_%03d" % _next_run_number
		_next_run_number += 1

	var target_tile := _target_tile_from_value(request.get("target_tile", Vector2i(-1, -1)))
	var source_context = request.get("source_context", {})
	if typeof(source_context) != TYPE_DICTIONARY:
		source_context = {}

	var receipt: Dictionary = spec.get("receipt", {})
	var success_check: Dictionary = spec.get("success_check", {})
	var failure_handling: Dictionary = spec.get("failure_handling", {})
	return {
		"id": run_id,
		"skill_id": str(spec.get("id", "")).strip_edges(),
		"skill_name": str(spec.get("name", "Skill Run")).strip_edges(),
		"agent_id": str(request.get("agent_id", "")).strip_edges(),
		"agent_name": str(request.get("agent_name", "Crew")).strip_edges(),
		"target_tile": target_tile,
		"day": int(request.get("day", 1)),
		"trigger_type": str(spec.get("trigger", {}).get("type", "manual")),
		"tools": _string_array(spec.get("tools", [])),
		"step_count": spec.get("steps", []).size() if typeof(spec.get("steps", [])) == TYPE_ARRAY else 0,
		"success_check_type": str(success_check.get("type", "")),
		"failure_suggestion": str(failure_handling.get("suggestion", "")).strip_edges(),
		"receipt_label": str(receipt.get("label", spec.get("name", "Skill Run"))).strip_edges(),
		"receipt_template": str(receipt.get("template", validation.get("normalized", {}).get("receipt_template", ""))).strip_edges(),
		"source_context": source_context.duplicate(true),
		"drift": validation.get("drift", {}).duplicate(true)
	}


func _build_directive(run: Dictionary, spec: Dictionary, request: Dictionary) -> Dictionary:
	var action := _primary_action(spec)
	var target_tile: Vector2i = run.get("target_tile", Vector2i(-1, -1))
	var is_work_order_action := CURRENT_WORK_ORDER_ACTIONS.has(action)
	var action_config: Dictionary = CURRENT_WORK_ORDER_ACTIONS.get(action, {})
	var directive := {
		"id": "%s_directive" % str(run.get("id", "forge_run")),
		"label": "%s %s" % [str(run.get("skill_name", "Skill Run")), _format_tile(target_tile)],
		"status": "ready",
		"kind": "work_order_directive" if is_work_order_action else "skill_directive",
		"source": "skill_forge",
		"action": action,
		"agent_action": str(action_config.get("agent_action", action)),
		"target_tile": target_tile,
		"required_item": str(action_config.get("required_item", "")),
		"created_day": int(run.get("day", 1)),
		"forge_run_id": str(run.get("id", "")),
		"skill_id": str(run.get("skill_id", "")),
		"skill_name": str(run.get("skill_name", "")),
		"agent_id": str(run.get("agent_id", "")),
		"agent_name": str(run.get("agent_name", "Crew")),
		"steps": spec.get("steps", []).duplicate(true) if typeof(spec.get("steps", [])) == TYPE_ARRAY else [],
		"success_check": spec.get("success_check", {}).duplicate(true),
		"failure_handling": spec.get("failure_handling", {}).duplicate(true),
		"receipt": spec.get("receipt", {}).duplicate(true),
		"source_context": run.get("source_context", {}).duplicate(true)
	}
	if request.has("priority"):
		directive["priority"] = request.get("priority")
	return directive


func _result_from_run(run: Dictionary, directive: Dictionary, status_text: String, field_log_line: String, validation: Dictionary) -> Dictionary:
	return {
		"status": status_text,
		"can_run": status_text == "started",
		"run": run,
		"directive": directive,
		"validation": validation,
		"field_log_lines": [field_log_line],
		"event_log_entries": [
			{
				"type": "skill_forge_run",
				"payload": _event_payload(run, status_text)
			}
		]
	}


func _event_payload(run: Dictionary, status_text: String) -> Dictionary:
	var payload := {
		"day": int(run.get("day", 1)),
		"run_id": str(run.get("id", "")),
		"skill_id": str(run.get("skill_id", "")),
		"skill_name": str(run.get("skill_name", "")),
		"status": status_text,
		"agent_id": str(run.get("agent_id", "")),
		"agent_name": str(run.get("agent_name", "Crew")),
		"target_tile": run.get("target_tile", Vector2i(-1, -1)),
		"trigger_type": str(run.get("trigger_type", "manual")),
		"action": str(run.get("action", "")),
		"directive_id": str(run.get("directive_id", "")),
		"directive_kind": str(run.get("directive_kind", "")),
		"success_check_type": str(run.get("success_check_type", "")),
		"receipt_label": str(run.get("receipt_label", "")),
		"result_detail": str(run.get("result_detail", "")),
		"failure_suggestion": str(run.get("failure_suggestion", "")),
		"drift_level": str(run.get("drift", {}).get("level", "steady")),
		"source_context": run.get("source_context", {}).duplicate(true)
	}
	return payload


func _primary_action(spec: Dictionary) -> String:
	var steps = spec.get("steps", [])
	if typeof(steps) == TYPE_ARRAY:
		for index in range(steps.size() - 1, -1, -1):
			var step = steps[index]
			if typeof(step) != TYPE_DICTIONARY:
				continue
			var tool := str(step.get("tool", "")).strip_edges()
			if tool != "" and tool != "inspect_tile":
				return tool
	var tools = spec.get("tools", [])
	if typeof(tools) == TYPE_ARRAY and not tools.is_empty():
		return str(tools[0]).strip_edges()
	return "skill_run"


func _start_field_log_line(run: Dictionary, directive: Dictionary) -> String:
	var source_detail := _format_source_context(run.get("source_context", {}))
	if source_detail != "":
		source_detail = " [%s]" % source_detail
	return "Skill Forge started %s for %s at %s%s." % [
		str(run.get("skill_name", "Skill Run")),
		str(run.get("agent_name", "Crew")),
		_format_tile(run.get("target_tile", Vector2i(-1, -1))),
		source_detail
	]


func _blocked_field_log_line(run: Dictionary, validation: Dictionary) -> String:
	var error_text := _first_issue_message(validation.get("errors", []))
	var suggestion := str(run.get("failure_suggestion", "")).strip_edges()
	if suggestion == "":
		suggestion = "Revise the spec and try again."
	return "Skill Forge blocked %s for %s: %s Hallucination Drift: %s. %s" % [
		str(run.get("skill_name", "Skill Run")),
		str(run.get("agent_name", "Crew")),
		error_text,
		str(run.get("drift", {}).get("level", "hallucinating")),
		suggestion
	]


func _completion_field_log_line(run: Dictionary, passed: bool) -> String:
	var status_text := "passed" if passed else "failed"
	var detail := str(run.get("result_detail", "pass/fail recorded")).strip_edges()
	var line := "Skill Forge %s %s for %s at %s: %s." % [
		status_text,
		str(run.get("skill_name", "Skill Run")),
		str(run.get("agent_name", "Crew")),
		_format_tile(run.get("target_tile", Vector2i(-1, -1))),
		detail
	]
	if not passed:
		var suggestion := str(run.get("failure_suggestion", "")).strip_edges()
		if suggestion != "":
			line += " %s" % suggestion
	return line


func _runtime_blocked_field_log_line(run: Dictionary) -> String:
	var detail := str(run.get("result_detail", "runtime guard blocked the run")).strip_edges()
	var line := "Skill Forge blocked %s for %s at %s: %s" % [
		str(run.get("skill_name", "Skill Run")),
		str(run.get("agent_name", "Crew")),
		_format_tile(run.get("target_tile", Vector2i(-1, -1))),
		detail
	]
	var suggestion := str(run.get("failure_suggestion", "")).strip_edges()
	if suggestion != "":
		line += " %s" % suggestion
	return "%s." % line.trim_suffix(".")


func _first_issue_message(issues) -> String:
	if typeof(issues) == TYPE_ARRAY and not issues.is_empty():
		var first_issue = issues[0]
		if typeof(first_issue) == TYPE_DICTIONARY:
			return str(first_issue.get("message", "The spec needs revision."))
	return "The spec needs revision."


func _format_source_context(source_context) -> String:
	if typeof(source_context) != TYPE_DICTIONARY:
		return ""
	var source := str(source_context.get("source", "")).strip_edges()
	var label := str(source_context.get("label", "")).strip_edges()
	var origin_source := str(source_context.get("origin_source", "")).strip_edges()
	var origin_label := str(source_context.get("origin_label", "")).strip_edges()
	var text := ""
	if label != "":
		text = "%s: %s" % [_readable_source(source), label] if source != "" else label
	elif source != "":
		text = _readable_source(source)
	if origin_label != "":
		var origin_text := "%s: %s" % [_readable_source(origin_source), origin_label] if origin_source != "" else origin_label
		text += " from %s" % origin_text if text != "" else origin_text
	return text


func _readable_source(source: String) -> String:
	match source.strip_edges():
		"completed_mission":
			return "Momentum"
		"ignored_ask":
			return "Pressure"
		"remembered_help":
			return "Memory"
		"truce":
			return "Truce"
		"completed_order":
			return "Follow-up"
	return source.replace("_", " ").capitalize()


func _target_tile_from_value(value) -> Vector2i:
	if typeof(value) == TYPE_VECTOR2I:
		return value
	if typeof(value) == TYPE_VECTOR2:
		return Vector2i(int(value.x), int(value.y))
	if typeof(value) == TYPE_DICTIONARY:
		return Vector2i(int(value.get("x", -1)), int(value.get("y", -1)))
	if typeof(value) == TYPE_ARRAY and value.size() >= 2:
		return Vector2i(int(value[0]), int(value[1]))
	return Vector2i(-1, -1)


func _format_tile(value) -> String:
	var tile := _target_tile_from_value(value)
	return "%s,%s" % [tile.x, tile.y]


func _string_array(value) -> Array:
	var result := []
	if typeof(value) != TYPE_ARRAY:
		return result
	for item in value:
		result.append(str(item))
	return result
