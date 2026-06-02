extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var game_ui = scene.get_node("GameUI")
	var orders := [
		_order("row_memory", "memory", "Old Help", "Memory"),
		_order("row_truce", "truce", "Rush Kit", "Truce"),
		_order("row_streak", "repeated_help", "Fence Kit", "Streak"),
		_order("row_follow_up", "completed_order", "Chicken Feed", "Follow-up"),
		_order("row_momentum", "completed_mission", "North Field", "Momentum"),
		_order("row_pressure", "ignored_ask", "Brush Clearing", "Pressure"),
		_order("row_held", "held_truce", "Stone Path", "Held")
	]
	game_ui.call("set_work_orders", orders)
	await process_frame

	var rows: Dictionary = game_ui.get("_work_order_rows")
	for order in orders:
		var order_id := str(order.get("id", ""))
		if not rows.has(order_id):
			_fail("Work order row missing for %s." % order_id)
			return
		var row: Dictionary = rows[order_id]
		if not row.has("preference"):
			_fail("Work order row for %s does not expose a preference context label." % order_id)
			return
		var preference := row.get("preference", null) as Label
		if preference == null or not preference.visible:
			_fail("Work order row for %s did not show a visible preference context." % order_id)
			return
		var expected := str(order.get("_expected_context", ""))
		var saw := str(preference.text)
		if saw != expected:
			_fail("Work order row for %s showed %s, expected %s." % [order_id, saw, expected])
			return
		if saw.contains("_") or saw == str(order.get("preference_source", "")):
			_fail("Work order row for %s showed a raw preference source: %s." % [order_id, saw])
			return

	scene.queue_free()
	await process_frame
	quit()


func _order(order_id: String, source: String, label: String, expected_context: String) -> Dictionary:
	return {
		"id": order_id,
		"label": label,
		"status": "ready",
		"action": "clear_brush",
		"can_progress": true,
		"preference_source": source,
		"preference_label": label,
		"social_preference_source": source,
		"social_preference_label": label,
		"_expected_context": expected_context
	}


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
