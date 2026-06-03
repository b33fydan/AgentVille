extends SceneTree

const AdversarialSessionManagerScript := preload("res://scripts/ai/AdversarialSessionManager.gd")

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_mission_momentum_ask_keeps_origin_context()
	if not _failed:
		quit()


func _test_mission_momentum_ask_keeps_origin_context() -> void:
	var demand := _resolved_supply_demand({
		"id": "chuck",
		"name": "Chuck",
		"trait": "chaotic",
		"irritation": 26.0,
		"memory_consequence_source": "completed_mission",
		"memory_consequence_label": "Chuck Cleanup Sprint",
		"memory_consequence_origin_source": "ignored_ask",
		"memory_consequence_origin_label": "Rush Kit",
		"memory_consequence_days": 1
	})
	if demand.is_empty():
		_fail("Mission momentum did not create a follow-up ask.")
		return
	if str(demand.get("preference_source", "")) != "completed_mission":
		_fail("Mission momentum ask did not preserve its momentum source.")
		return
	if str(demand.get("preference_label", "")) != "Chuck Cleanup Sprint":
		_fail("Mission momentum ask did not preserve the completed mission label.")
		return
	if str(demand.get("preference_origin_source", "")) != "ignored_ask":
		_fail("Mission momentum ask did not preserve the original pressure source. saw=%s" % str(demand))
		return
	if str(demand.get("preference_origin_label", "")) != "Rush Kit":
		_fail("Mission momentum ask did not preserve the original Rush Kit label.")
		return
	if not str(demand.get("reason", "")).contains("Pressure: Rush Kit"):
		_fail("Mission momentum ask reason did not name readable origin context. saw=%s" % str(demand.get("reason", "")))
		return
	if str(demand.get("reason", "")).contains("ignored_ask"):
		_fail("Mission momentum ask reason leaked raw origin context. saw=%s" % str(demand.get("reason", "")))
		return

	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	scene.call("_apply_adversarial_result", {
		"outcome": "resolved",
		"agent_id": "chuck",
		"agent_name": "Chuck",
		"crafting_demand": demand
	})
	await process_frame
	await process_frame

	var demand_id := str(demand.get("id", ""))
	if demand_id == "":
		demand_id = _latest_demand_id(scene)
	var preference_label := _demand_preference_label(scene, demand_id)
	if preference_label == null or not preference_label.visible:
		_fail("Demand row did not show a Mission Momentum preference chip.")
		return
	if str(preference_label.text) != "Momentum":
		_fail("Demand row used the wrong preference chip. saw=%s" % str(preference_label.text))
		return
	if not str(preference_label.tooltip_text).contains("Mission momentum: Chuck Cleanup Sprint"):
		_fail("Demand tooltip did not name the completed mission. saw=%s" % str(preference_label.tooltip_text))
		return
	if not str(preference_label.tooltip_text).contains("Pressure: Rush Kit"):
		_fail("Demand tooltip did not preserve readable origin context. saw=%s" % str(preference_label.tooltip_text))
		return
	if str(preference_label.tooltip_text).contains("ignored_ask"):
		_fail("Demand tooltip leaked raw origin context. saw=%s" % str(preference_label.tooltip_text))
		return

	var game_ui = scene.get_node("GameUI")
	game_ui.call("set_work_orders", [{
		"id": "origin_order",
		"label": "Chuck: Clear 1,1",
		"status": "ready",
		"action": "clear_brush",
		"can_progress": true,
		"preference_source": "completed_mission",
		"preference_label": "Chuck Cleanup Sprint",
		"preference_origin_source": "ignored_ask",
		"preference_origin_label": "Rush Kit",
		"social_preference_source": "completed_mission",
		"social_preference_label": "Chuck Cleanup Sprint"
	}])
	await process_frame
	var order_preference_label := _work_order_preference_label(scene, "origin_order")
	if order_preference_label == null or not order_preference_label.visible:
		_fail("Work-order row did not show a Mission Momentum preference chip.")
		return
	if str(order_preference_label.text) != "Momentum":
		_fail("Work-order row used the wrong preference chip. saw=%s" % str(order_preference_label.text))
		return
	if not str(order_preference_label.tooltip_text).contains("Pressure: Rush Kit"):
		_fail("Work-order tooltip did not preserve readable origin context. saw=%s" % str(order_preference_label.tooltip_text))
		return
	if str(order_preference_label.tooltip_text).contains("ignored_ask"):
		_fail("Work-order tooltip leaked raw origin context. saw=%s" % str(order_preference_label.tooltip_text))
		return

	scene.queue_free()
	await process_frame


func _resolved_supply_demand(agent_snapshot: Dictionary) -> Dictionary:
	var manager = AdversarialSessionManagerScript.new()
	manager.start_session(agent_snapshot, {
		"day": 8,
		"demand_hint": "deliver_agent_supply",
		"recent_failures": 1
	})
	manager.choose_response("own_mistake")
	var result: Dictionary = manager.choose_response("own_mistake")
	return result.get("crafting_demand", {})


func _latest_demand_id(scene: Node) -> String:
	var demand_ids: Array = scene.get("crafting_demand_ids")
	if demand_ids.is_empty():
		return ""
	return str(demand_ids.back())


func _demand_preference_label(scene: Node, demand_id: String) -> Label:
	var game_ui = scene.get_node("GameUI")
	var rows: Dictionary = game_ui.get("_crafting_demand_rows")
	if not rows.has(demand_id):
		return null
	var row: Dictionary = rows[demand_id]
	return row.get("preference", null) as Label


func _work_order_preference_label(scene: Node, order_id: String) -> Label:
	var game_ui = scene.get_node("GameUI")
	var rows: Dictionary = game_ui.get("_work_order_rows")
	if not rows.has(order_id):
		return null
	var row: Dictionary = rows[order_id]
	return row.get("preference", null) as Label


func _fail(message: String) -> void:
	_failed = true
	push_error(message)
	quit(1)
