extends SceneTree

const AdversarialSessionManagerScript := preload("res://scripts/ai/AdversarialSessionManager.gd")

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_session_memory_context()
	if _failed:
		return
	await _test_scene_memory_context()
	if not _failed:
		quit()


func _test_session_memory_context() -> void:
	var manager = AdversarialSessionManagerScript.new()
	var session: Dictionary = manager.start_session({
		"id": "marigold",
		"name": "Marigold",
		"trait": "hopeful",
		"irritation": 42.0,
		"helped_today": 0,
		"recent_help_label": "",
		"remembered_help_label": "Seed Bundle"
	}, {
		"day": 2,
		"recent_failures": 3,
		"top_failed_action": "place"
	})

	if str(session.get("remembered_help_label", "")) != "Seed Bundle":
		_fail("Parley session did not preserve the remembered help label.")
		return
	if float(session.get("social_credit_bonus", -1.0)) != 0.0:
		_fail("Remembered help should not become a same-day patience bonus.")
		return
	if str(session.get("social_credit_label", "")) != "":
		_fail("Remembered help should not become spendable social credit.")
		return
	if _choices_have(session.get("choices", []), "call_favor"):
		_fail("Remembered help should not expose the Call favor response.")
		return
	if not str(session.get("npc_line", "")).contains("Seed Bundle"):
		_fail("Parley opening line did not mention remembered help.")
		return


func _test_scene_memory_context() -> void:
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

	scene.call("_on_adversarial_encounter_requested", "marigold")
	await process_frame

	var game_ui = scene.get_node("GameUI")
	var goal_label := game_ui.get("_encounter_goal_label") as Label
	if goal_label == null:
		_fail("Parley panel did not expose the patience goal label.")
		return
	if not goal_label.text.contains("Memory"):
		_fail("Parley panel did not show remembered-help context. saw=%s" % goal_label.text)
		return
	if goal_label.text.contains("Favor +"):
		_fail("Remembered help appeared as a spendable favor bonus.")
		return
	if _encounter_button(scene, "Call favor") != null:
		_fail("Remembered help exposed a Call favor button in the scene.")
		return

	var line_label := game_ui.get("_encounter_line_label") as Label
	if line_label == null or not line_label.text.contains("Seed Bundle"):
		_fail("Parley UI line did not name the remembered Seed Bundle.")
		return

	var own_it_button := _encounter_button(scene, "Own it")
	if own_it_button == null:
		_fail("Parley did not expose the normal Own it response.")
		return
	own_it_button.pressed.emit()
	await process_frame

	own_it_button = _encounter_button(scene, "Own it")
	if own_it_button == null:
		_fail("Parley did not keep Own it available for the second repair response.")
		return
	own_it_button.pressed.emit()
	await process_frame
	await process_frame

	var summary: Dictionary = scene.get_node("GameEventLog").call("build_day_summary", scene.get_node("FarmWorld/GridManager").day)
	if int(summary.get("memory_context_sessions", 0)) != 1:
		_fail("Day summary did not count the remembered-help Parley context.")
		return

	var memory_sessions: Dictionary = summary.get("remembered_help_sessions", {})
	if not memory_sessions.has("marigold"):
		_fail("Day summary did not keep Marigold's remembered-help Parley receipt.")
		return

	var marigold_memory: Dictionary = memory_sessions.get("marigold", {})
	if str(marigold_memory.get("last_memory_label", "")) != "Seed Bundle":
		_fail("Remembered-help receipt did not preserve the Seed Bundle label.")
		return

	var formatted := str(scene.call("_format_day_summary", summary))
	if not formatted.contains("remembered Marigold's Seed Bundle"):
		_fail("Formatted day summary did not mention remembered-help Parley context.")
		return

	scene.queue_free()
	await process_frame


func _choices_have(choices: Array, choice_id: String) -> bool:
	for choice in choices:
		if typeof(choice) == TYPE_DICTIONARY and str(choice.get("id", "")) == choice_id:
			return true
	return false


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
