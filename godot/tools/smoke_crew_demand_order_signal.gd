extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

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
	if not social_label.text.contains("Wants"):
		_fail("Fresh demand did not start as a crew-row Wants signal.")
		return

	scene.call("_on_advance_day_requested")
	await process_frame

	var demand: Dictionary = scene.crafting_demands[demand_id]
	if str(demand.get("authored_order_id", "")) == "":
		_fail("Aged targeted demand did not draft a linked work order.")
		return
	if not social_label.visible:
		_fail("Crew row hid Bert's drafted-order signal.")
		return
	if social_label.text.contains("Wants"):
		_fail("Crew row still showed a raw Wants signal after Bert drafted a work order.")
		return
	if not social_label.text.contains("Queued") or not social_label.text.contains("Clear Brush"):
		_fail("Crew row did not show Bert's drafted demand as a queued order.")
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
