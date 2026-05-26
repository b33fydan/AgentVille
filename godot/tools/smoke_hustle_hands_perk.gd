extends SceneTree

const AdversarialSessionManagerScript := preload("res://scripts/ai/AdversarialSessionManager.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_chuck_supply_selection()
	await _test_hustle_hands_delivery()
	quit()


func _test_chuck_supply_selection() -> void:
	var manager = AdversarialSessionManagerScript.new()
	manager.start_session({
		"id": "chuck",
		"name": "Chuck",
		"trait": "chaotic",
		"irritation": 30.0
	}, {
		"day": 1,
		"demand_hint": "deliver_agent_supply",
		"recent_failures": 2
	})
	manager.choose_response("own_mistake")
	var result: Dictionary = manager.choose_response("own_mistake")
	var demand: Dictionary = result.get("crafting_demand", {})
	if str(demand.get("required_item", "")) != "rush_kit":
		_fail("Chuck's agent supply demand did not request a Rush Kit.")
		return
	if not str(demand.get("label", "")).contains("Rush Kit"):
		_fail("Chuck's Rush Kit demand did not carry a readable label.")
		return


func _test_hustle_hands_delivery() -> void:
	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var grid = scene.get_node("FarmWorld/GridManager")
	var target_tile = grid.get_tile(Vector2i(0, 0))
	if target_tile == null:
		_fail("Smoke setup could not find the Hustle Hands target tile.")
		return
	target_tile.place_item("rock")
	if str(target_tile.decor_id) != "rock":
		_fail("Smoke setup did not place the target rock.")
		return

	var game_ui = scene.get_node("GameUI")
	var craft_buttons: Dictionary = game_ui.get("_craft_buttons")
	if not craft_buttons.has("rush_kit"):
		_fail("Crafting UI did not register the Rush Kit recipe.")
		return

	var crafted_labels: Dictionary = game_ui.get("_crafted_labels")
	if not crafted_labels.has("rush_kit"):
		_fail("Stash UI did not expose Rush Kit inventory.")
		return

	var demand_id := str(scene.call("_create_crafting_demand", {
		"kind": "deliver_item",
		"required_item": "rush_kit",
		"amount": 1,
		"label": "Deliver Rush Kit",
		"reason": "Chuck wants speed in a box."
	}, {
		"agent_id": "chuck",
		"agent_name": "Chuck"
	}))
	if demand_id == "":
		_fail("Scene refused to create a Rush Kit demand.")
		return

	scene.call("_add_resources", {
		"fiber": 1,
		"stone": 1
	})
	await process_frame

	var rush_button := craft_buttons["rush_kit"] as Button
	if rush_button.disabled:
		_fail("Rush Kit craft button stayed disabled with enough resources.")
		return
	rush_button.pressed.emit()
	await process_frame
	await process_frame

	var demands: Dictionary = scene.get("crafting_demands")
	var demand: Dictionary = demands.get(demand_id, {})
	if str(demand.get("status", "")) != "done":
		_fail("Rush Kit demand was not completed before Hustle Hands.")
		return

	var hustle_timer_value = scene.get("_hustle_hands_timer")
	if typeof(hustle_timer_value) != TYPE_FLOAT and typeof(hustle_timer_value) != TYPE_INT:
		_fail("Hustle Hands timer did not activate after Chuck's Rush Kit delivery.")
		return
	if float(hustle_timer_value) <= 0.0:
		_fail("Hustle Hands timer did not activate after Chuck's Rush Kit delivery.")
		return

	var crew_status = game_ui.get("_crew_status_label")
	if crew_status == null or not str(crew_status.text).contains("Hustle Hands"):
		_fail("Crew panel did not show the Hustle Hands status.")
		return

	if str(target_tile.decor_id) == "rock":
		_fail("Hustle Hands did not clear the prepared rock tile.")
		return

	var log = scene.get_node("GameEventLog")
	var applied_receipt := false
	var used_receipt := false
	for event in log.get("events"):
		if typeof(event) != TYPE_DICTIONARY or str(event.get("type", "")) != "farm_perk":
			continue
		if str(event.get("perk_id", "")) != "hustle_hands":
			continue
		if str(event.get("status", "")) == "applied":
			applied_receipt = true
		if str(event.get("status", "")) == "used" and event.get("target_tile", Vector2i(-1, -1)) == target_tile.grid_pos:
			used_receipt = true
	if not applied_receipt:
		_fail("Hustle Hands did not record an applied receipt.")
		return
	if not used_receipt:
		_fail("Hustle Hands did not record the cleared tile receipt.")
		return

	scene.queue_free()
	await process_frame


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
