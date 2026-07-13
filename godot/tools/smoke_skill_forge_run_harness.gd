extends SceneTree

const GameEventLogScript := preload("res://scripts/ai/GameEventLog.gd")
const SkillForgeRunHarnessScript := preload("res://scripts/systems/SkillForgeRunHarness.gd")
const SkillForgeTemplateLibraryScript := preload("res://scripts/systems/SkillForgeTemplateLibrary.gd")

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_clear_patch_builds_work_order_directive()
	_test_harvest_crops_builds_work_order_directive()
	_test_build_fence_builds_work_order_directive()
	_test_plant_seed_builds_work_order_directive()
	_test_tend_crops_builds_work_order_directive()
	_test_invalid_spec_blocks_with_drift_receipt()
	_test_runtime_guard_block_receipt()
	_test_pass_and_fail_completion_receipts()
	if not _failed:
		quit()


func _test_clear_patch_builds_work_order_directive() -> void:
	var library = SkillForgeTemplateLibraryScript.new()
	var harness = SkillForgeRunHarnessScript.new()
	var result: Dictionary = harness.start_manual_run(library.get_template_spec("clear_patch_starter"), {
		"agent_id": "chuck",
		"agent_name": "Chuck",
		"target_tile": Vector2i(2, 3),
		"day": 5,
		"source_context": {
			"source": "completed_mission",
			"label": "Cleanup Sprint",
			"origin_source": "ignored_ask",
			"origin_label": "Rush Kit"
		}
	})

	if str(result.get("status", "")) != "started":
		_fail("Clear Patch run did not start. result=%s" % str(result))
		return
	var directive: Dictionary = result.get("directive", {})
	if str(directive.get("kind", "")) != "work_order_directive":
		_fail("Clear Patch did not build a work-order-shaped directive. result=%s" % str(result))
		return
	if str(directive.get("action", "")) != "clear_brush" or str(directive.get("agent_action", "")) != "clear_brush":
		_fail("Clear Patch directive did not map to clear_brush. directive=%s" % str(directive))
		return
	if directive.get("target_tile", Vector2i.ZERO) != Vector2i(2, 3):
		_fail("Clear Patch directive did not preserve selected tile. directive=%s" % str(directive))
		return
	if str(directive.get("source_context", {}).get("label", "")) != "Cleanup Sprint":
		_fail("Clear Patch directive did not preserve source context. directive=%s" % str(directive))
		return
	if not _field_log_contains(result, "Skill Forge started Clear Patch for Chuck at 2,3"):
		_fail("Clear Patch start line was not field-log ready. result=%s" % str(result))
		return
	if not _event_exists(result, "skill_forge_run", "started"):
		_fail("Clear Patch run did not create a start event. result=%s" % str(result))
		return


func _test_harvest_crops_builds_work_order_directive() -> void:
	var library = SkillForgeTemplateLibraryScript.new()
	var harness = SkillForgeRunHarnessScript.new()
	var result: Dictionary = harness.start_manual_run(library.get_template_spec("harvest_crops_starter"), {
		"agent_id": "bert",
		"agent_name": "Bert",
		"target_tile": Vector2i(1, 6),
		"day": 6,
		"source_context": {
			"source": "completed_order",
			"label": "Ready Crop"
		}
	})

	if str(result.get("status", "")) != "started":
		_fail("Harvest Crops run did not start. result=%s" % str(result))
		return
	var directive: Dictionary = result.get("directive", {})
	if str(directive.get("kind", "")) != "work_order_directive":
		_fail("Harvest Crops did not build a work-order-shaped directive. result=%s" % str(result))
		return
	if str(directive.get("action", "")) != "harvest_crop" or str(directive.get("agent_action", "")) != "harvest_crop":
		_fail("Harvest Crops directive did not map to harvest_crop. directive=%s" % str(directive))
		return
	if directive.get("target_tile", Vector2i.ZERO) != Vector2i(1, 6):
		_fail("Harvest Crops directive did not preserve selected tile. directive=%s" % str(directive))
		return
	if str(result.get("run", {}).get("success_check_type", "")) != "inventory_delta":
		_fail("Harvest Crops did not preserve the inventory success check. result=%s" % str(result))
		return
	if not _field_log_contains(result, "Skill Forge started Harvest Crops for Bert at 1,6"):
		_fail("Harvest Crops start line was not field-log ready. result=%s" % str(result))
		return
	if not _event_exists(result, "skill_forge_run", "started"):
		_fail("Harvest Crops run did not create a start event. result=%s" % str(result))
		return


