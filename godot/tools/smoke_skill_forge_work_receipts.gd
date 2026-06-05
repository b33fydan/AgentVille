extends SceneTree

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_forge_order_completion_keeps_skill_context()
	if not _failed:
		quit()


func _test_forge_order_completion_keeps_skill_context() -> void:
	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	root.size = Vector2i(1600, 900)
	await process_frame
	await process_frame

	var game_ui = scene.get_node("GameUI")
	_select_template(game_ui, "clear_patch_starter")
	if _failed:
		return

	var run_button = game_ui.get("_skill_forge_run_button") as Button
	if run_button == null:
		_fail("Skill Forge run button missing before work receipt smoke.")
		return
	run_button.pressed.emit()
	await process_frame

	var order_id := _latest_forge_order_id(scene, "clear_patch_starter")
	if order_id == "" or not scene.work_orders.has(order_id):
		_fail("Clear Patch did not draft a Forge work order for receipt smoke.")
		return
	var order: Dictionary = scene.work_orders[order_id]
	var target_tile: Vector2i = order.get("target_tile", Vector2i(-1, -1))
	var tile = scene.get_node("FarmWorld/GridManager").get_tile(target_tile)
	if tile == null:
		_fail("Forge work-order target tile was missing.")
		return

	var trace_label = game_ui.get("_skill_forge_trace_label") as Label
	if trace_label == null or str(trace_label.text) != "Spec > Directive > Work Order > Harness Receipt":
		_fail("Forge panel did not trace the drafted work order. text=%s" % (trace_label.text if trace_label else ""))
		return

	var agent_manager = scene.get_node("FarmWorld/AgentManager")
	for agent in agent_manager.agents:
		agent.move_speed = 42.0

	scene.call("_on_work_order_requested", order_id)
	await process_frame
	await process_frame

	var queued_field_log_entries: Array = game_ui.get("_field_log_entries")
	if not _entries_contain(queued_field_log_entries, "Work order queued:") or not _entries_contain(queued_field_log_entries, "[Forge: Clear Patch]"):
		_fail("Field Log did not include Forge context when the work order was queued. entries=%s" % str(queued_field_log_entries))
		return

	if _active_agent_badge_text(scene) != "Forge":
		_fail("Assigned Forge work did not show a Forge reason badge. saw=%s" % _active_agent_badge_text(scene))
		return

	await create_timer(1.1).timeout
	if str(tile.decor_id) != "":
		_fail("Forge-authored clear_brush work did not clear the target.")
		return

	var completed_event: Dictionary = _completed_forge_world_action(scene, order)
	if completed_event.is_empty():
		_fail("Completed Forge work did not record a dedicated forge_run_id world action.")
		return
	if str(completed_event.get("skill_name", "")) != "Clear Patch":
		_fail("Completed Forge work did not keep the readable skill name. event=%s" % str(completed_event))
		return
	if str(completed_event.get("social_preference_source", "")) == "skill_forge":
		_fail("Forge work leaked into social-preference event context. event=%s" % str(completed_event))
		return

	var receipt := str(scene.call("_format_agent_receipt", completed_event))
	if not receipt.contains("[Forge: Clear Patch]"):
		_fail("Forge work receipt did not name the Forge skill. saw=%s" % receipt)
		return
	if receipt.contains("skill_forge") or receipt.contains("Skill Forge: Clear Patch"):
		_fail("Forge work receipt used raw or social-style Forge context. saw=%s" % receipt)
		return

	if trace_label == null or str(trace_label.text) != "Spec > Directive > Work Order > Agent Receipt":
		_fail("Forge panel did not trace through the agent receipt endpoint. text=%s" % (trace_label.text if trace_label else ""))
		return
	if not str(trace_label.tooltip_text).contains(receipt):
		_fail("Forge trace tooltip did not preserve the readable agent receipt. tooltip=%s receipt=%s" % [str(trace_label.tooltip_text), receipt])
		return
	if not str(trace_label.tooltip_text).contains("History: Agent Receipt Clear Patch") or not str(trace_label.tooltip_text).contains("Passed Clear Patch"):
		_fail("Forge trace tooltip did not keep recent Forge receipt history. tooltip=%s" % str(trace_label.tooltip_text))
		return

	var summary: Dictionary = scene.get_node("GameEventLog").call("build_day_summary", scene.get_node("FarmWorld/GridManager").day)
	if not _summary_has_forge_work(summary, str(order.get("forge_run_id", "")), "Clear Patch"):
		_fail("Day summary did not keep Forge work context. summary=%s" % str(summary.get("agent_skill_forge_actions", {})))
		return
	if _summary_has_social_skill_forge(summary):
		_fail("Day summary counted Forge work as social preference work. summary=%s" % str(summary.get("agent_social_preference_actions", {})))
		return
	var formatted_summary := str(scene.call("_format_day_summary", summary))
	if not formatted_summary.contains("forge work") or not formatted_summary.contains("Clear Patch"):
		_fail("Formatted day summary did not include Forge work context. saw=%s" % formatted_summary)
		return
	if formatted_summary.contains("skill_forge"):
		_fail("Formatted day summary leaked raw Forge source. saw=%s" % formatted_summary)
		return

	scene.queue_free()
	await process_frame


