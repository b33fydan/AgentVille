extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var crafted_items: Dictionary = scene.get("crafted_items")
	crafted_items["seed_bundle"] = 1
	scene.set("crafted_items", crafted_items)
	scene.call("_refresh_inventory_and_orders")

	var demand_id := str(scene.call("_create_crafting_demand", {
		"kind": "deliver_item",
		"required_item": "seed_bundle",
		"amount": 1,
		"label": "Deliver Seed Bundle",
		"reason": "Marigold should show a crew-row social receipt."
	}, {
		"agent_id": "marigold",
		"agent_name": "Marigold"
	}))
	await process_frame

	var give_button := _demand_button(scene, demand_id)
	if give_button == null or give_button.text != "Give":
		_fail("Smoke setup did not expose a Give action.")
		return

	give_button.pressed.emit()
	await process_frame
	await process_frame

	var agent_manager = scene.get_node("FarmWorld/AgentManager")
	var snapshot := _agent_snapshot(agent_manager, "marigold")
	if int(snapshot.get("helped_today", 0)) != 1:
		_fail("Marigold snapshot did not remember today's completed help.")
		return
	if not str(snapshot.get("recent_help_label", "")).contains("Seed Bundle"):
		_fail("Marigold snapshot did not remember the helped supply label.")
		return

	var social_label := _crew_social_label(scene, "marigold")
	if social_label == null:
		_fail("Crew row did not expose a social receipt label.")
		return
	if not social_label.visible or not social_label.text.contains("Helped today"):
		_fail("Marigold crew row did not show the helped-today signal.")
		return
	if not social_label.text.contains("Seed Bundle"):
		_fail("Marigold crew row did not name the delivered supply.")
		return

	scene.call("_on_advance_day_requested")
	await process_frame
	await process_frame

	snapshot = _agent_snapshot(agent_manager, "marigold")
	if int(snapshot.get("helped_today", -1)) != 0:
		_fail("Marigold helped-today signal did not reset the next morning.")
		return
	if social_label.visible:
		_fail("Marigold crew row kept showing yesterday's helped-today signal.")
		return

	scene.queue_free()
	await process_frame
	quit()


func _agent_snapshot(agent_manager, agent_id: String) -> Dictionary:
	for snapshot in agent_manager.call("get_agent_snapshots"):
		if typeof(snapshot) == TYPE_DICTIONARY and str(snapshot.get("id", "")) == agent_id:
			return snapshot
	return {}


func _demand_button(scene: Node, demand_id: String) -> Button:
	var game_ui = scene.get_node("GameUI")
	var rows: Dictionary = game_ui.get("_crafting_demand_rows")
	if not rows.has(demand_id):
		return null
	var row: Dictionary = rows[demand_id]
	return row.get("button", null) as Button


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
