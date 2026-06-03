extends SceneTree

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_mission_momentum_queue_receipt_keeps_origin_context()
	if not _failed:
		quit()


func _test_mission_momentum_queue_receipt_keeps_origin_context() -> void:
	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var grid = scene.get_node("FarmWorld/GridManager")
	var target := Vector2i(8, 4)
	var tile = grid.get_tile(target)
	if tile == null:
		_fail("Smoke setup could not find the Mission Momentum queue target tile.")
		return
	tile.erase()
	tile.place_item("tall_grass")

	var demand_id := str(scene.call("_create_crafting_demand", {
		"kind": "clear_brush",
		"required_action": "clear_brush",
		"amount": 1,
		"label": "Clear Brush",
		"target_tile": target,
		"preference_source": "completed_mission",
		"preference_label": "Chuck Cleanup Sprint",
		"preference_origin_source": "ignored_ask",
		"preference_origin_label": "Rush Kit"
	}, {
		"agent_id": "chuck",
		"agent_name": "Chuck"
	}))
	if demand_id == "":
		_fail("Smoke setup did not create a Mission Momentum field demand.")
		return

	var order_id := str(scene.call("_maybe_author_work_order_for_demand", demand_id))
	if order_id == "" or not scene.work_orders.has(order_id):
		_fail("Mission Momentum demand did not author a linked work order.")
		return

	scene.call("_on_work_order_requested", order_id)
	await process_frame

	var log_entries: Array = scene.game_ui.get("_field_log_entries")
	if log_entries.is_empty():
		_fail("Mission Momentum queue did not write a Field Log receipt.")
		return
	var receipt := _queued_receipt(log_entries)
	if receipt == "":
		_fail("Field Log did not include the queued work receipt. saw=%s" % str(log_entries))
		return
	if not receipt.contains("[Momentum: Chuck Cleanup Sprint]"):
		_fail("Queued work receipt did not name Mission Momentum context. saw=%s" % receipt)
		return
	if not receipt.contains("[Pressure: Rush Kit]"):
		_fail("Queued work receipt did not name readable origin context. saw=%s" % receipt)
		return
	if receipt.contains("ignored_ask"):
		_fail("Queued work receipt leaked raw origin context. saw=%s" % receipt)
		return

	scene.queue_free()
	await process_frame


func _queued_receipt(log_entries: Array) -> String:
	for entry in log_entries:
		var text := str(entry)
		if text.contains("Work order queued"):
			return text
	return ""


func _fail(message: String) -> void:
	_failed = true
	push_error(message)
	quit(1)
