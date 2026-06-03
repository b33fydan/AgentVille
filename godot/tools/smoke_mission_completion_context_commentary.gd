extends SceneTree

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_completed_mission_uses_source_context_in_commentary()
	if not _failed:
		quit()


func _test_completed_mission_uses_source_context_in_commentary() -> void:
	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var grid = scene.get_node("FarmWorld/GridManager")
	var first_target := Vector2i(1, 1)
	var second_target := Vector2i(2, 1)
	if not _prepare_brush_tile(grid, first_target) or not _prepare_brush_tile(grid, second_target):
		_fail("Mission commentary setup could not prepare brush targets.")
		return

	var mission_id := str(scene.call("_create_crew_mission", {
		"label": "Chuck Cleanup Sprint",
		"preference_source": "ignored_ask",
		"preference_label": "Rush Kit",
		"steps": [
			{
				"kind": "clear_brush",
				"required_action": "clear_brush",
				"amount": 1,
				"label": "Clear Pressure Patch",
				"target_tile": first_target
			},
			{
				"kind": "clear_brush",
				"required_action": "clear_brush",
				"amount": 1,
				"label": "Clear Follow-up Patch",
				"target_tile": second_target
			}
		]
	}, {
		"agent_id": "chuck",
		"agent_name": "Chuck"
	}))
	if mission_id == "":
		_fail("Mission commentary setup did not create a mission.")
		return

	var first_demand := _latest_open_mission_demand(scene, mission_id)
	if first_demand.is_empty():
		_fail("Mission commentary setup did not open the first step.")
		return
	_complete_brush_step(scene, grid, first_demand)
	await process_frame
	await process_frame

	var second_demand := _latest_open_mission_demand(scene, mission_id)
	if second_demand.is_empty():
		_fail("Mission commentary setup did not open the second step.")
		return
	_complete_brush_step(scene, grid, second_demand)
	await process_frame
	await process_frame

	var mission: Dictionary = scene.crew_missions.get(mission_id, {})
	if str(mission.get("status", "")) != "done":
		_fail("Mission commentary setup did not complete the mission.")
		return

	var log_entries: Array = scene.game_ui.get("_field_log_entries")
	if not _strings_contain(log_entries, "Pressure: Rush Kit"):
		_fail("Mission completion Field Log did not include readable source context. saw=%s" % str(log_entries))
		return
	if _strings_contain(log_entries, "ignored_ask"):
		_fail("Mission completion Field Log leaked raw source context. saw=%s" % str(log_entries))
		return

	var summary: Dictionary = scene.get_node("GameEventLog").call("build_day_summary", grid.day)
	var formatted_summary := str(scene.call("_format_day_summary", summary))
	if not formatted_summary.contains("Pressure: Rush Kit") or formatted_summary.contains("ignored_ask"):
		_fail("Formatted day summary did not use readable mission source context. saw=%s" % formatted_summary)
		return

	var vibe: Dictionary = summary.get("vibe", {})
	if not _strings_contain(vibe.get("reasons", []), "Pressure: Rush Kit"):
		_fail("Vibe reasons did not include completed mission source context. saw=%s" % str(vibe.get("reasons", [])))
		return
	if _strings_contain(vibe.get("reasons", []), "ignored_ask"):
		_fail("Vibe reasons leaked raw mission source context. saw=%s" % str(vibe.get("reasons", [])))
		return

	var agent_manager = scene.get_node("FarmWorld/AgentManager")
	var comment := str(agent_manager.call("_summary_comment", summary))
	if not comment.contains("Mission complete") or not comment.contains("Pressure: Rush Kit"):
		_fail("NPC verdict did not notice mission source context. saw=%s" % comment)
		return
	if comment.contains("ignored_ask"):
		_fail("NPC verdict leaked raw mission source context. saw=%s" % comment)
		return

	scene.queue_free()
	await process_frame


func _prepare_brush_tile(grid, target: Vector2i) -> bool:
	var tile = grid.get_tile(target)
	if tile == null:
		return false
	tile.erase()
	tile.place_item("tall_grass")
	return true


func _complete_brush_step(scene: Node, grid, demand: Dictionary) -> void:
	var target: Vector2i = demand.get("target_tile", Vector2i(-1, -1))
	grid.get_tile(target).cut_with_sickle()
	scene.call("_on_player_action_logged", {
		"actor": "player",
		"tool": "sickle",
		"action": "clear_brush",
		"grid_pos": target,
		"item_id": "sickle",
		"success": true,
		"message": "Cleared mission patch.",
		"value": 0,
		"resources": {"fiber": 2},
		"crafted_cost": {}
	})


func _latest_open_mission_demand(scene: Node, mission_id: String) -> Dictionary:
	var demand_ids: Array = scene.get("crafting_demand_ids")
	var demands: Dictionary = scene.get("crafting_demands")
	for index in range(demand_ids.size() - 1, -1, -1):
		var demand_id := str(demand_ids[index])
		var demand: Dictionary = demands.get(demand_id, {})
		if str(demand.get("status", "")) == "open" and str(demand.get("mission_id", "")) == mission_id:
			return demand
	return {}


func _strings_contain(values, needle: String) -> bool:
	if typeof(values) != TYPE_ARRAY:
		return false
	for value in values:
		if str(value).contains(needle):
			return true
	return false


func _fail(message: String) -> void:
	_failed = true
	push_error(message)
	quit(1)
