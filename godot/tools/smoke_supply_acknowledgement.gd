extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var agent_manager = scene.get_node("FarmWorld/AgentManager")
	var before_mood := _agent_mood(agent_manager, "marigold")

	var crafted_items: Dictionary = scene.get("crafted_items")
	crafted_items["seed_bundle"] = 1
	scene.set("crafted_items", crafted_items)
	scene.call("_refresh_inventory_and_orders")

	var demand_id := str(scene.call("_create_crafting_demand", {
		"kind": "deliver_item",
		"required_item": "seed_bundle",
		"amount": 1,
		"label": "Deliver Seed Bundle",
		"reason": "Marigold should visibly notice supply help."
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

	var snapshot := _agent_snapshot(agent_manager, "marigold")
	if snapshot.is_empty():
		_fail("Marigold snapshot disappeared after supply delivery.")
		return
	if str(snapshot.get("expression", "")) != "pleased":
		_fail("Marigold did not show a pleased expression after accepting supply.")
		return
	if float(snapshot.get("mood", 0.0)) <= before_mood:
		_fail("Marigold mood did not improve after accepting supply.")
		return

	var entries: Array = scene.get_node("GameUI").get("_field_log_entries")
	if not _entries_contain(entries, "Marigold accepted Seed Bundle"):
		_fail("Field Log did not record Marigold accepting the Seed Bundle.")
		return
	if not _entries_contain(entries, "Spring Hands ready"):
		_fail("Field Log did not connect the accepted supply to Spring Hands.")
		return
	if not _entries_contain(entries, "Marigold:") or not _entries_contain(entries, "Seed Bundle"):
		_fail("Marigold did not make a specific supply acknowledgement comment.")
		return

	scene.queue_free()
	await process_frame
	quit()


func _agent_mood(agent_manager, agent_id: String) -> float:
	return float(_agent_snapshot(agent_manager, agent_id).get("mood", 0.0))


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


func _entries_contain(entries: Array, needle: String) -> bool:
	for entry in entries:
		if str(entry).contains(needle):
			return true
	return false


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
