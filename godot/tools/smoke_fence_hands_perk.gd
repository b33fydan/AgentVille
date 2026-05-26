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
		_fail("Smoke setup could not find the Fence Hands target tile.")
		return
	if str(target_tile.decor_id) != "" or str(target_tile.structure_id) != "" or target_tile.crop != null:
		_fail("Smoke setup target was not an empty tile.")
		return

	var game_ui = scene.get_node("GameUI")
	var demand_id := str(scene.call("_create_crafting_demand", {
		"kind": "deliver_item",
		"required_item": "fence_kit",
		"amount": 1,
		"label": "Deliver Fence Kit",
		"reason": "Bert wants the kit to become actual fence."
	}, {
		"agent_id": "bert",
		"agent_name": "Bert"
	}))
	if demand_id == "":
		_fail("Smoke setup did not create the Fence Kit demand.")
		return

	scene.call("_add_resources", {
		"fiber": 2,
		"grain": 1
	})
	await process_frame

	var craft_buttons: Dictionary = game_ui.get("_craft_buttons")
	if not craft_buttons.has("fence_kit"):
		_fail("Fence Kit craft button was not registered.")
		return
	var fence_button := craft_buttons["fence_kit"] as Button
	if fence_button.disabled:
		_fail("Fence Kit craft button stayed disabled with enough resources.")
		return
	fence_button.pressed.emit()
	await process_frame
	await process_frame

	var demands: Dictionary = scene.get("crafting_demands")
	var demand: Dictionary = demands.get(demand_id, {})
	if str(demand.get("status", "")) != "done":
		_fail("Fence Kit demand was not completed before Fence Hands.")
		return

	var fence_timer_value = scene.get("_fence_hands_timer")
	if typeof(fence_timer_value) != TYPE_FLOAT and typeof(fence_timer_value) != TYPE_INT:
		_fail("Fence Hands timer did not activate after Bert's Fence Kit delivery.")
		return
	if float(fence_timer_value) <= 0.0:
		_fail("Fence Hands timer did not activate after Bert's Fence Kit delivery.")
		return

	var crew_status = game_ui.get("_crew_status_label")
	if crew_status == null or not str(crew_status.text).contains("Fence Hands"):
		_fail("Crew panel did not show the Fence Hands status.")
		return

	if str(target_tile.decor_id) != "fence":
		_fail("Fence Hands did not place a fence on the prepared open tile.")
		return

	var log = scene.get_node("GameEventLog")
	var applied_receipt := false
	var used_receipt := false
	for event in log.get("events"):
		if typeof(event) != TYPE_DICTIONARY or str(event.get("type", "")) != "farm_perk":
			continue
		if str(event.get("perk_id", "")) != "fence_hands":
			continue
		if str(event.get("status", "")) == "applied":
			applied_receipt = true
		if str(event.get("status", "")) == "used" and event.get("target_tile", Vector2i(-1, -1)) == target_tile.grid_pos:
			used_receipt = true
	if not applied_receipt:
		_fail("Fence Hands did not record an applied receipt.")
		return
	if not used_receipt:
		_fail("Fence Hands did not record the fenced tile receipt.")
		return

	scene.queue_free()
	await process_frame
	quit()


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
