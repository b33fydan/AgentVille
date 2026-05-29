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

	scene.call("_on_advance_day_requested")
	await process_frame

	var demand: Dictionary = scene.crafting_demands[demand_id]
	var order_id := str(demand.get("authored_order_id", ""))
	if order_id == "" or not scene.work_orders.has(order_id):
		_fail("Aged targeted demand did not draft a linked work order.")
		return

	var social_label := _crew_social_label(scene, "bert")
	if social_label == null:
		_fail("Crew row did not expose Bert's social label.")
		return
	if not social_label.visible or not social_label.text.contains("Queued"):
		_fail("Crew row did not show Bert's drafted demand as a queued signal.")
		return

	var target_tile = grid.get_tile(demand.get("target_tile", Vector2i(-1, -1)))
	if target_tile == null:
		_fail("Queued demand target tile was missing.")
		return
	var order_marker := target_tile.get_node("OrderMarker") as Node3D
	if order_marker == null or not order_marker.visible:
		_fail("Queued demand did not show a work-order marker.")
		return

	var previous_scale: Vector3 = order_marker.scale
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	social_label.gui_input.emit(click)

	if order_marker.scale.x <= previous_scale.x:
		_fail("Clicking a queued crew-row demand did not pulse the work-order marker.")
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
