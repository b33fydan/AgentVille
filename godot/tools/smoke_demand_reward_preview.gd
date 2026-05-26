extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _assert_supply_reward_preview({
		"agent_id": "bert",
		"agent_name": "Bert"
	}, "fence_kit", "Fence Hands")
	await _assert_supply_reward_preview({
		"agent_id": "marigold",
		"agent_name": "Marigold"
	}, "seed_bundle", "Spring Hands")
	await _assert_supply_reward_preview({
		"agent_id": "chuck",
		"agent_name": "Chuck"
	}, "rush_kit", "Hustle Hands")
	quit()


func _assert_supply_reward_preview(source_event: Dictionary, item_id: String, expected_reward: String) -> void:
	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var demand_id := str(scene.call("_create_crafting_demand", {
		"kind": "deliver_item",
		"required_item": item_id,
		"amount": 1,
		"label": "Deliver %s" % _pretty_item_name(item_id),
		"reason": "%s wants to preview the payoff before spending supplies." % str(source_event.get("agent_name", "Crew"))
	}, source_event))
	await process_frame

	if demand_id == "":
		_fail("Smoke setup could not create a %s demand." % expected_reward)
		return

	var snapshot: Dictionary = scene.call("_crafting_demand_snapshot", demand_id)
	if str(snapshot.get("reward_text", "")) != expected_reward:
		_fail("Demand snapshot did not preview %s." % expected_reward)
		return

	var game_ui = scene.get_node("GameUI")
	var rows: Dictionary = game_ui.get("_crafting_demand_rows")
	if not rows.has(demand_id):
		_fail("Demand row was not visible for %s." % expected_reward)
		return

	var row: Dictionary = rows[demand_id]
	if not row.has("reward"):
		_fail("Demand row did not expose a reward label for %s." % expected_reward)
		return

	var reward_label := row["reward"] as Label
	if reward_label == null:
		_fail("Demand reward row entry was not a Label for %s." % expected_reward)
		return
	if not reward_label.visible or str(reward_label.text) != expected_reward:
		_fail("Demand row did not display %s before delivery." % expected_reward)
		return

	scene.queue_free()
	await process_frame


func _pretty_item_name(item_id: String) -> String:
	match item_id:
		"fence_kit":
			return "Fence Kit"
		"seed_bundle":
			return "Seed Bundle"
		"rush_kit":
			return "Rush Kit"
	return item_id.capitalize()


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
