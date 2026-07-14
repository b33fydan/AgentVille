class_name SkillTriggerScheduler
extends RefCounted


const SUPPORTED_TRIGGER := "day_start"

var _armed: Dictionary = {}
var _next_arm_number: int = 1


func has_armed() -> bool:
	return not _armed.is_empty()


func snapshot() -> Dictionary:
	return _armed.duplicate(true)


func arm(
	spec: Dictionary,
	request: Dictionary,
	source,
	source_map: Dictionary,
	current_day: int
) -> Dictionary:
	var trigger_type := str(spec.get("trigger", {}).get("type", "manual")).strip_edges()
	if trigger_type != SUPPORTED_TRIGGER:
		return {
			"status": "rejected",
			"armed": has_armed(),
			"replaced": false,
			"reason": "unsupported_trigger",
			"trigger_type": trigger_type,
			"arm": snapshot(),
			"previous_arm": {}
		}

	var previous_arm := snapshot()
	var arm_id := "day_start_arm_%03d" % _next_arm_number
	_next_arm_number += 1
	_armed = {
		"id": arm_id,
		"trigger_type": SUPPORTED_TRIGGER,
		"armed_day": current_day,
		"spec": spec.duplicate(true),
		"request": request.duplicate(true),
		"source": _copy_variant(source),
		"source_map": source_map.duplicate(true)
	}

	var replaced := not previous_arm.is_empty()
	return {
		"status": "replaced" if replaced else "armed",
		"armed": true,
		"replaced": replaced,
		"arm": snapshot(),
		"previous_arm": previous_arm
	}


func disarm(reason: String = "player") -> Dictionary:
	var normalized_reason := reason.strip_edges()
	if normalized_reason == "":
		normalized_reason = "player"
	var previous_arm := snapshot()
	if previous_arm.is_empty():
		return {
			"status": "idle",
			"disarmed": false,
			"reason": normalized_reason,
			"arm": {}
		}

	_armed.clear()
	return {
		"status": "disarmed",
		"disarmed": true,
		"reason": normalized_reason,
		"arm": previous_arm
	}


func consume_day_start(current_day: int) -> Dictionary:
	if _armed.is_empty():
		return {
			"status": "idle",
			"fired": false,
			"consumed": false,
			"current_day": current_day,
			"arm": {}
		}

	var armed_day := int(_armed.get("armed_day", current_day))
	if current_day <= armed_day:
		return {
			"status": "waiting",
			"fired": false,
			"consumed": false,
			"current_day": current_day,
			"arm": snapshot()
		}

	var consumed_arm := snapshot()
	_armed.clear()
	return {
		"status": "fired",
		"fired": true,
		"consumed": true,
		"current_day": current_day,
		"arm": consumed_arm
	}


func _copy_variant(value):
	if typeof(value) == TYPE_DICTIONARY or typeof(value) == TYPE_ARRAY:
		return value.duplicate(true)
	return value
