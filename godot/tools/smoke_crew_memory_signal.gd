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
		"label": "Deliver Seed Bundle"
	}, {
		"agent_id": "marigold",
		"agent_name": "Marigold"
	}))
	await process_frame

	var give_button := _demand_button(scene, demand_id)
	if give_button == null:
		_fail("Smoke setup did not expose a Give button.")
		return

	give_button.pressed.emit()
	await process_frame
	await process_frame

	var social_label := _crew_social_label(scene, "marigold")
	if social_label == null or not social_label.visible or not social_label.text.contains("Helped today"):
		_fail("Marigold did not show same-day helped credit before day advance.")
		return
	if not social_label.text.contains("Seed Bundle"):
		_fail("Same-day helped credit did not name the delivered Seed Bundle.")
		return

	scene.call("_on_advance_day_requested")
	await process_frame
	await process_frame

	social_label = _crew_social_label(scene, "marigold")
	if social_label == null or not social_label.visible:
		_fail("Marigold did not keep a next-day memory signal after helped credit reset.")
		return
	if not social_label.text.contains("Remembers") or not social_label.text.contains("Seed Bundle"):
		_fail("Next-day memory signal did not name the remembered help. saw=%s" % social_label.text)
		return

	scene.call("_on_advance_day_requested")
	await process_frame
	await process_frame

	social_label = _crew_social_label(scene, "marigold")
	if social_label != null and social_label.visible and social_label.text.contains("Remembers"):
		_fail("One-day memory signal did not clear on the following morning.")
		return

	scene.queue_free()
	await process_frame
	quit()


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
