extends SceneTree

const AdversarialSessionManagerScript := preload("res://scripts/ai/AdversarialSessionManager.gd")

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_session_memory_preference_demands()
	if _failed:
		return
	await _test_scene_remembered_help_deepens_next_ask()
	if not _failed:
		quit()


func _test_session_memory_preference_demands() -> void:
	var remembered_demand := _resolved_supply_demand({
		"id": "marigold",
		"name": "Marigold",
		"trait": "hopeful",
		"irritation": 24.0,
		"remembered_help_label": "Seed Bundle",
		"remembered_help_days": 1
	})
	if str(remembered_demand.get("kind", "")) != "harvest_crop":
		_fail("Remembered Seed Bundle did not deepen Marigold's next ask into a harvest demand.")
		return
	if str(remembered_demand.get("preference_source", "")) != "remembered_help":
		_fail("Remembered-help demand did not record its preference source.")
		return
	if str(remembered_demand.get("preference_label", "")) != "Seed Bundle":
		_fail("Remembered-help demand did not keep the memory label.")
		return

	var truce_demand := _resolved_supply_demand({
		"id": "bert",
		"name": "Bert",
		"trait": "grizzled",
		"irritation": 32.0,
		"truce_label": "Fence Kit",
		"truce_days": 1
	})
	if str(truce_demand.get("kind", "")) != "build_fence":
		_fail("Fence Kit truce did not deepen Bert's next ask into a fence-building demand.")
		return
	if str(truce_demand.get("preference_source", "")) != "truce":
		_fail("Truce demand did not record its preference source.")
		return

	var explicit_demand := _resolved_demand({
		"id": "bert",
		"name": "Bert",
		"trait": "grizzled",
		"irritation": 32.0,
		"truce_label": "Fence Kit",
		"truce_days": 1
	}, "clear_brush")
	if str(explicit_demand.get("kind", "")) != "clear_brush":
		_fail("Explicit demand hint was overridden by memory/truce preference.")
		return
	if str(explicit_demand.get("preference_source", "")) != "":
		_fail("Explicit demand hint should not be marked as memory-influenced.")
		return


func _resolved_supply_demand(agent_snapshot: Dictionary) -> Dictionary:
	return _resolved_demand(agent_snapshot, "deliver_agent_supply")


func _resolved_demand(agent_snapshot: Dictionary, demand_hint: String) -> Dictionary:
	var manager = AdversarialSessionManagerScript.new()
	manager.start_session(agent_snapshot, {
		"day": 2,
		"demand_hint": demand_hint,
		"recent_failures": 1
	})
	manager.choose_response("own_mistake")
	var result: Dictionary = manager.choose_response("own_mistake")
	return result.get("crafting_demand", {})


func _test_scene_remembered_help_deepens_next_ask() -> void:
	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var crafted_items: Dictionary = scene.get("crafted_items")
	crafted_items["seed_bundle"] = 1
	scene.set("crafted_items", crafted_items)
	scene.call("_refresh_inventory_and_orders")

	var setup_demand_id := str(scene.call("_create_crafting_demand", {
		"kind": "deliver_item",
		"required_item": "seed_bundle",
		"amount": 1,
		"label": "Deliver Seed Bundle"
	}, {
		"agent_id": "marigold",
		"agent_name": "Marigold"
	}))
	await process_frame

	var give_button := _demand_button(scene, setup_demand_id)
	if give_button == null:
		_fail("Smoke setup did not expose a Give action.")
		return

	give_button.pressed.emit()
	await process_frame
	await process_frame

	scene.call("_on_advance_day_requested")
	await process_frame
	await process_frame

	scene.call("_on_adversarial_encounter_requested", "marigold")
	await process_frame

	var own_it_button := _encounter_button(scene, "Own it")
	if own_it_button == null:
		_fail("Remembered-help Parley did not expose Own it.")
		return
	own_it_button.pressed.emit()
	await process_frame

	own_it_button = _encounter_button(scene, "Own it")
	if own_it_button == null:
		_fail("Remembered-help Parley did not keep Own it for the second response.")
		return
	own_it_button.pressed.emit()
	await process_frame
	await process_frame

	var preference_demand := _latest_open_demand(scene, "marigold")
	if preference_demand.is_empty():
		_fail("Resolved remembered-help Parley did not create a follow-up demand.")
		return
	if str(preference_demand.get("kind", "")) != "harvest_crop":
		_fail("Remembered Seed Bundle follow-up was not a harvest demand in the scene.")
		return
	if str(preference_demand.get("preference_source", "")) != "remembered_help":
		_fail("Scene demand did not preserve remembered-help preference metadata.")
		return
	if str(preference_demand.get("preference_label", "")) != "Seed Bundle":
		_fail("Scene demand did not preserve the Seed Bundle preference label.")
		return

	var logged_preference := false
	for event in scene.get_node("GameEventLog").get("events"):
		if typeof(event) != TYPE_DICTIONARY or str(event.get("type", "")) != "crafting_demand":
			continue
		if str(event.get("status", "")) == "open" and str(event.get("preference_source", "")) == "remembered_help" and str(event.get("preference_label", "")) == "Seed Bundle":
			logged_preference = true
			break
	if not logged_preference:
		_fail("Crafting-demand receipt did not include remembered-help preference metadata.")
		return

	scene.queue_free()
	await process_frame


func _latest_open_demand(scene: Node, agent_id: String) -> Dictionary:
	var demand_ids: Array = scene.get("crafting_demand_ids")
	var demands: Dictionary = scene.get("crafting_demands")
	for index in range(demand_ids.size() - 1, -1, -1):
		var demand_id := str(demand_ids[index])
		var demand: Dictionary = demands.get(demand_id, {})
		if str(demand.get("status", "")) == "open" and str(demand.get("agent_id", "")) == agent_id:
			return demand
	return {}


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
		var typed_button := button as Button
		if typed_button != null and typed_button.visible and typed_button.text == button_text:
			return typed_button
	return null


func _fail(message: String) -> void:
	_failed = true
	push_error(message)
	quit(1)
