extends SceneTree

const SkillSpecValidatorScript := preload("res://scripts/systems/SkillSpecValidator.gd")

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_tend_crop_spec_passes()
	_test_trigger_allowlist()
	_test_unknown_tools_are_blocked()
	_test_unknown_conditions_are_blocked()
	_test_safe_warnings_create_drift_state()
	_test_missing_receipts_are_blocked()
	if not _failed:
		quit()


func _test_tend_crop_spec_passes() -> void:
	var validator = SkillSpecValidatorScript.new()
	var result: Dictionary = validator.validate(_valid_tend_crop_spec())

	if not bool(result.get("valid", false)):
		_fail("Valid Tend Crops spec did not pass. result=%s" % str(result))
		return
	if bool(result.get("hard_blocked", true)):
		_fail("Valid Tend Crops spec was hard blocked. result=%s" % str(result))
		return
	if not _drift_level_is(result, "steady"):
		_fail("Valid Tend Crops spec did not report steady drift state. result=%s" % str(result))
		return

	var normalized: Dictionary = result.get("normalized", {})
	if str(normalized.get("receipt_template", "")) == "":
		_fail("Valid Tend Crops spec did not normalize a receipt template. result=%s" % str(result))
		return


func _test_trigger_allowlist() -> void:
	var validator = SkillSpecValidatorScript.new()
	if validator.supported_triggers() != ["manual", "day_start"]:
		_fail("Trigger allowlist drifted. triggers=%s" % str(validator.supported_triggers()))
		return

	var day_start_spec := _valid_tend_crop_spec()
	day_start_spec["trigger"] = {"type": "  day_start  "}
	var day_start_result: Dictionary = validator.validate(day_start_spec)
	if not bool(day_start_result.get("valid", false)):
		_fail("Day-start trigger did not pass validation. result=%s" % str(day_start_result))
		return
	if str(day_start_result.get("normalized", {}).get("trigger", {}).get("type", "")) != "day_start":
		_fail("Day-start trigger was not normalized. result=%s" % str(day_start_result))
		return

	var unknown_spec := _valid_tend_crop_spec()
	unknown_spec["trigger"] = {"type": "crop_ready"}
	var unknown_result: Dictionary = validator.validate(unknown_spec)
	if not bool(unknown_result.get("hard_blocked", false)) or not _issue_code_exists(unknown_result.get("errors", []), "unsupported_trigger"):
		_fail("Unknown event did not hard block at the validator. result=%s" % str(unknown_result))
		return


func _test_unknown_tools_are_blocked() -> void:
	var validator = SkillSpecValidatorScript.new()
	var spec := _valid_tend_crop_spec()
	spec["tools"] = ["inspect_tile", "summon_rain"]
	spec["steps"][1]["tool"] = "summon_rain"
	var result: Dictionary = validator.validate(spec)

	if not bool(result.get("hard_blocked", false)):
		_fail("Unknown tool did not hard block the spec. result=%s" % str(result))
		return
	if bool(result.get("can_run", true)):
		_fail("Unknown tool still allowed the spec to run. result=%s" % str(result))
		return
	if not _issue_code_exists(result.get("errors", []), "unknown_tool"):
		_fail("Unknown tool did not emit an unknown_tool error. result=%s" % str(result))
		return
	if not _drift_level_is(result, "hallucinating"):
		_fail("Unknown tool did not raise hallucination drift. result=%s" % str(result))
		return


func _test_unknown_conditions_are_blocked() -> void:
	var validator = SkillSpecValidatorScript.new()
	var spec := _valid_tend_crop_spec()
	spec["steps"][1]["when"] = "maybe_if_the_agent_feels_like_it"
	var result: Dictionary = validator.validate(spec)

	if not bool(result.get("hard_blocked", false)):
		_fail("Unknown condition did not hard block the spec. result=%s" % str(result))
		return
	if bool(result.get("can_run", true)):
		_fail("Unknown condition still allowed the spec to run. result=%s" % str(result))
		return
	if not _issue_code_exists(result.get("errors", []), "unsupported_condition"):
		_fail("Unknown condition did not emit an unsupported_condition error. result=%s" % str(result))
		return
	if not _drift_level_is(result, "hallucinating"):
		_fail("Unknown condition did not raise hallucination drift. result=%s" % str(result))
		return


func _test_safe_warnings_create_drift_state() -> void:
	var validator = SkillSpecValidatorScript.new()
	var spec := _valid_tend_crop_spec()
	spec["name"] = "Tend Every Single Crop In The Whole Farm Before Breakfast"
	spec["steps"].append({
		"id": "extra_check",
		"tool": "inspect_tile",
		"target": "context.target",
		"when": "always"
	})
	spec["failure_handling"]["suggestion"] = "try again"
	var result: Dictionary = validator.validate(spec)

	if not bool(result.get("valid", false)):
		_fail("Warning-only spec should remain runnable. result=%s" % str(result))
		return
	if not bool(result.get("can_run_with_override", false)):
		_fail("Warning-only spec did not expose override state. result=%s" % str(result))
		return
	if not _issue_code_exists(result.get("warnings", []), "long_name"):
		_fail("Long name did not emit a warning. result=%s" % str(result))
		return
	if not _issue_code_exists(result.get("warnings", []), "weak_failure_suggestion"):
		_fail("Weak failure suggestion did not emit a warning. result=%s" % str(result))
		return
	if not _drift_level_is(result, "wobbly"):
		_fail("Warning-only spec did not report wobbly drift. result=%s" % str(result))
		return


func _test_missing_receipts_are_blocked() -> void:
	var validator = SkillSpecValidatorScript.new()
	var spec := _valid_tend_crop_spec()
	spec.erase("receipt")
	spec.erase("receipt_template")
	var result: Dictionary = validator.validate(spec)

	if not bool(result.get("hard_blocked", false)):
		_fail("Missing receipt did not hard block the spec. result=%s" % str(result))
		return
	if not _issue_code_exists(result.get("errors", []), "missing_receipt"):
		_fail("Missing receipt did not emit a missing_receipt error. result=%s" % str(result))
		return


func _valid_tend_crop_spec() -> Dictionary:
	return {
		"id": "tend_crops_starter",
		"name": "Tend Crops",
		"trigger": {
			"type": "manual"
		},
		"context": {
			"target": "selected_tile",
			"include_recent_source": false
		},
		"tools": ["inspect_tile", "tend_crop"],
		"steps": [
			{
				"id": "inspect",
				"tool": "inspect_tile",
				"target": "context.target"
			},
			{
				"id": "tend",
				"tool": "tend_crop",
				"target": "context.target",
				"when": "crop.needs_tending"
			}
		],
		"success_check": {
			"type": "crop_state",
			"target": "context.target",
			"state": "tended"
		},
		"failure_handling": {
			"on_blocked": "record_receipt",
			"suggestion": "Pick a crop tile that needs tending."
		},
		"receipt": {
			"label": "Tend Crops run",
			"template": "{agent} tended {target} and checked {result}.",
			"include_source_context": false
		}
	}


func _issue_code_exists(issues, code: String) -> bool:
	if typeof(issues) != TYPE_ARRAY:
		return false
	for issue in issues:
		if typeof(issue) == TYPE_DICTIONARY and str(issue.get("code", "")) == code:
			return true
	return false


func _drift_level_is(result: Dictionary, level: String) -> bool:
	var drift = result.get("drift", {})
	if typeof(drift) != TYPE_DICTIONARY:
		return false
	return str(drift.get("level", "")) == level


func _fail(message: String) -> void:
	_failed = true
	push_error(message)
	quit(1)
