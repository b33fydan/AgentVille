extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var grid = scene.get_node("FarmWorld/GridManager")
	var target_tile = grid.get_tile(Vector2i(0, 0))
	if target_tile == null:
		_fail("Smoke setup could not find the Spring Hands target tile.")
		return
	target_tile.till()
	if not target_tile.is_tilled or target_tile.crop != null:
		_fail("Smoke setup did not prepare an empty tilled tile.")
		return

	var game_ui = scene.get_node("GameUI")
	var demand_id := str(scene.call("_create_crafting_demand", {
		"kind": "deliver_item",
		"required_item": "seed_bundle",
		"amount": 1,
		"label": "Deliver Seed Bundle",
		"reason": "Marigold wants seed stock with visible farm payoff."
	}, {
		"agent_id": "marigold",
		"agent_name": "Marigold"
	}))
	if demand_id == "":
		_fail("Smoke setup did not create the Seed Bundle demand.")
		return

	scene.call("_add_resources", {
		"grain": 2
	})
	await process_frame

	var craft_buttons: Dictionary = game_ui.get("_craft_buttons")
	if not craft_buttons.has("seed_bundle"):
		_fail("Seed Bundle craft button was not registered.")
		return
	var seed_button := craft_buttons["seed_bundle"] as Button
	if seed_button.disabled:
		_fail("Seed Bundle craft button stayed disabled with enough Grain.")
		return
	seed_button.pressed.emit()
	await process_frame
	await process_frame

	var demands: Dictionary = scene.get("crafting_demands")
	var demand: Dictionary = demands.get(demand_id, {})
	if str(demand.get("status", "")) != "done":
		_fail("Seed Bundle demand was not completed before Spring Hands.")
		return

	var spring_timer_value = scene.get("_spring_hands_timer")
	if typeof(spring_timer_value) != TYPE_FLOAT and typeof(spring_timer_value) != TYPE_INT:
		_fail("Spring Hands timer did not activate after Marigold's Seed Bundle delivery.")
		return
	if float(spring_timer_value) <= 0.0:
		_fail("Spring Hands timer did not activate after Marigold's Seed Bundle delivery.")
		return

	var crew_status = game_ui.get("_crew_status_label")
	if crew_status == null or not str(crew_status.text).contains("Spring Hands"):
		_fail("Crew panel did not show the Spring Hands status.")
		return

	if target_tile.crop == null:
		_fail("Spring Hands did not plant the prepared tilled tile.")
		return
	if str(target_tile.crop.crop_id) != "wheat":
		_fail("Spring Hands planted the wrong crop.")
		return

	var log = scene.get_node("GameEventLog")
	var applied_receipt := false
	var used_receipt := false
	for event in log.get("events"):
		if typeof(event) != TYPE_DICTIONARY or str(event.get("type", "")) != "farm_perk":
			continue
		if str(event.get("perk_id", "")) != "spring_hands":
			continue
		if str(event.get("status", "")) == "applied":
			applied_receipt = true
		if str(event.get("status", "")) == "used" and event.get("target_tile", Vector2i(-1, -1)) == target_tile.grid_pos:
			used_receipt = true
	if not applied_receipt:
		_fail("Spring Hands did not record an applied receipt.")
		return
	if not used_receipt:
		_fail("Spring Hands did not record the planted tile receipt.")
		return

	scene.queue_free()
	await process_frame
	quit()


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
