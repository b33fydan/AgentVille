extends SceneTree

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_mission_momentum_has_distinct_crew_and_world_signals()
	if not _failed:
		quit()


func _test_mission_momentum_has_distinct_crew_and_world_signals() -> void:
	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var marigold = _agent_actor(scene, "marigold")
	if marigold == null:
		_fail("Could not find Marigold for mission momentum signal check.")
		return

	marigold.state["memory_consequence_source"] = "completed_mission"
	marigold.state["memory_consequence_label"] = "Marigold Growth Run"
	marigold.state["memory_consequence_days"] = 1
	marigold.state["daily_intention_id"] = "mission_momentum"
	marigold.state["daily_intention_label"] = "Mission Momentum"
	marigold.state["daily_intention_focus"] = "grow"
	marigold.call("_refresh_reason_badge")

	var agent_manager = scene.get_node("FarmWorld/AgentManager")
	var game_ui = scene.get("game_ui")
	game_ui.set_agent_snapshots(agent_manager.call("get_agent_snapshots"))
	await process_frame

	var social_label := _crew_social_label(scene, "marigold")
	if social_label == null or not social_label.visible:
		_fail("Crew row did not expose Marigold's mission momentum signal.")
		return
	if not str(social_label.text).contains("Mission momentum"):
		_fail("Mission momentum crew signal used the generic daily plan label. saw=%s" % str(social_label.text))
		return
	if not str(social_label.text).contains("Marigold Growth Run"):
		_fail("Mission momentum crew signal did not preserve the completed mission label. saw=%s" % str(social_label.text))
		return
	if str(social_label.text).contains("Plan"):
		_fail("Mission momentum crew signal should not read as a generic Plan. saw=%s" % str(social_label.text))
		return

	var badge = marigold.get_node_or_null("VoxelRig/ReasonBadge")
	if badge == null or not badge.visible or str(badge.text) != "Momentum":
		_fail("Mission momentum did not show a distinct Momentum reason badge.")
		return

	scene.queue_free()
	await process_frame


func _agent_actor(scene: Node, agent_id: String):
	var agent_manager = scene.get_node("FarmWorld/AgentManager")
	for agent in agent_manager.agents:
		if str(agent.get("agent_id")) == agent_id:
			return agent
	return null


func _crew_social_label(scene: Node, agent_id: String) -> Label:
	var game_ui = scene.get("game_ui")
	var rows: Dictionary = game_ui.get("_crew_rows")
	if not rows.has(agent_id):
		return null
	var row: Dictionary = rows[agent_id]
	return row.get("social", null) as Label


func _fail(message: String) -> void:
	_failed = true
	push_error(message)
	quit(1)
