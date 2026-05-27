extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
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
		"reason": "Marigold wants the day summary to remember who was helped."
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

	var summary: Dictionary = scene.get_node("GameEventLog").call("build_day_summary", scene.get_node("FarmWorld/GridManager").day)
	var helped_agents: Dictionary = summary.get("helped_agents", {})
	if not helped_agents.has("marigold"):
		_fail("Day summary did not remember Marigold as a helped agent.")
		return

	var marigold: Dictionary = helped_agents.get("marigold", {})
	if str(marigold.get("name", "")) != "Marigold":
		_fail("Helped-agent receipt did not keep Marigold's readable name.")
		return
	if int(marigold.get("supply_deliveries", 0)) != 1:
		_fail("Helped-agent receipt did not count Marigold's delivered supply.")
		return

	var formatted := str(scene.call("_format_day_summary", summary))
	if not formatted.contains("helped Marigold"):
		_fail("Formatted day summary did not call out Marigold help.")
		return

	scene.queue_free()
	await process_frame
	quit()


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
