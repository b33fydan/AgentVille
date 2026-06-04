extends SceneTree

const GameEventLogScript := preload("res://scripts/ai/GameEventLog.gd")

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_skill_forge_runs_land_in_day_summary()
	if not _failed:
		quit()


func _test_skill_forge_runs_land_in_day_summary() -> void:
	var log := Node.new()
	log.set_script(GameEventLogScript)
	root.add_child(log)

	log.call("record_event", "skill_forge_run", {
		"day": 4,
		"run_id": "forge_run_001",
		"skill_id": "clear_patch_starter",
		"skill_name": "Clear Patch",
		"status": "started",
		"agent_id": "chuck",
		"agent_name": "Chuck",
		"target_tile": Vector2i(2, 3),
		"trigger_type": "manual",
		"action": "clear_brush",
		"success_check_type": "tile_state",
		"receipt_label": "Clear Patch run",
		"drift_level": "steady"
	})
	log.call("record_event", "skill_forge_run", {
		"day": 4,
		"run_id": "forge_run_001",
		"skill_id": "clear_patch_starter",
		"skill_name": "Clear Patch",
		"status": "passed",
		"agent_id": "chuck",
		"agent_name": "Chuck",
		"target_tile": Vector2i(2, 3),
		"trigger_type": "manual",
		"action": "clear_brush",
		"success_check_type": "tile_state",
		"receipt_label": "Clear Patch run",
		"result_detail": "brush cleared",
		"drift_level": "steady"
	})
	log.call("record_event", "skill_forge_run", {
		"day": 4,
		"run_id": "forge_run_002",
		"skill_id": "tend_crops_starter",
		"skill_name": "Tend Crops",
		"status": "blocked",
		"agent_id": "marigold",
		"agent_name": "Marigold",
		"target_tile": Vector2i(1, 4),
		"trigger_type": "manual",
		"action": "summon_rain",
		"success_check_type": "crop_state",
		"receipt_label": "Tend Crops run",
		"failure_suggestion": "Replace summon_rain with tend_crop and rerun.",
		"drift_level": "hallucinating"
	})

	var summary: Dictionary = log.call("build_day_summary", 4)
	if int(summary.get("skill_forge_run_count", 0)) != 2:
		_fail("Skill Forge day summary did not count unique runs. summary=%s" % str(summary))
		return
	if int(summary.get("completed_skill_forge_runs", 0)) != 1:
		_fail("Skill Forge day summary did not count passed runs. summary=%s" % str(summary))
		return
	if int(summary.get("blocked_skill_forge_runs", 0)) != 1:
		_fail("Skill Forge day summary did not count blocked runs. summary=%s" % str(summary))
		return

	var runs: Dictionary = summary.get("skill_forge_runs", {})
	if str(runs.get("forge_run_001", {}).get("status", "")) != "passed":
		_fail("Passed Forge run did not keep its final status. runs=%s" % str(runs))
		return
	if str(runs.get("forge_run_002", {}).get("drift_level", "")) != "hallucinating":
		_fail("Blocked Forge run did not keep hallucinating drift. runs=%s" % str(runs))
		return

	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var formatted := str(scene.call("_format_day_summary", summary))
	if not formatted.contains("forge recap"):
		_fail("Formatted day summary did not include Forge recap. saw=%s" % formatted)
		return
	if not formatted.contains("Chuck passed Clear Patch"):
		_fail("Forge recap did not name the passed run. saw=%s" % formatted)
		return
	if not formatted.contains("Marigold blocked Tend Crops"):
		_fail("Forge recap did not name the blocked run. saw=%s" % formatted)
		return
	if not formatted.contains("Drift hallucinating"):
		_fail("Forge recap did not include blocked-run drift. saw=%s" % formatted)
		return

	scene.queue_free()
	log.queue_free()
	await process_frame


func _fail(message: String) -> void:
	_failed = true
	push_error(message)
	quit(1)
