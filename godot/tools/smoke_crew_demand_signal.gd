extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var grid = scene.get_node("FarmWorld/GridManager")
	var target_tile = grid.get_tile(Vector2i(0, 1))
	if target_tile == null:
		_fail("Starter brush target tile was missing.")
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

	var social_label := _crew_social_label(scene, "bert")
	if social_label == null:
		_fail("Crew row did not expose Bert's social label.")
		return
	if not social_label.visible:
		_fail("Crew row did not show Bert's open demand signal.")
		return
	if not social_label.text.contains("Wants") or not social_label.text.contains("Clear Brush"):
		_fail("Crew row open demand signal did not name the brush demand.")
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
	await process_frame

	if not social_label.visible:
		_fail("Crew row hid Bert's completed demand social signal.")
		return
	if not social_label.text.contains("Helped today") or not social_label.text.contains("Clear Brush"):
		_fail("Crew row did not switch from Wants to helped social credit.")
		return

	scene.queue_free()
	await process_frame
	quit()


func _crew_social_label(scene: Node, agent_id: String) -> Label:
	var game_ui = scene.get_node("GameUI")
	var rows: Dictionary = game_ui.get("_crew_rows")
	if not rows.has(agent_id):
		return null
	var row: Dictionary = rows[agent_id]
	return row.get("social", null) as Label


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
