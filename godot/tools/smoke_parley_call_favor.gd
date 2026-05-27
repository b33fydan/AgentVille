extends SceneTree

const AdversarialSessionManagerScript := preload("res://scripts/ai/AdversarialSessionManager.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_model_call_favor_choice()
	await _test_scene_call_favor_button()
	quit()


func _test_model_call_favor_choice() -> void:
	var baseline_manager = AdversarialSessionManagerScript.new()
	var baseline: Dictionary = baseline_manager.start_session({
		"id": "marigold",
		"name": "Marigold",
		"trait": "hopeful",
		"irritation": 42.0,
		"helped_today": 0,
		"recent_help_label": ""
	}, {
		"day": 1,
		"recent_failures": 3,
		"top_failed_action": "place"
	})
	if _choices_have(baseline.get("choices", []), "call_favor"):
		_fail("Parley exposed Call favor without social credit.")
		return

	var helped_manager = AdversarialSessionManagerScript.new()
	var helped: Dictionary = helped_manager.start_session({
		"id": "marigold",
		"name": "Marigold",
		"trait": "hopeful",
		"irritation": 42.0,
		"helped_today": 1,
		"recent_help_label": "Seed Bundle"
	}, {
		"day": 1,
		"recent_failures": 3,
		"top_failed_action": "place"
	})
	if not _choices_have(helped.get("choices", []), "call_favor"):
		_fail("Parley did not expose Call favor when social credit existed.")
		return

	var after_favor: Dictionary = helped_manager.choose_response("call_favor")
	if str(after_favor.get("last_choice_id", "")) != "call_favor":
		_fail("Call favor did not become the selected response.")
		return
	if bool(after_favor.get("social_credit_used", false)) != true:
		_fail("Call favor did not mark the social credit as used.")
		return
	if _choices_have(after_favor.get("choices", []), "call_favor"):
		_fail("Call favor stayed available after being used once.")
		return

	var claims: Array = after_favor.get("claims", [])
	if claims.is_empty() or not str(claims.back().get("claim", "")).contains("Seed Bundle"):
		_fail("Call favor did not record the remembered Seed Bundle claim.")
		return
	if float(claims.back().get("resolution_delta", 0.0)) < 42.0:
		_fail("Call favor did not strongly advance resolution.")
		return
	if not str(after_favor.get("npc_line", "")).contains("Seed Bundle"):
		_fail("Call favor response did not name the remembered favor.")
		return


func _test_scene_call_favor_button() -> void:
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
		"reason": "Marigold should get a playable favor response."
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

	if not _choice_button_visible(scene, "Call favor"):
		_fail("Parley UI did not expose the Call favor response button.")
		return

	scene.queue_free()
	await process_frame


func _choices_have(choices, choice_id: String) -> bool:
	if typeof(choices) != TYPE_ARRAY:
		return false
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


func _choice_button_visible(scene: Node, button_text: String) -> bool:
	var game_ui = scene.get_node("GameUI")
	var buttons: Array = game_ui.get("_encounter_choice_buttons")
	for button in buttons:
		if button is Button and bool(button.visible) and str(button.text) == button_text:
			return true
	return false


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
