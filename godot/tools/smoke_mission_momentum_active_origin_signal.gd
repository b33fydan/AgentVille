extends SceneTree

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_mission_momentum_origin_surfaces_while_work_is_active()
	if not _failed:
		quit()


func _test_mission_momentum_origin_surfaces_while_work_is_active() -> void:
	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var agent_manager = scene.get_node("FarmWorld/AgentManager")
	var marigold = _agent_actor(scene, "marigold")
	if marigold == null:
		_fail("Could not find Marigold for active Mission Momentum origin signal check.")
		return

	marigold.call("start_directive", "clear_brush", Vector2i(4, 1), "mission momentum work", {
		"social_preference_source": "completed_mission",
		"social_preference_label": "Marigold Growth Run",
		"social_preference_origin_source": "ignored_ask",
		"social_preference_origin_label": "Seed Bundle"
	})

	var game_ui = scene.get_node("GameUI")
	game_ui.set_agent_snapshots(agent_manager.call("get_agent_snapshots"))
	await process_frame

	var snapshot := _agent_snapshot(agent_manager, "marigold")
	if str(snapshot.get("active_social_preference_origin_source", "")) != "ignored_ask":
		_fail("Active snapshot did not preserve Mission Momentum origin source. saw=%s" % str(snapshot))
		return
	if str(snapshot.get("active_social_preference_origin_label", "")) != "Seed Bundle":
		_fail("Active snapshot did not preserve Mission Momentum origin label. saw=%s" % str(snapshot))
		return

	var social_label := _crew_social_label(scene, "marigold")
	if social_label == null or not social_label.visible:
		_fail("Crew row did not expose active Mission Momentum work.")
		return
	var text := str(social_label.text)
	if not text.contains("Momentum work") or not text.contains("Marigold Growth Run"):
		_fail("Crew row did not name active Mission Momentum work. saw=%s" % text)
		return
	if not text.contains("Pressure: Seed Bundle"):
		_fail("Crew row did not show readable Mission Momentum origin context. saw=%s" % text)
		return
	if text.contains("ignored_ask"):
		_fail("Crew row leaked raw Mission Momentum origin context. saw=%s" % text)
		return

	scene.queue_free()
	await process_frame


func _agent_actor(scene: Node, agent_id: String):
	var agent_manager = scene.get_node("FarmWorld/AgentManager")
	for agent in agent_manager.agents:
		if str(agent.get("agent_id")) == agent_id:
			return agent
	return null


func _agent_snapshot(agent_manager, agent_id: String) -> Dictionary:
	for snapshot in agent_manager.call("get_agent_snapshots"):
		if typeof(snapshot) == TYPE_DICTIONARY and str(snapshot.get("id", "")) == agent_id:
			return snapshot
	return {}


func _crew_social_label(scene: Node, agent_id: String) -> Label:
	var game_ui = scene.get_node("GameUI")
	var rows: Dictionary = game_ui.get("_crew_rows")
	if not rows.has(agent_id):
		return null
	var row: Dictionary = rows[agent_id]
	return row.get("social", null) as Label


func _fail(message: String) -> void:
	_failed = true
	push_error(message)
	quit(1)
