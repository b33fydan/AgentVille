extends SceneTree

const AgentMemoryScript := preload("res://scripts/ai/AgentMemory.gd")
const UtilityAgentDecisionModelScript := preload("res://scripts/ai/UtilityAgentDecisionModel.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_remembered_seed_help_biases_harvest()
	_test_truce_rush_biases_brush_clearing()
	_test_fence_memory_biases_boundary_checks()
	_test_plain_utility_still_prefers_ready_crops()
	quit()


func _test_remembered_seed_help_biases_harvest() -> void:
	var decision := _decision(
		_agent_state("marigold", "Marigold", "hopeful", {
			"remembered_help_label": "Seed Bundle",
			"remembered_help_days": 1
		}),
		_world({
			"ready_crops": 1,
			"ready_tile": Vector2i(6, 4),
			"brush_tiles": 1,
			"brush_tile": Vector2i(1, 1)
		})
	)
	if str(decision.get("action", "")) != "harvest_crop":
		_fail("Remembered Seed Bundle did not bias Marigold toward harvest work.")
		return
	if decision.get("target_tile", Vector2i.ZERO) != Vector2i(6, 4):
		_fail("Remembered harvest preference did not keep the ready crop target.")
		return
	if not str(decision.get("reason", "")).contains("memory"):
		_fail("Remembered harvest preference did not record a memory reason.")
		return


func _test_truce_rush_biases_brush_clearing() -> void:
	var decision := _decision(
		_agent_state("chuck", "Chuck", "chaotic", {
			"truce_label": "Rush Kit",
			"truce_days": 1
		}),
		_world({
			"ready_crops": 1,
			"ready_tile": Vector2i(7, 7),
			"brush_tiles": 2,
			"brush_tile": Vector2i(2, 3)
		})
	)
	if str(decision.get("action", "")) != "clear_brush":
		_fail("Rush Kit truce did not bias Chuck toward brush clearing.")
		return
	if decision.get("target_tile", Vector2i.ZERO) != Vector2i(2, 3):
		_fail("Brush-clearing truce preference did not keep the brush target.")
		return
	if not str(decision.get("reason", "")).contains("truce"):
		_fail("Brush-clearing preference did not record a truce reason.")
		return


func _test_fence_memory_biases_boundary_checks() -> void:
	var decision := _decision(
		_agent_state("bert", "Bert", "grizzled", {
			"remembered_help_label": "Fence Kit",
			"remembered_help_days": 1
		}),
		_world({
			"ready_crops": 1,
			"ready_tile": Vector2i(8, 2),
			"structures": 1,
			"structure_tile": Vector2i(4, 5)
		})
	)
	if str(decision.get("action", "")) != "inspect_structure":
		_fail("Fence Kit memory did not bias Bert toward boundary checks.")
		return
	if decision.get("target_tile", Vector2i.ZERO) != Vector2i(4, 5):
		_fail("Fence memory preference did not keep the structure target.")
		return


func _test_plain_utility_still_prefers_ready_crops() -> void:
	var decision := _decision(
		_agent_state("marigold", "Marigold", "hopeful"),
		_world({
			"ready_crops": 1,
			"ready_tile": Vector2i(5, 6),
			"brush_tiles": 1,
			"brush_tile": Vector2i(1, 2)
		})
	)
	if str(decision.get("action", "")) != "harvest_crop":
		_fail("Plain utility stopped preferring ready crops.")
		return
	if str(decision.get("reason", "")).contains("memory") or str(decision.get("reason", "")).contains("truce"):
		_fail("Plain utility should not carry social preference context.")
		return


func _decision(agent_state: Dictionary, world: Dictionary) -> Dictionary:
	var model = UtilityAgentDecisionModelScript.new()
	var memory = AgentMemoryScript.new()
	return model.decide(agent_state, world, memory)


func _agent_state(agent_id: String, agent_name: String, personality_trait: String, extra: Dictionary = {}) -> Dictionary:
	var state := {
		"id": agent_id,
		"name": agent_name,
		"trait": personality_trait,
		"energy": 80.0,
		"mood": 60.0,
		"irritation": 0.0,
		"remembered_help_label": "",
		"remembered_help_days": 0,
		"truce_label": "",
		"truce_days": 0
	}
	for key in extra.keys():
		state[key] = extra[key]
	return state


func _world(extra: Dictionary = {}) -> Dictionary:
	var world := {
		"home_tile": Vector2i.ZERO,
		"ready_crops": 0,
		"ready_tile": Vector2i.ZERO,
		"growing_crops": 0,
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
	push_error(message)
	quit(1)
