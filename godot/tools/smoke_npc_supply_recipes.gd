extends SceneTree

const AdversarialSessionManagerScript := preload("res://scripts/ai/AdversarialSessionManager.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_agent_supply_selection()
	await _test_seed_bundle_delivery()
	quit()


func _test_agent_supply_selection() -> void:
	var bert_demand := _resolved_supply_demand({
		"id": "bert",
		"name": "Bert",
		"trait": "grizzled",
		"irritation": 28.0
	})
	if str(bert_demand.get("required_item", "")) != "fence_kit":
		_fail("Bert's practical supply demand should remain a Fence Kit.")
		return

	var marigold_demand := _resolved_supply_demand({
		"id": "marigold",
		"name": "Marigold",
		"trait": "hopeful",
		"irritation": 22.0
	})
	if str(marigold_demand.get("required_item", "")) != "seed_bundle":
		_fail("Marigold's agent supply demand did not request a Seed Bundle.")
		return
	if not str(marigold_demand.get("label", "")).contains("Seed Bundle"):
		_fail("Marigold's Seed Bundle demand did not carry a readable label.")
		return


func _resolved_supply_demand(agent_snapshot: Dictionary) -> Dictionary:
	var manager = AdversarialSessionManagerScript.new()
	manager.start_session(agent_snapshot, {
		"day": 1,
		"demand_hint": "deliver_agent_supply",
		"recent_failures": 1
	})
	manager.choose_response("own_mistake")
	var result: Dictionary = manager.choose_response("own_mistake")
	return result.get("crafting_demand", {})


func _test_seed_bundle_delivery() -> void:
	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var game_ui = scene.get_node("GameUI")
	var craft_buttons: Dictionary = game_ui.get("_craft_buttons")
	if not craft_buttons.has("seed_bundle"):
		_fail("Crafting UI did not register the Seed Bundle recipe.")
		return

	var crafted_labels: Dictionary = game_ui.get("_crafted_labels")
	if not crafted_labels.has("seed_bundle"):
		_fail("Stash UI did not expose Seed Bundle inventory.")
		return

	var demand_id := str(scene.call("_create_crafting_demand", {
		"kind": "deliver_item",
		"required_item": "seed_bundle",
		"amount": 1,
		"label": "Deliver Seed Bundle",
		"reason": "Marigold wants seed stock before the next apology tour."
	}, {
		"agent_id": "marigold",
		"agent_name": "Marigold"
	}))
	if demand_id == "":
		_fail("Scene refused to create a Seed Bundle demand.")
		return

	var demands: Dictionary = scene.get("crafting_demands")
	var demand: Dictionary = demands.get(demand_id, {})
	if str(demand.get("status_text", "")) != "Needs Seed Bundle":
		_fail("Seed Bundle demand did not show the missing supply state.")
		return

	scene.call("_add_resources", {
		"grain": 2
	})
	var seed_button := craft_buttons["seed_bundle"] as Button
	if seed_button.disabled:
		_fail("Seed Bundle craft button stayed disabled with enough Grain.")
		return
	seed_button.pressed.emit()
	await process_frame

	demands = scene.get("crafting_demands")
	demand = demands.get(demand_id, {})
	if str(demand.get("status", "")) != "done":
		_fail("Crafting a Seed Bundle did not complete the matching demand.")
		return
	if int(scene.get("crafted_items").get("seed_bundle", -1)) != 0:
		_fail("Completed Seed Bundle demand did not consume the delivered supply.")
		return
	if int(scene.get("resources").get("grain", 0)) != 1:
		_fail("Seed Bundle delivery did not spend grain and then apply Marigold's perk.")
		return

	var log = scene.get_node("GameEventLog")
	var crafted_receipt := false
	var completed_receipt := false
	for event in log.get("events"):
		if typeof(event) != TYPE_DICTIONARY:
			continue
		if str(event.get("type", "")) == "craft_action" and str(event.get("recipe_id", "")) == "seed_bundle":
			crafted_receipt = true
		if str(event.get("type", "")) == "crafting_demand" and str(event.get("status", "")) == "done" and str(event.get("required_item", "")) == "seed_bundle":
			completed_receipt = true
	if not crafted_receipt:
		_fail("Seed Bundle crafting did not record a craft receipt.")
		return
	if not completed_receipt:
		_fail("Seed Bundle demand completion did not record a demand receipt.")
		return

	scene.queue_free()
	await process_frame


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
