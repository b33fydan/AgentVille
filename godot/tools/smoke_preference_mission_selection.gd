extends SceneTree

const AdversarialSessionManagerScript := preload("res://scripts/ai/AdversarialSessionManager.gd")

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_preference_context_selects_mission_arcs()
	if not _failed:
		quit()


func _test_preference_context_selects_mission_arcs() -> void:
	var cases := [
		{
			"agent_id": "marigold",
			"name": "Marigold",
			"trait": "hopeful",
			"remembered_help_label": "Seed Bundle",
			"remembered_help_days": 1,
			"expected_label": "Marigold Growth Run",
			"expected_steps": ["clear_brush", "harvest_crop"]
		},
		{
			"agent_id": "bert",
			"name": "Bert",
			"trait": "grizzled",
			"truce_label": "Fence Kit",
			"truce_days": 1,
			"expected_label": "Bert Boundary Run",
			"expected_steps": ["clear_brush", "build_fence"]
		},
		{
			"agent_id": "chuck",
			"name": "Chuck",
			"trait": "chaotic",
			"memory_consequence_source": "ignored_ask",
			"memory_consequence_label": "Rush Kit",
			"memory_consequence_days": 1,
			"expected_label": "Chuck Cleanup Sprint",
			"expected_steps": ["clear_brush", "clear_brush"]
		},
		{
			"agent_id": "marigold",
			"name": "Marigold",
			"trait": "hopeful",
			"memory_consequence_source": "completed_mission",
			"memory_consequence_label": "Marigold Growth Run",
			"memory_consequence_days": 1,
			"expected_label": "Marigold Growth Run",
			"expected_steps": ["clear_brush", "harvest_crop"]
		}
	]

	for test_case in cases:
		var result := _resolved_preference_run_result(test_case)
		var mission: Dictionary = result.get("crew_mission", {})
		if mission.is_empty():
			_fail("%s preference context did not select a crew mission." % str(test_case.get("name", "Crew")))
			return
		var expected_label := str(test_case.get("expected_label", ""))
		if str(mission.get("label", "")) != expected_label:
			_fail("Preference mission selected %s, expected %s." % [str(mission.get("label", "")), expected_label])
			return
		if not _mission_step_kinds_match(mission.get("steps", []), test_case.get("expected_steps", [])):
			_fail("Preference mission %s did not use expected steps. saw=%s" % [expected_label, str(mission.get("steps", []))])
			return
		if not result.get("crafting_demand", {}).is_empty():
			_fail("Preference mission result also created a standalone crafting demand.")
			return


func _resolved_preference_run_result(agent_snapshot: Dictionary) -> Dictionary:
	var manager = AdversarialSessionManagerScript.new()
	manager.start_session(agent_snapshot, {
		"day": 5,
		"demand_hint": "preference_run",
		"mission_hint": "preference_run",
		"grievance_text": "%s wants the next mission to reflect recent context." % str(agent_snapshot.get("name", "Crew")),
		"npc_goal": "turn memory into a practical mission arc"
	})
	manager.choose_response("own_mistake")
	return manager.choose_response("own_mistake")


func _mission_step_kinds_match(steps, expected_steps) -> bool:
	if typeof(steps) != TYPE_ARRAY or typeof(expected_steps) != TYPE_ARRAY:
		return false
	if steps.size() != expected_steps.size():
		return false
	for index in range(steps.size()):
		if typeof(steps[index]) != TYPE_DICTIONARY:
			return false
		if str(steps[index].get("kind", "")) != str(expected_steps[index]):
			return false
	return true


func _fail(message: String) -> void:
	_failed = true
	push_error(message)
	quit(1)
