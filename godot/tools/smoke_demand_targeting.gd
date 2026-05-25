extends SceneTree


func _initialize() -> void:
	root.size = Vector2i(1600, 900)
	call_deferred("_run")


func _run() -> void:
	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var grid = scene.get_node("FarmWorld/GridManager")
	var game_ui = scene.get_node("GameUI")
	var camera_controller = scene.get_node("CameraController")
	var target_tile = grid.get_tile(Vector2i(0, 1))
	var wrong_tile = grid.get_tile(Vector2i(0, 2))
	if target_tile == null or wrong_tile == null:
		_fail("Starter brush target tiles were missing.")
		return

	var demand_id := str(scene.call("_create_crafting_demand", {
		"kind": "clear_brush",
		"required_action": "clear_brush",
		"amount": 1,
		"label": "Clear Brush"
	}, {
		"agent_id": "bert",
		"agent_name": "Bert"
	}))
	await process_frame

	if demand_id == "":
		_fail("Targeted clear-brush demand was not created.")
		return

	var demands: Dictionary = scene.get("crafting_demands")
	var demand: Dictionary = demands.get(demand_id, {})
	if demand.get("target_tile", Vector2i(-1, -1)) != target_tile.grid_pos:
		_fail("Clear-brush demand did not pick the first live brush target.")
		return

	var demand_rows: Dictionary = game_ui.get("_crafting_demand_rows")
	if not demand_rows.has(demand_id):
		_fail("Targeted demand row was not registered in the UI.")
		return
	var row: Dictionary = demand_rows[demand_id]
	if not str((row["label"] as Label).text).contains("0,1"):
		_fail("Demand row did not include compact target coordinates.")
		return

	if not target_tile.get_node("DemandMarker").visible:
		_fail("Demand target tile did not show the in-world demand marker.")
		return

	scene.call("_on_player_action_logged", {
		"actor": "player",
		"tool": "sickle",
		"action": "sickle",
		"grid_pos": wrong_tile.grid_pos,
		"item_id": "sickle",
		"success": true,
		"message": "Sickle cut it clean.",
		"value": 0,
		"resources": {"fiber": 2},
		"crafted_cost": {}
	})
	await process_frame

	demands = scene.get("crafting_demands")
	demand = demands.get(demand_id, {})
	if str(demand.get("status", "")) != "open":
		_fail("Wrong-tile brush clearing completed the targeted demand.")
		return

	var previous_target: Vector3 = camera_controller.target_position
	scene.call("_on_crafting_demand_target_requested", demand_id)
	await process_frame
	if camera_controller.target_position == previous_target:
		_fail("Requesting a targeted demand did not move the camera focus.")
		return

	scene.call("_on_player_action_logged", {
		"actor": "player",
		"tool": "sickle",
		"action": "sickle",
		"grid_pos": target_tile.grid_pos,
		"item_id": "sickle",
		"success": true,
		"message": "Sickle cut it clean.",
		"value": 0,
		"resources": {"fiber": 2},
		"crafted_cost": {}
	})
	await process_frame

	demands = scene.get("crafting_demands")
	demand = demands.get(demand_id, {})
	if str(demand.get("status", "")) != "done":
		_fail("Correct-tile brush clearing did not complete the targeted demand.")
		return
	if target_tile.get_node("DemandMarker").visible:
		_fail("Completed demand marker stayed visible on the target tile.")
		return

	scene.queue_free()
	await process_frame
	quit()


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
