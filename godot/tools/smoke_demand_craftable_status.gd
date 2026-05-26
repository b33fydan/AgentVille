extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var demand_id := str(scene.call("_create_crafting_demand", {
		"kind": "deliver_item",
		"required_item": "rush_kit",
		"amount": 1,
		"label": "Deliver Rush Kit",
		"reason": "Chuck wants to know if the rush supply is craftable."
	}, {
		"agent_id": "chuck",
		"agent_name": "Chuck"
	}))
	if demand_id == "":
		_fail("Smoke setup could not create a Rush Kit demand.")
		return

	var snapshot: Dictionary = scene.call("_crafting_demand_snapshot", demand_id)
	if str(snapshot.get("status_text", "")) != "Needs Rush Kit":
		_fail("Rush Kit demand should start in a missing-item state.")
		return

	scene.call("_add_resources", {
		"fiber": 1
	})
	await process_frame
	snapshot = scene.call("_crafting_demand_snapshot", demand_id)
	if str(snapshot.get("status_text", "")) != "Needs Rush Kit":
		_fail("Rush Kit demand became craftable with only partial resources.")
		return

	scene.call("_add_resources", {
		"stone": 1
	})
	await process_frame
	snapshot = scene.call("_crafting_demand_snapshot", demand_id)
	if str(snapshot.get("status_text", "")) != "Can craft":
		_fail("Rush Kit demand did not show the craftable state when ingredients were available.")
		return
	if not bool(snapshot.get("can_craft_required_item", false)):
		_fail("Rush Kit demand snapshot did not expose can_craft_required_item.")
		return

	var game_ui = scene.get_node("GameUI")
	var rows: Dictionary = game_ui.get("_crafting_demand_rows")
	if not rows.has(demand_id):
		_fail("Demand row was not visible for the craftable Rush Kit demand.")
		return

	var row: Dictionary = rows[demand_id]
	var status_label := row["status"] as Label
	if status_label == null or str(status_label.text) != "Can craft":
		_fail("Demand row did not display the craftable Rush Kit state.")
		return

	scene.queue_free()
	await process_frame
	quit()


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
