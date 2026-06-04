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
	var success_check: Dictionary = spec.get("success_check", {})
	var tools: Array = spec.get("tools", [])
	var steps: Array = spec.get("steps", [])
	return {
		"id": spec.get("id", ""),
		"name": spec.get("name", ""),
		"summary": spec.get("summary", ""),
		"lesson": spec.get("lesson", ""),
		"context": str(spec.get("context", {}).get("target", "")),
		"tools": tools.duplicate(),
		"step_count": steps.size(),
		"success_check": success_check.get("type", ""),
		"receipt_label": spec.get("receipt", {}).get("label", "")
	}


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
