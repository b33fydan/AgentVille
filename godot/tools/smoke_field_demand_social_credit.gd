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

	var demand: Dictionary = scene.get("crafting_demands").get(demand_id, {})
	if str(demand.get("status", "")) != "done":
		_fail("Brush field-work demand did not complete.")
		return

	var agent_manager = scene.get_node("FarmWorld/AgentManager")
	var snapshot := _agent_snapshot(agent_manager, "bert")
	if int(snapshot.get("helped_today", 0)) != 1:
		_fail("Completed brush demand did not mark Bert as helped today.")
		return
	if not str(snapshot.get("recent_help_label", "")).contains("Clear Brush"):
		_fail("Completed brush demand did not keep a readable helped label.")
		return

	var social_label := _crew_social_label(scene, "bert")
	if social_label == null:
		_fail("Crew row did not expose Bert's social label.")
		return
	if not social_label.visible:
		_fail("Crew row did not show Bert's field-work social credit.")
		return
	if not social_label.text.contains("Helped today") or not social_label.text.contains("Clear Brush"):
		_fail("Crew row field-work social credit did not name the brush demand.")
		return

	scene.call("_on_adversarial_encounter_requested", "bert")
	await process_frame

	if _encounter_button(scene, "Call favor") == null:
		_fail("Field-work social credit did not expose Call favor in Bert's next Parley.")
		return

	scene.queue_free()
	await process_frame
	quit()


func _agent_snapshot(agent_manager, agent_id: String) -> Dictionary:
	for snapshot in agent_manager.call("get_agent_snapshots"):
		if typeof(snapshot) == TYPE_DICTIONARY and str(snapshot.get("id", "")) == agent_id:
			return snapshot
	return {}


func _crew_social_label(scene: Node, agent_id: String) -> Label:
	var game_ui = scene.get_node("GameUI")
	var rows: Dictionary = game_ui.get("_crew_rows")
	if not rows.has(agent_id):
		return null
	var row: Dictionary = rows[agent_id]
	return row.get("social", null) as Label


func _encounter_button(scene: Node, button_text: String) -> Button:
	var game_ui = scene.get_node("GameUI")
	var buttons: Array = game_ui.get("_encounter_choice_buttons")
	for button in buttons:
		if button is Button and bool(button.visible) and str(button.text) == button_text:
			return button
	return null


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
