extends SceneTree

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_source_backed_mission_momentum_keeps_origin_context()
	if not _failed:
		quit()


func _test_source_backed_mission_momentum_keeps_origin_context() -> void:
	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var grid = scene.get_node("FarmWorld/GridManager")
	var first_target := Vector2i(1, 1)
	var second_target := Vector2i(2, 1)
	if not _prepare_brush_tile(grid, first_target) or not _prepare_brush_tile(grid, second_target):
		_fail("Mission momentum source setup could not prepare brush targets.")
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
		_fail("Mission momentum source setup did not create a source-backed mission.")
		return

	var first_demand := _latest_open_mission_demand(scene, mission_id)
	if first_demand.is_empty():
		_fail("Mission momentum source setup did not open the first step.")
		return
	_complete_brush_step(scene, grid, first_demand)
	await process_frame
	await process_frame

	var second_demand := _latest_open_mission_demand(scene, mission_id)
	if second_demand.is_empty():
		_fail("Mission momentum source setup did not open the second step.")
		return
	_complete_brush_step(scene, grid, second_demand)
	await process_frame
	await process_frame

	var mission: Dictionary = scene.crew_missions.get(mission_id, {})
	if str(mission.get("status", "")) != "done":
		_fail("Mission momentum source setup did not complete the mission.")
		return

	scene.call("_on_advance_day_requested")
	await process_frame
	await process_frame

	var agent_manager = scene.get_node("FarmWorld/AgentManager")
	var snapshot := _agent_snapshot(agent_manager, "chuck")
	if str(snapshot.get("memory_consequence_source", "")) != "completed_mission":
		_fail("Completed mission did not create next-day mission momentum.")
		return
	if str(snapshot.get("memory_consequence_label", "")) != "Chuck Cleanup Sprint":
		_fail("Mission momentum did not preserve the completed mission label.")
		return
	if str(snapshot.get("memory_consequence_origin_source", "")) != "ignored_ask":
		_fail("Mission momentum did not preserve the original pressure source. saw=%s" % str(snapshot))
		return
	if str(snapshot.get("memory_consequence_origin_label", "")) != "Rush Kit":
		_fail("Mission momentum did not preserve the original Rush Kit label.")
		return

	var social_label := _crew_social_label(scene, "chuck")
	if social_label == null or not social_label.visible:
		_fail("Crew row did not expose Chuck's next-day mission momentum plan.")
		return
	if not str(social_label.text).contains("Mission momentum: Chuck Cleanup Sprint"):
		_fail("Crew row did not name the mission momentum plan. saw=%s" % str(social_label.text))
		return
	if not str(social_label.text).contains("Pressure: Rush Kit"):
		_fail("Crew row did not include the original pressure context. saw=%s" % str(social_label.text))
		return
	if str(social_label.text).contains("ignored_ask"):
		_fail("Crew row leaked raw mission origin source. saw=%s" % str(social_label.text))
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


func _agent_snapshot(agent_manager, agent_id: String) -> Dictionary:
	for snapshot in agent_manager.call("get_agent_snapshots"):
		if typeof(snapshot) == TYPE_DICTIONARY and str(snapshot.get("id", "")) == agent_id:
			return snapshot
	return {}


func _crew_social_label(scene: Node, agent_id: String) -> Label:
	var game_ui = scene.get("game_ui")
	var rows: Dictionary = game_ui.get("_crew_rows")
	if not rows.has(agent_id):
		return null
	var row: Dictionary = rows[agent_id]
	return row.get("social", null) as Label


func _fail(message: String) -> void:
	_failed = true
	push_error(message)
	quit(1)