func _select_template(game_ui, template_id: String) -> void:
	var buttons_value = game_ui.get("_skill_forge_template_buttons")
	if typeof(buttons_value) != TYPE_DICTIONARY:
		_fail("Skill Forge panel did not expose template buttons.")
		return
	var buttons: Dictionary = buttons_value
	var button = buttons.get(template_id, null) as Button
	if button == null:
		_fail("Skill Forge template button missing for %s." % template_id)
		return
	button.pressed.emit()


func _latest_forge_order_id(scene: Node, skill_id: String) -> String:
	for index in range(scene.work_order_ids.size() - 1, -1, -1):
		var order_id := str(scene.work_order_ids[index])
		var order: Dictionary = scene.work_orders.get(order_id, {})
		if str(order.get("source", "")) == "skill_forge" and str(order.get("skill_id", "")) == skill_id:
			return order_id
	return ""


func _active_agent_badge_text(scene: Node) -> String:
	var agent_manager = scene.get_node("FarmWorld/AgentManager")
	for agent in agent_manager.agents:
		if str(agent.state.get("current_action", "idle")) == "idle":
			continue
		var badge = agent.get_node_or_null("VoxelRig/ReasonBadge")
		if badge != null and badge.visible:
			return str(badge.text)
	return ""


func _completed_forge_world_action(scene: Node, order: Dictionary) -> Dictionary:
	var forge_run_id := str(order.get("forge_run_id", ""))
	for event in scene.get_node("GameEventLog").get("events"):
		if typeof(event) != TYPE_DICTIONARY:
			continue
		if str(event.get("type", "")) != "agent_world_action":
			continue
		if not bool(event.get("success", false)):
			continue
		if str(event.get("work_order_id", "")) != str(order.get("id", "")):
			continue
		if str(event.get("forge_run_id", "")) == forge_run_id:
			return event
	return {}


func _entries_contain(entries: Array, needle: String) -> bool:
	for entry in entries:
		if str(entry).contains(needle):
			return true
	return false


func _summary_has_forge_work(summary: Dictionary, forge_run_id: String, skill_name: String) -> bool:
	var forge_actions: Dictionary = summary.get("agent_skill_forge_actions", {})
	for receipt in forge_actions.values():
		if typeof(receipt) != TYPE_DICTIONARY:
			continue
		if str(receipt.get("run_id", "")) == forge_run_id and str(receipt.get("skill_name", "")) == skill_name:
			return true
	return false


func _summary_has_social_skill_forge(summary: Dictionary) -> bool:
	var social_actions: Dictionary = summary.get("agent_social_preference_actions", {})
	for receipt in social_actions.values():
		if typeof(receipt) == TYPE_DICTIONARY and str(receipt.get("last_source", "")) == "skill_forge":
			return true
	return false


func _fail(message: String) -> void:
	_failed = true
	push_error(message)
	quit(1)
