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
		_fail("Smoke setup did not expose a Give action.")
		return

	give_button.pressed.emit()
	await process_frame
	await process_frame

	scene.call("_on_advance_day_requested")
	await process_frame
	await process_frame

	var social_label := _crew_social_label(scene, "marigold")
	if social_label == null or not social_label.visible or not social_label.text.contains("Remembers"):
		_fail("Smoke setup did not create a visible remembered-help signal.")
		return

	scene.call("_on_adversarial_encounter_requested", "marigold")
	await process_frame

	for index in range(3):
		var deflect_button := _encounter_button(scene, "Deflect")
		if deflect_button == null:
			_fail("Parley did not expose Deflect response %s." % (index + 1))
			return
		deflect_button.pressed.emit()
		await process_frame

	var discussed_snapshot := _agent_snapshot(scene.get_node("FarmWorld/AgentManager"), "marigold")
	if int(discussed_snapshot.get("memory_discussed_today", 0)) != 1:
		_fail("Remembered-help Parley did not mark memory as discussed today.")
		return

	scene.call("_on_advance_day_requested")
	await process_frame
	await process_frame

	var truce_snapshot := _agent_snapshot(scene.get_node("FarmWorld/AgentManager"), "marigold")
	if int(truce_snapshot.get("truce_days", 0)) != 1:
		_fail("Discussed memory did not roll into a one-day truce.")
		return
	if str(truce_snapshot.get("truce_label", "")) != "Seed Bundle":
		_fail("Truce did not preserve the discussed Seed Bundle label.")
		return
	if int(truce_snapshot.get("memory_discussed_today", -1)) != 0:
		_fail("Discussed-memory counter did not clear after becoming a truce.")
		return

	social_label = _crew_social_label(scene, "marigold")
	if social_label == null or not social_label.visible:
		_fail("Crew row did not show the memory truce signal.")
		return
	if not social_label.text.contains("Truce") or not social_label.text.contains("Seed Bundle"):
		_fail("Crew row did not show the truce memory signal. saw=%s" % social_label.text)
		return
	if social_label.text.contains("Discussed") or social_label.text.contains("Remembers") or social_label.text.contains("Favor"):
		_fail("Truce signal used a stale memory/social state. saw=%s" % social_label.text)
		return

	scene.call("_on_advance_day_requested")
	await process_frame
	await process_frame

	var cleared_snapshot := _agent_snapshot(scene.get_node("FarmWorld/AgentManager"), "marigold")
	if int(cleared_snapshot.get("truce_days", 0)) != 0 or str(cleared_snapshot.get("truce_label", "")) != "":
		_fail("Memory truce did not clear after one day.")
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
