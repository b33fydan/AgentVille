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
		"reason": "Chuck wants the row to explain what is missing."
	}, {
		"agent_id": "chuck",
		"agent_name": "Chuck"
	}))
	if demand_id == "":
		_fail("Smoke setup could not create a Rush Kit demand.")
		return

	var snapshot: Dictionary = scene.call("_crafting_demand_snapshot", demand_id)
	if str(snapshot.get("missing_resource_text", "")) != "1 Fiber, 1 Stone":
		_fail("Rush Kit demand did not summarize all missing ingredients.")
		return
	if not _assert_wait_tooltip(scene, demand_id, ["1 Fiber", "1 Stone"], []):
		return

	scene.call("_add_resources", {
		"fiber": 1
	})
	await process_frame

	snapshot = scene.call("_crafting_demand_snapshot", demand_id)
	if str(snapshot.get("missing_resource_text", "")) != "1 Stone":
		_fail("Rush Kit demand did not narrow its missing ingredient summary after Fiber arrived.")
		return
	if not _assert_wait_tooltip(scene, demand_id, ["1 Stone"], ["Fiber"]):
		return

	scene.queue_free()
	await process_frame
	quit()


func _assert_wait_tooltip(scene: Node, demand_id: String, expected_parts: Array, rejected_parts: Array) -> bool:
	var button := _demand_button(scene, demand_id)
	if button == null:
		_fail("Missing supply demand did not expose a Wait button.")
		return false
	if button.text != "Wait" or not button.disabled:
		_fail("Missing supply demand did not present a disabled Wait action.")
		return false

	var tooltip := str(button.tooltip_text)
	for expected in expected_parts:
		if not tooltip.contains(str(expected)):
			_fail("Wait tooltip did not include %s. saw=%s" % [str(expected), tooltip])
			return false
	for rejected in rejected_parts:
		if tooltip.contains(str(rejected)):
			_fail("Wait tooltip still included %s. saw=%s" % [str(rejected), tooltip])
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