func _test_build_fence_builds_work_order_directive() -> void:
	var library = SkillForgeTemplateLibraryScript.new()
	var harness = SkillForgeRunHarnessScript.new()
	var result: Dictionary = harness.start_manual_run(library.get_template_spec("build_fence_starter"), {
		"agent_id": "bert",
		"agent_name": "Bert",
		"target_tile": Vector2i(4, 5),
		"day": 6,
		"source_context": {
			"source": "truce",
			"label": "Fence Request"
		}
	})

	if str(result.get("status", "")) != "started":
		_fail("Build Fence run did not start. result=%s" % str(result))
		return
	var directive: Dictionary = result.get("directive", {})
	if str(directive.get("kind", "")) != "work_order_directive":
		_fail("Build Fence did not build a work-order-shaped directive. result=%s" % str(result))
		return
	if str(directive.get("action", "")) != "build_fence" or str(directive.get("agent_action", "")) != "build_fence_order":
		_fail("Build Fence directive did not map to build_fence_order. directive=%s" % str(directive))
		return
	if str(directive.get("required_item", "")) != "fence_kit":
		_fail("Build Fence directive did not keep its Fence Kit requirement. directive=%s" % str(directive))
		return
	if directive.get("target_tile", Vector2i.ZERO) != Vector2i(4, 5):
		_fail("Build Fence directive did not preserve selected tile. directive=%s" % str(directive))
		return
	if str(result.get("run", {}).get("success_check_type", "")) != "tile_state":
		_fail("Build Fence did not preserve the tile-state success check. result=%s" % str(result))
		return
	if not _field_log_contains(result, "Skill Forge started Build Fence for Bert at 4,5"):
		_fail("Build Fence start line was not field-log ready. result=%s" % str(result))
		return
	if not _event_exists(result, "skill_forge_run", "started"):
		_fail("Build Fence run did not create a start event. result=%s" % str(result))
		return


func _test_tend_crops_builds_work_order_directive() -> void:
	var library = SkillForgeTemplateLibraryScript.new()
	var harness = SkillForgeRunHarnessScript.new()
	var result: Dictionary = harness.start_manual_run(library.get_template_spec("tend_crops_starter"), {
		"agent_id": "marigold",
		"agent_name": "Marigold",
		"target_tile": [1, 5],
		"day": 6
	})

	if str(result.get("status", "")) != "started":
		_fail("Tend Crops run did not start. result=%s" % str(result))
		return
	var directive: Dictionary = result.get("directive", {})
	if str(directive.get("kind", "")) != "work_order_directive":
		_fail("Tend Crops did not build a work-order-shaped directive. directive=%s" % str(directive))
		return
	if str(directive.get("action", "")) != "tend_crop" or str(directive.get("agent_action", "")) != "tend_crop":
		_fail("Tend Crops directive did not map to tend_crop crew work. directive=%s" % str(directive))
		return
	if directive.get("target_tile", Vector2i.ZERO) != Vector2i(1, 5):
		_fail("Tend Crops did not parse array target context. directive=%s" % str(directive))
		return
	if str(result.get("run", {}).get("success_check_type", "")) != "crop_state":
		_fail("Tend Crops did not preserve the crop-state success check. result=%s" % str(result))
		return
	if str(result.get("run", {}).get("drift", {}).get("level", "")) != "steady":
		_fail("Tend Crops did not start steady. result=%s" % str(result))
		return


func _test_plant_seed_builds_work_order_directive() -> void:
	var library = SkillForgeTemplateLibraryScript.new()
	var harness = SkillForgeRunHarnessScript.new()
	var result: Dictionary = harness.start_manual_run(library.get_template_spec("plant_seed_starter"), {
		"agent_id": "marigold",
		"agent_name": "Marigold",
		"target_tile": Vector2i(2, 4),
		"day": 6
	})

	if str(result.get("status", "")) != "started":
		_fail("Plant Seed run did not start. result=%s" % str(result))
		return
	var directive: Dictionary = result.get("directive", {})
	if str(directive.get("kind", "")) != "work_order_directive":
		_fail("Plant Seed did not build a work-order-shaped directive. directive=%s" % str(directive))
		return
	if str(directive.get("action", "")) != "plant_seed" or str(directive.get("agent_action", "")) != "plant_seed":
		_fail("Plant Seed directive did not map to plant_seed crew work. directive=%s" % str(directive))
		return
	if directive.get("target_tile", Vector2i.ZERO) != Vector2i(2, 4):
		_fail("Plant Seed did not preserve selected tile context. directive=%s" % str(directive))
		return
	if str(result.get("run", {}).get("success_check_type", "")) != "crop_state":
		_fail("Plant Seed did not preserve the crop-state success check. result=%s" % str(result))
		return
	if str(result.get("run", {}).get("drift", {}).get("level", "")) != "steady":
		_fail("Plant Seed did not start steady. result=%s" % str(result))
		return
	if not _field_log_contains(result, "Skill Forge started Plant Seed for Marigold at 2,4"):
		_fail("Plant Seed start line was not field-log ready. result=%s" % str(result))
		return
	if not _event_exists(result, "skill_forge_run", "started"):
		_fail("Plant Seed run did not create a start event. result=%s" % str(result))
		return


