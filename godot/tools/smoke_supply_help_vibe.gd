extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_prep_counts_as_player_help()
	await _test_give_counts_as_player_help()
	quit()


func _test_prep_counts_as_player_help() -> void:
	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var demand_id := str(scene.call("_create_crafting_demand", {
		"kind": "deliver_item",
		"required_item": "rush_kit",
		"amount": 1,
		"label": "Deliver Rush Kit",
		"reason": "Chuck wants supply help counted in the day verdict."
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
	if prep_button == null or prep_button.text != "Prep":
		_fail("Smoke setup did not expose a Prep action.")
		return

	prep_button.pressed.emit()
	await process_frame
	await process_frame

	var summary := _day_summary(scene)
	if int(summary.get("craft_count", 0)) != 1:
		_fail("Prep supply help did not count the craft action.")
		return
	if int(summary.get("player_actions", {}).get("craft", 0)) < 1:
		_fail("Prep supply help did not count crafting as player work.")
		return
	if int(summary.get("player_actions", {}).get("deliver_supply", 0)) < 1:
		_fail("Prep supply help did not count the supply delivery as player work.")
		return
	if str(summary.get("vibe", {}).get("label", "")) == "neglectful":
		_fail("Prep supply help was still scored as neglectful.")
		return
	var formatted := str(scene.call("_format_day_summary", summary))
	if not formatted.contains("1 supply delivered"):
		_fail("Prep supply help was not called out in the formatted day summary.")
		return

	scene.queue_free()
	await process_frame


func _test_give_counts_as_player_help() -> void:
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
		"reason": "Marigold wants stashed supply help counted too."
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

	var summary := _day_summary(scene)
	if int(summary.get("craft_count", 0)) != 0:
		_fail("Give-only supply help should not invent a same-day craft action.")
		return
	if int(summary.get("player_actions", {}).get("deliver_supply", 0)) < 1:
		_fail("Give-only supply help did not count the supply delivery as player work.")
		return
	if int(summary.get("total_player_actions", 0)) < 1:
		_fail("Give-only supply help did not increase total player actions.")
		return
	if str(summary.get("vibe", {}).get("label", "")) == "neglectful":
		_fail("Give-only supply help was still scored as neglectful.")
		return
	var formatted := str(scene.call("_format_day_summary", summary))
	if not formatted.contains("1 supply delivered"):
		_fail("Give-only supply help was not called out in the formatted day summary.")
		return

	scene.queue_free()
	await process_frame


func _day_summary(scene: Node) -> Dictionary:
	var log = scene.get_node("GameEventLog")
	var grid = scene.get_node("FarmWorld/GridManager")
	return log.call("build_day_summary", int(grid.day))


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
