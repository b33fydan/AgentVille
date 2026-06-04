class_name SkillForgeTemplateLibrary
extends RefCounted

const TEMPLATE_IDS := ["tend_crops_starter", "clear_patch_starter"]


func get_template_ids() -> Array:
	return TEMPLATE_IDS.duplicate()


func has_template(template_id: String) -> bool:
	return TEMPLATE_IDS.has(template_id)


func get_template_spec(template_id: String) -> Dictionary:
	match template_id:
		"tend_crops_starter":
			return _tend_crops_spec()
		"clear_patch_starter":
			return _clear_patch_spec()
		_:
			return {}


func get_template_preview(template_id: String) -> Dictionary:
	var spec := get_template_spec(template_id)
	if spec.is_empty():
		return {}
	return _preview_from_spec(spec)


func list_template_previews() -> Array:
	var previews := []
	for template_id in TEMPLATE_IDS:
		previews.append(get_template_preview(template_id))
	return previews


func _preview_from_spec(spec: Dictionary) -> Dictionary:
	var context: Dictionary = spec.get("context", {})
	var success_check: Dictionary = spec.get("success_check", {})
	var receipt: Dictionary = spec.get("receipt", {})
	var tools: Array = spec.get("tools", [])
	var steps: Array = spec.get("steps", [])
	var context_target := str(context.get("target", ""))
	return {
		"id": spec.get("id", ""),
		"name": spec.get("name", ""),
		"summary": spec.get("summary", ""),
		"lesson": spec.get("lesson", ""),
		"trigger_type": str(spec.get("trigger", {}).get("type", "")),
		"context": context_target,
		"context_label": context_target,
		"tools": tools.duplicate(),
		"tools_label": _join_string_values(tools, " -> "),
		"step_count": steps.size(),
		"step_label": _step_label(steps),
		"success_check": success_check.get("type", ""),
		"check_label": _check_label(success_check),
		"receipt_label": receipt.get("label", "")
	}


func _step_label(steps: Array) -> String:
	var ids := []
	for step in steps:
		if typeof(step) != TYPE_DICTIONARY:
			continue
		var step_id := str(step.get("id", "")).strip_edges()
		if step_id != "":
			ids.append(step_id)
	if ids.is_empty():
		return ""
	return _join_string_values(ids, " -> ")


func _check_label(success_check: Dictionary) -> String:
	var check_type := str(success_check.get("type", "")).strip_edges()
	var target := str(success_check.get("target", "")).strip_edges()
	if target == "context.target":
		target = "selected_tile"
	if check_type == "":
		return ""
	if target == "":
		return check_type
	return "%s on %s" % [check_type, target]


func _join_string_values(values: Array, separator: String) -> String:
	var strings := []
	for value in values:
		var text := str(value).strip_edges()
		if text != "":
			strings.append(text)
	return separator.join(strings)


func _tend_crops_spec() -> Dictionary:
	return {
		"id": "tend_crops_starter",
		"name": "Tend Crops",
		"summary": "Teach an NPC to inspect one selected crop tile and tend it when it needs attention.",
		"lesson": "Manual trigger, selected farm context, one tool call, and a visible crop-state success check.",
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


func _clear_patch_spec() -> Dictionary:
	return {
		"id": "clear_patch_starter",
		"name": "Clear Patch",
		"summary": "Teach an NPC to inspect one selected tile, clear brush if present, and report the result.",
		"lesson": "Allowlisted tools, guarded steps, blocked-run handling, and a tile-state success check.",
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
			"label": "Clear Patch run",
			"template": "{agent} cleared {target} after checking {source_context}.",
			"include_source_context": true
		}
	}