func _test_invalid_spec_blocks_with_drift_receipt() -> void:
	var library = SkillForgeTemplateLibraryScript.new()
	var harness = SkillForgeRunHarnessScript.new()
	var spec: Dictionary = library.get_template_spec("clear_patch_starter")
	spec["tools"] = ["inspect_tile", "summon_rain"]
	spec["steps"][1]["tool"] = "summon_rain"
	var result: Dictionary = harness.start_manual_run(spec, {
		"agent_name": "Bert",
		"target_tile": {"x": 4, "y": 1},
		"day": 7
	})

	if str(result.get("status", "")) != "blocked":
		_fail("Invalid spec did not block. result=%s" % str(result))
		return
	if not result.get("directive", {}).is_empty():
		_fail("Blocked run still produced a directive. result=%s" % str(result))
		return
	if str(result.get("run", {}).get("drift", {}).get("level", "")) != "hallucinating":
		_fail("Blocked run did not expose hallucinating drift. result=%s" % str(result))
		return
	if not _field_log_contains(result, "Skill Forge blocked Clear Patch"):
		_fail("Blocked run did not create readable Field Log copy. result=%s" % str(result))
		return
	if not _event_exists(result, "skill_forge_run", "blocked"):
		_fail("Blocked run did not create a blocked event. result=%s" % str(result))
		return


func _test_pass_and_fail_completion_receipts() -> void:
	var library = SkillForgeTemplateLibraryScript.new()
	var harness = SkillForgeRunHarnessScript.new()
	var start: Dictionary = harness.start_manual_run(library.get_template_spec("clear_patch_starter"), {
		"agent_name": "Chuck",
		"target_tile": Vector2i(0, 1),
		"day": 8
	})
	var passed: Dictionary = harness.complete_run(start, true, {
		"result_detail": "brush cleared"
	})
	if str(passed.get("status", "")) != "passed":
		_fail("Pass completion did not mark passed. result=%s" % str(passed))
		return
	if not _field_log_contains(passed, "Skill Forge passed Clear Patch"):
		_fail("Pass completion did not create readable Field Log copy. result=%s" % str(passed))
		return
	if not _event_exists(passed, "skill_forge_run", "passed"):
		_fail("Pass completion did not create a passed event. result=%s" % str(passed))
		return

	var failed: Dictionary = harness.complete_run(start, false, {
		"result_detail": "selected tile had no brush"
	})
	if str(failed.get("status", "")) != "failed":
		_fail("Fail completion did not mark failed. result=%s" % str(failed))
		return
	if not _field_log_contains(failed, "Pick a brush tile or revise the condition"):
		_fail("Fail completion did not include revision suggestion. result=%s" % str(failed))
		return

	var log := Node.new()
	log.set_script(GameEventLogScript)
	root.add_child(log)
	for entry in start.get("event_log_entries", []):
		log.call("record_event", str(entry.get("type", "")), entry.get("payload", {}))
	for entry in passed.get("event_log_entries", []):
		log.call("record_event", str(entry.get("type", "")), entry.get("payload", {}))
	var recent_events: Array = log.call("get_recent_events", 4)
	if recent_events.size() != 2:
		_fail("Forge run events were not recordable in GameEventLog. events=%s" % str(recent_events))
		return
	if str(recent_events[0].get("type", "")) != "skill_forge_run" or str(recent_events[1].get("status", "")) != "passed":
		_fail("Forge run events did not preserve type/status. events=%s" % str(recent_events))
		return


func _test_runtime_guard_block_receipt() -> void:
	var library = SkillForgeTemplateLibraryScript.new()
	var harness = SkillForgeRunHarnessScript.new()
	var start: Dictionary = harness.start_manual_run(library.get_template_spec("harvest_crops_starter"), {
		"agent_name": "Marigold",
		"target_tile": Vector2i(4, 2),
		"day": 9
	})
	var blocked: Dictionary = harness.block_run(start, {
		"result_detail": "Guard crop.ready blocked at tile (4,2): expected a ready crop, observed an empty tile.",
		"day": 10
	})
	if str(blocked.get("status", "")) != "blocked":
		_fail("Runtime guard result did not mark blocked. result=%s" % str(blocked))
		return
	if int(blocked.get("run", {}).get("day", 0)) != 10:
		_fail("Runtime guard result did not preserve completion day. result=%s" % str(blocked))
		return
	if not _field_log_contains(blocked, "Guard crop.ready blocked at tile (4,2)"):
		_fail("Runtime guard result did not expose the observed reason. result=%s" % str(blocked))
		return
	if not _event_exists(blocked, "skill_forge_run", "blocked"):
		_fail("Runtime guard result did not emit blocked event. result=%s" % str(blocked))
		return


func _field_log_contains(result: Dictionary, needle: String) -> bool:
	for line in result.get("field_log_lines", []):
		if str(line).contains(needle):
			return true
	return false


func _event_exists(result: Dictionary, event_type: String, status: String) -> bool:
	for entry in result.get("event_log_entries", []):
		if str(entry.get("type", "")) != event_type:
			continue
		var payload: Dictionary = entry.get("payload", {})
		if str(payload.get("status", "")) == status:
			return true
	return false


func _fail(message: String) -> void:
	_failed = true
	push_error(message)
	quit(1)
