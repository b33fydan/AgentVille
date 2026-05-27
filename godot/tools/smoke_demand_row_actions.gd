extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_prep_button_crafts_and_delivers()
	await _test_give_button_delivers_stashed_supply()
	quit()


func _test_prep_button_crafts_and_delivers() -> void:
	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var demand_id := str(scene.call("_create_crafting_demand", {
		"kind": "deliver_item",
		"required_item": "rush_kit",
		"amount": 1,
		"label": "Deliver Rush Kit",
		"reason": "Chuck wants the supply row to do the obvious thing."
	}, {
		"agent_id": "chuck",
		"agent_name": "Chuck"
	}))
	scene.call("_add_resources", {
		"fiber": 1,
		"stone": 1
	})
	await process_frame

	var prep_button := _demand_button(scene, demand_id)
	if prep_button == null:
		_fail("Craftable demand row did not expose a Prep button.")
		return
	if prep_button.text != "Prep" or prep_button.disabled:
		_fail("Craftable demand row did not present an enabled Prep action.")
		return

	prep_button.pressed.emit()
	await process_frame
	await process_frame

	var demand: Dictionary = scene.get("crafting_demands").get(demand_id, {})
	if str(demand.get("status", "")) != "done":
		_fail("Prep action did not complete the Rush Kit demand.")
		return
	if int(scene.get("crafted_items").get("rush_kit", -1)) != 0:
		_fail("Prep action did not deliver the crafted Rush Kit immediately.")
		return
	if int(scene.get("resources").get("fiber", -1)) != 0 or int(scene.get("resources").get("stone", -1)) != 0:
		_fail("Prep action did not spend the Rush Kit ingredients.")
		return
	if float(scene.get("_hustle_hands_timer")) <= 0.0:
		_fail("Prep action did not trigger Chuck's Hustle Hands payoff.")
		return
	if not _assert_done_button(scene, demand_id, "Prep"):
		return

	scene.queue_free()
	await process_frame


func _test_give_button_delivers_stashed_supply() -> void:
	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	scene.call("_add_resources", {
		"grain": 2
	})
	if not bool(scene.call("_craft_recipe", "seed_bundle", "player_demand_quiet")):
		_fail("Smoke setup could not stash a Seed Bundle.")
		return

	var demand_id := str(scene.call("_create_crafting_demand", {
		"kind": "deliver_item",
		"required_item": "seed_bundle",
		"amount": 1,
		"label": "Deliver Seed Bundle",
		"reason": "Marigold wants an already-stashed supply delivered from the row."
	}, {
		"agent_id": "marigold",
		"agent_name": "Marigold"
	}))
	await process_frame

	var give_button := _demand_button(scene, demand_id)
	if give_button == null:
		_fail("Ready demand row did not expose a Give button.")
		return
	if give_button.text != "Give" or give_button.disabled:
		_fail("Ready demand row did not present an enabled Give action.")
		return

	give_button.pressed.emit()
	await process_frame
	await process_frame

	var demand: Dictionary = scene.get("crafting_demands").get(demand_id, {})
	if str(demand.get("status", "")) != "done":
		_fail("Give action did not complete the Seed Bundle demand.")
		return
	if int(scene.get("crafted_items").get("seed_bundle", -1)) != 0:
		_fail("Give action did not consume the stashed Seed Bundle.")
		return
	if float(scene.get("_spring_hands_timer")) <= 0.0:
		_fail("Give action did not trigger Marigold's Spring Hands payoff.")
		return
	if not _assert_done_button(scene, demand_id, "Give"):
		return

	scene.queue_free()
	await process_frame


func _assert_done_button(scene: Node, demand_id: String, source_action: String) -> bool:
	var button := _demand_button(scene, demand_id)
	if button == null:
		_fail("%s action removed the completed demand row button." % source_action)
		return false
	if button.text != "Done" or not button.disabled:
		_fail("%s action did not leave a disabled Done button on the completed row." % source_action)
		return false
	return true


func _demand_button(scene: Node, demand_id: String) -> Button:
	var game_ui = scene.get_node("GameUI")
	var rows: Dictionary = game_ui.get("_crafting_demand_rows")
	if not rows.has(demand_id):
		return null
	var row: Dictionary = rows[demand_id]
	return row.get("button", null) as Button


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
