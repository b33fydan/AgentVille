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
		"reason": "Marigold should show spent favor feedback after Parley."
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

	var agent_manager = scene.get_node("FarmWorld/AgentManager")
	var snapshot := _agent_snapshot(agent_manager, "marigold")
	if int(snapshot.get("favor_spent_today", 0)) != 1:
		_fail("Calling a favor did not mark Marigold's favor as spent today.")
		return
	if str(snapshot.get("recent_spent_favor_label", "")) != "Seed Bundle":
		_fail("Spent favor snapshot did not keep the Seed Bundle label.")
		return

	var social_label := _crew_social_label(scene, "marigold")
	if social_label == null:
		_fail("Crew row did not expose Marigold's social label.")
		return
	if not social_label.visible:
		_fail("Crew row did not show Marigold's spent favor signal.")
		return
	if not social_label.text.contains("Favor spent") or not social_label.text.contains("Seed Bundle"):
		_fail("Crew row spent favor signal did not name the Seed Bundle.")
		return

	scene.call("_on_advance_day_requested")
	await process_frame
	await process_frame

	snapshot = _agent_snapshot(agent_manager, "marigold")
	if int(snapshot.get("favor_spent_today", -1)) != 0:
		_fail("Next morning did not clear Marigold's spent favor count.")
		return
	if str(snapshot.get("recent_spent_favor_label", "")) != "":
		_fail("Next morning did not clear Marigold's spent favor label.")
		return
	if social_label.visible:
		_fail("Crew row kept showing a spent favor after the next morning.")
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


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
