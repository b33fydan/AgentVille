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
		"reason": "Marigold wants the day-end verdict to remember the spent favor."
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

	scene.call("_on_adversarial_encounter_requested", "marigold")
	await process_frame

	var call_favor_button := _encounter_button(scene, "Call favor")
	if call_favor_button == null:
		_fail("Parley did not expose Call favor after helping Marigold.")
		return
	call_favor_button.pressed.emit()
	await process_frame

	var own_it_button := _encounter_button(scene, "Own it")
	if own_it_button == null:
		_fail("Parley did not keep a normal repair response after Call favor.")
		return
	own_it_button.pressed.emit()
	await process_frame
	await process_frame

	var summary: Dictionary = scene.get_node("GameEventLog").call("build_day_summary", scene.get_node("FarmWorld/GridManager").day)
	var verdict := str(scene.get_node("FarmWorld/AgentManager").call("_summary_comment", summary))
	if not verdict.contains("Marigold"):
		_fail("NPC day-end verdict did not name the spent-favor crew member.")
		return
	if not verdict.to_lower().contains("favor"):
		_fail("NPC day-end verdict did not acknowledge the called favor.")
		return
	if verdict.begins_with("Bert: \"Helped Marigold"):
		_fail("NPC day-end verdict fell back to the generic helped-agent line.")
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
