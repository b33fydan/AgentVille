extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_bert_boundary_run_tracks_and_resolves()
	await _test_chuck_cleanup_run_tracks_and_resolves()
	quit()


func _test_bert_boundary_run_tracks_and_resolves() -> void:
	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var grid = scene.get_node("FarmWorld/GridManager")
	var clear_target := Vector2i(1, 1)
	var fence_target := Vector2i(2, 1)
	var clear_tile = grid.get_tile(clear_target)
	var fence_tile = grid.get_tile(fence_target)
	if clear_tile == null or fence_tile == null:
		_fail("Boundary mission setup could not find target tiles.")
		return
	clear_tile.erase()
	clear_tile.place_item("tall_grass")
	fence_tile.erase()

	var result := _resolved_result_for("bert", "Bert", "grizzled", "boundary_run", grid.day)
	scene.call("_apply_adversarial_result", result)
	await process_frame
	await process_frame

	var mission_id := _latest_mission_id(scene)
	if mission_id == "":
		_fail("Boundary run did not start a crew mission.")
		return

	var mission: Dictionary = scene.crew_missions.get(mission_id, {})
	if str(mission.get("label", "")) != "Bert Boundary Run":
		_fail("Boundary run did not use Bert's mission label.")
		return
	if int(mission.get("total_steps", 0)) != 2:
		_fail("Boundary run did not create two mission steps.")
		return

	var first_demand := _latest_open_mission_demand(scene, mission_id)
	if first_demand.is_empty() or str(first_demand.get("kind", "")) != "clear_brush":
		_fail("Boundary run did not open with clear-brush work.")
		return
	var first_target: Vector2i = first_demand.get("target_tile", clear_target)
	grid.get_tile(first_target).cut_with_sickle()

	scene.call("_on_player_action_logged", {
		"actor": "player",
		"tool": "sickle",
		"action": "clear_brush",
		"grid_pos": first_target,
		"item_id": "sickle",
		"success": true,
		"message": "Cleared boundary brush.",
		"value": 0,
		"resources": {"fiber": 2},
		"crafted_cost": {}
	})
	await process_frame
	await process_frame

	var second_demand := _latest_open_mission_demand(scene, mission_id)
	if second_demand.is_empty() or str(second_demand.get("kind", "")) != "build_fence":
		_fail("Boundary run did not advance into fence work.")
		return
	var second_target: Vector2i = second_demand.get("target_tile", fence_target)
	var second_tile = grid.get_tile(second_target)
	if second_tile == null or not second_tile.place_item("fence"):
		_fail("Boundary run fence setup could not place a fence.")
		return

	scene.call("_on_player_action_logged", {
		"actor": "player",
		"tool": "place",
		"action": "place",
		"grid_pos": second_target,
		"item_id": "fence",
		"success": true,
		"message": "Placed boundary fence.",
		"value": 0,
		"resources": {},
		"crafted_cost": {"fence_kit": 1}
	})
	await process_frame
	await process_frame

	mission = scene.crew_missions.get(mission_id, {})
	if str(mission.get("status", "")) != "done":
		_fail("Boundary run did not resolve after fence work.")
		return
	if int(scene.resources.get("fiber", 0)) < 3:
		_fail("Boundary run did not pay its completion fiber reward.")
		return

	scene.queue_free()
	await process_frame


func _test_chuck_cleanup_run_tracks_and_resolves() -> void:
	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var grid = scene.get_node("FarmWorld/GridManager")
	var first_target := Vector2i(1, 1)
	var second_target := Vector2i(2, 1)
	for target in [first_target, second_target]:
		var tile = grid.get_tile(target)
		if tile == null:
			_fail("Cleanup mission setup could not find target tile.")
			return
		tile.erase()
		tile.place_item("tall_grass")

	var result := _resolved_result_for("chuck", "Chuck", "chaotic", "cleanup_run", grid.day)
	scene.call("_apply_adversarial_result", result)
	await process_frame
	await process_frame

	var mission_id := _latest_mission_id(scene)
	if mission_id == "":
		_fail("Cleanup run did not start a crew mission.")
		return

	var mission: Dictionary = scene.crew_missions.get(mission_id, {})
	if str(mission.get("label", "")) != "Chuck Cleanup Sprint":
		_fail("Cleanup run did not use Chuck's mission label.")
		return

	var first_demand := _latest_open_mission_demand(scene, mission_id)
	if first_demand.is_empty() or str(first_demand.get("kind", "")) != "clear_brush":
		_fail("Cleanup run did not open with brush clearing.")
		return
	var first_step_target: Vector2i = first_demand.get("target_tile", first_target)
	grid.get_tile(first_step_target).cut_with_sickle()
	scene.call("_on_player_action_logged", _clear_event(first_step_target, "Cleared first cleanup patch."))
	await process_frame
	await process_frame

	var second_demand := _latest_open_mission_demand(scene, mission_id)
	if second_demand.is_empty() or str(second_demand.get("kind", "")) != "clear_brush":
		_fail("Cleanup run did not advance into a second brush clearing.")
		return
	var second_step_target: Vector2i = second_demand.get("target_tile", second_target)
	if second_step_target == first_step_target:
		_fail("Cleanup run reused the first cleared target for its second step.")
		return
	grid.get_tile(second_step_target).cut_with_sickle()
	scene.call("_on_player_action_logged", _clear_event(second_step_target, "Cleared second cleanup patch."))
	await process_frame
	await process_frame

	mission = scene.crew_missions.get(mission_id, {})
	if str(mission.get("status", "")) != "done":
		_fail("Cleanup run did not resolve after two brush steps.")
		return
	if int(scene.resources.get("fiber", 0)) < 5:
		_fail("Cleanup run did not pay its completion fiber reward.")
		return

	scene.queue_free()
	await process_frame


func _resolved_result_for(agent_id: String, agent_name: String, trait_name: String, mission_hint: String, mission_day: int) -> Dictionary:
	var session_manager = preload("res://scripts/ai/AdversarialSessionManager.gd").new()
	session_manager.start_session({
		"id": agent_id,
		"name": agent_name,
		"trait": trait_name,
		"irritation": 0.0
	}, {
		"day": mission_day,
		"demand_hint": mission_hint,
		"grievance_text": "%s wants a concrete two-step recovery plan." % agent_name,
		"npc_goal": "turn the promise into practical field steps"
	})
	session_manager.choose_response("own_mistake")
	return session_manager.choose_response("own_mistake")


func _clear_event(target: Vector2i, message: String) -> Dictionary:
	return {
		"actor": "player",
		"tool": "sickle",
		"action": "clear_brush",
		"grid_pos": target,
		"item_id": "sickle",
		"success": true,
		"message": message,
		"value": 0,
		"resources": {"fiber": 2},
		"crafted_cost": {}
	}


func _latest_mission_id(scene: Node) -> String:
	if scene.crew_mission_ids.is_empty():
		return ""
	return str(scene.crew_mission_ids.back())


func _latest_open_mission_demand(scene: Node, mission_id: String) -> Dictionary:
	var demand_ids: Array = scene.get("crafting_demand_ids")
	var demands: Dictionary = scene.get("crafting_demands")
	for index in range(demand_ids.size() - 1, -1, -1):
		var demand_id := str(demand_ids[index])
		var demand: Dictionary = demands.get(demand_id, {})
		if str(demand.get("status", "")) == "open" and str(demand.get("mission_id", "")) == mission_id:
			return demand
	return {}


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
