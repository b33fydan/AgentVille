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
		"reason": "Marigold should create a favor receipt when the favor is called."
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
	if int(summary.get("called_favors", 0)) != 1:
		_fail("Day summary did not count the called Parley favor.")
		return

	var favored_agents: Dictionary = summary.get("favored_agents", {})
	if not favored_agents.has("marigold"):
		_fail("Day summary did not remember Marigold as the called-favor agent.")
		return

	var marigold: Dictionary = favored_agents.get("marigold", {})
	if str(marigold.get("name", "")) != "Marigold":
		_fail("Called-favor receipt did not keep Marigold's readable name.")
		return
	if int(marigold.get("called_favors", 0)) != 1:
		_fail("Called-favor receipt did not count Marigold's favor.")
		return
	if str(marigold.get("last_favor_label", "")) != "Seed Bundle":
		_fail("Called-favor receipt did not keep the remembered Seed Bundle label.")
		return

	var formatted := str(scene.call("_format_day_summary", summary))
	if not formatted.contains("called Marigold's favor"):
		_fail("Formatted day summary did not call out Marigold's spent favor.")
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
