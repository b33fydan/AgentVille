extends SceneTree

const AgentMemoryScript := preload("res://scripts/ai/AgentMemory.gd")
const UtilityAgentDecisionModelScript := preload("res://scripts/ai/UtilityAgentDecisionModel.gd")

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_consequence_memory_biases_autonomous_work()
	if not _failed:
		quit()


func _test_consequence_memory_biases_autonomous_work() -> void:
	var cases := [
		{
			"agent_id": "marigold",
			"agent_name": "Marigold",
			"trait": "hopeful",
			"source": "repeated_help",
			"label": "Seed Bundle",
			"expected_action": "harvest_crop",
			"expected_context": "Streak",
			"world": {
				"ready_crops": 1,
				"ready_tile": Vector2i(6, 4),
				"brush_tiles": 1,
				"brush_tile": Vector2i(2, 2)
			}
		},
		{
			"agent_id": "bert",
			"agent_name": "Bert",
			"trait": "grizzled",
			"source": "completed_order",
			"label": "Clear Brush",
			"expected_action": "clear_brush",
			"expected_context": "Follow-up",
			"world": {
				"ready_crops": 1,
				"ready_tile": Vector2i(7, 7),
				"brush_tiles": 1,
				"brush_tile": Vector2i(3, 3)
			}
		},
		{
			"agent_id": "marigold",
			"agent_name": "Marigold",
			"trait": "hopeful",
			"source": "completed_mission",
			"label": "Marigold Growth Run",
			"expected_action": "harvest_crop",
			"expected_context": "Momentum",
			"world": {
				"ready_crops": 1,
				"ready_tile": Vector2i(5, 6),
				"brush_tiles": 1,
				"brush_tile": Vector2i(1, 1)
			}
		},
		{
			"agent_id": "chuck",
			"agent_name": "Chuck",
			"trait": "chaotic",
			"source": "ignored_ask",
			"label": "Rush Kit",
			"expected_action": "clear_brush",
			"expected_context": "Pressure",
			"world": {
				"ready_crops": 1,
				"ready_tile": Vector2i(6, 6),
				"brush_tiles": 1,
				"brush_tile": Vector2i(2, 3)
			}
		},
		{
			"agent_id": "bert",
			"agent_name": "Bert",
			"trait": "grizzled",
			"source": "held_truce",
			"label": "Fence Kit",
			"expected_action": "inspect_structure",
			"expected_context": "Held",
			"world": {
				"ready_crops": 1,
				"ready_tile": Vector2i(8, 8),
				"structures": 1,
				"structure_tile": Vector2i(4, 5)
			}
		}
	]

	for test_case in cases:
		var source := str(test_case.get("source", ""))
		var label := str(test_case.get("label", ""))
		var decision := _decision(
			_agent_state(
				str(test_case.get("agent_id", "")),
				str(test_case.get("agent_name", "")),
				str(test_case.get("trait", "")),
				source,
				label
			),
			_world(test_case.get("world", {}))
		)
		if str(decision.get("action", "")) != str(test_case.get("expected_action", "")):
			_fail("%s consequence did not bias autonomous work toward %s. saw=%s" % [source, str(test_case.get("expected_action", "")), str(decision.get("action", ""))])
			return
		if str(decision.get("social_preference_source", "")) != source or str(decision.get("social_preference_label", "")) != label:
			_fail("%s consequence autonomy did not carry social preference metadata." % source)
			return
		var comment := str(decision.get("comment", ""))
		if not comment.contains(str(test_case.get("expected_context", ""))):
			_fail("%s consequence comment did not use readable %s context. saw=%s" % [source, str(test_case.get("expected_context", "")), comment])
			return
		if comment.contains("Memory says"):
			_fail("%s consequence autonomy fell back to generic Memory copy. saw=%s" % [source, comment])
			return


func _decision(agent_state: Dictionary, world: Dictionary) -> Dictionary:
	var model = UtilityAgentDecisionModelScript.new()
	var memory = AgentMemoryScript.new()
	return model.decide(agent_state, world, memory)


func _agent_state(agent_id: String, agent_name: String, personality_trait: String, source: String, label: String) -> Dictionary:
	return {
		"id": agent_id,
		"name": agent_name,
		"trait": personality_trait,
		"energy": 80.0,
		"mood": 60.0,
		"irritation": 0.0,
		"remembered_help_label": "",
		"remembered_help_days": 0,
		"truce_label": "",
		"truce_days": 0,
		"memory_consequence_source": source,
		"memory_consequence_label": label,
		"memory_consequence_days": 1,
		"daily_intention_id": "",
		"daily_intention_label": "",
		"daily_intention_focus": ""
	}


func _world(extra: Dictionary = {}) -> Dictionary:
	var world := {
		"home_tile": Vector2i.ZERO,
		"ready_crops": 0,
		"ready_tile": Vector2i.ZERO,
		"growing_crops": 0,
		"growing_tile": Vector2i.ZERO,
		"empty_soil": 0,
		"soil_tile": Vector2i.ZERO,
		"brush_tiles": 0,
		"brush_tile": Vector2i.ZERO,
		"structures": 0,
		"structure_tile": Vector2i.ZERO,
		"wander_tile": Vector2i(1, 1)
	}
	for key in extra.keys():
		world[key] = extra[key]
	return world


func _fail(message: String) -> void:
	_failed = true
	push_error(message)
	quit(1)
