extends SceneTree

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_preference_mission_keeps_source_context()
	if not _failed:
		quit()


func _test_preference_mission_keeps_source_context() -> void:
	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var chuck = _agent_actor(scene, "chuck")
	if chuck == null:
		_fail("Could not find Chuck for mission context setup.")
		return

	chuck.state["memory_consequence_source"] = "ignored_ask"
	chuck.state["memory_consequence_label"] = "Rush Kit"
	chuck.state["memory_consequence_days"] = 1

	scene.call("_on_adversarial_encounter_requested", "chuck")
	await process_frame
	scene.call("_on_adversarial_response_selected", "own_mistake")
	await process_frame
	scene.call("_on_adversarial_response_selected", "own_mistake")
	await process_frame
	await process_frame

	var mission_id := _latest_mission_id(scene)
	if mission_id == "":
		_fail("Live consequence Parley did not create a mission for context check.")
		return

	var mission: Dictionary = scene.crew_missions.get(mission_id, {})
	if str(mission.get("preference_source", "")) != "ignored_ask":
		_fail("Preference mission did not preserve pressure source. saw=%s" % str(mission.get("preference_source", "")))
		return
	if str(mission.get("preference_label", "")) != "Rush Kit":
		_fail("Preference mission did not preserve Rush Kit label.")
		return

	var summary: Dictionary = scene.get_node("GameEventLog").call("build_day_summary", scene.grid_manager.day)
	var mission_receipt: Dictionary = summary.get("crew_missions", {}).get(mission_id, {})
	if str(mission_receipt.get("preference_source", "")) != "ignored_ask" or str(mission_receipt.get("preference_label", "")) != "Rush Kit":
		_fail("Mission summary did not preserve source context. saw=%s" % str(mission_receipt))
		return

	var context_label := _mission_context_label(scene, mission_id)
	if context_label == null or not context_label.visible:
		_fail("Mission tracker did not show a context label.")
		return
	if str(context_label.text) != "Pressure":
		_fail("Mission tracker context label did not use readable pressure text. saw=%s" % str(context_label.text))
		return
	if not str(context_label.tooltip_text).contains("Rush Kit"):
		_fail("Mission tracker context tooltip did not name the Rush Kit source.")
		return

	scene.queue_free()
	await process_frame


func _agent_actor(scene: Node, agent_id: String):
	var agent_manager = scene.get_node("FarmWorld/AgentManager")
	for agent in agent_manager.agents:
		if str(agent.get("agent_id")) == agent_id:
			return agent
	return null


func _latest_mission_id(scene: Node) -> String:
	if scene.crew_mission_ids.is_empty():
		return ""
	return str(scene.crew_mission_ids.back())


func _mission_context_label(scene: Node, mission_id: String) -> Label:
	var rows: Dictionary = scene.game_ui.get("_crew_mission_rows")
	if not rows.has(mission_id):
		return null
	var row: Dictionary = rows[mission_id]
	return row.get("context", null) as Label


func _fail(message: String) -> void:
	_failed = true
	push_error(message)
	quit(1)
