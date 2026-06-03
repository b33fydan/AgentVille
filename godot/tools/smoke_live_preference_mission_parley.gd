extends SceneTree

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_live_consequence_parley_proposes_preference_mission()
	if not _failed:
		quit()


func _test_live_consequence_parley_proposes_preference_mission() -> void:
	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var chuck = _agent_actor(scene, "chuck")
	if chuck == null:
		_fail("Could not find Chuck for live preference mission setup.")
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
		_fail("Live consequence Parley did not create a preference-selected mission.")
		return
	var mission: Dictionary = scene.crew_missions.get(mission_id, {})
	if str(mission.get("agent_id", "")) != "chuck":
		_fail("Preference-selected mission did not preserve Chuck as the author.")
		return
	if str(mission.get("label", "")) != "Chuck Cleanup Sprint":
		_fail("Ignored Rush Kit consequence did not select Chuck's Cleanup Sprint. saw=%s" % str(mission.get("label", "")))
		return
	if int(mission.get("total_steps", 0)) != 2:
		_fail("Preference-selected cleanup mission did not create two steps.")
		return

	var first_demand := _latest_open_mission_demand(scene, mission_id)
	if first_demand.is_empty() or str(first_demand.get("kind", "")) != "clear_brush":
		_fail("Preference-selected cleanup mission did not open with brush clearing.")
		return
	if _latest_open_standalone_demand(scene, "chuck") != "":
		_fail("Live consequence Parley created a standalone demand alongside the preference mission.")
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


func _latest_open_mission_demand(scene: Node, mission_id: String) -> Dictionary:
	var demand_ids: Array = scene.get("crafting_demand_ids")
	var demands: Dictionary = scene.get("crafting_demands")
	for index in range(demand_ids.size() - 1, -1, -1):
		var demand_id := str(demand_ids[index])
		var demand: Dictionary = demands.get(demand_id, {})
		if str(demand.get("status", "")) == "open" and str(demand.get("mission_id", "")) == mission_id:
			return demand
	return {}


func _latest_open_standalone_demand(scene: Node, agent_id: String) -> String:
	var demand_ids: Array = scene.get("crafting_demand_ids")
	var demands: Dictionary = scene.get("crafting_demands")
	for index in range(demand_ids.size() - 1, -1, -1):
		var demand_id := str(demand_ids[index])
		var demand: Dictionary = demands.get(demand_id, {})
		if str(demand.get("status", "")) == "open" and str(demand.get("agent_id", "")) == agent_id and str(demand.get("mission_id", "")) == "":
			return demand_id
	return ""


func _fail(message: String) -> void:
	_failed = true
	push_error(message)
	quit(1)
