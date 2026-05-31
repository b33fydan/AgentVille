extends SceneTree

const AgentMemoryScript := preload("res://scripts/ai/AgentMemory.gd")
const UtilityAgentDecisionModelScript := preload("res://scripts/ai/UtilityAgentDecisionModel.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_remembered_seed_help_biases_harvest()
	_test_truce_rush_biases_brush_clearing()
	_test_fence_memory_biases_boundary_checks()
	_test_seed_memory_checks_growing_crops()
	_test_rush_truce_scans_structures_when_no_brush()
	_test_fence_memory_checks_open_ground_when_no_boundary()
	_test_plain_utility_still_prefers_ready_crops()
	if not _test_model_metadata():
		return
	await _test_scene_world_snapshot_exposes_growing_crop()
	await _test_scene_social_preference_receipts()
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
	if str(decision.get("social_preference_source", "")) != "memory" or str(decision.get("social_preference_label", "")) != "Seed Bundle":
		_fail("Remembered harvest preference did not carry social metadata.")
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
	if str(decision.get("social_preference_source", "")) != "truce" or str(decision.get("social_preference_label", "")) != "Rush Kit":
		_fail("Brush-clearing truce preference did not carry social metadata.")
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


func _test_seed_memory_checks_growing_crops() -> void:
	var decision := _decision(
		_agent_state("marigold", "Marigold", "hopeful", {
			"remembered_help_label": "Seed Bundle",
			"remembered_help_days": 1
		}),
		_world({
			"growing_crops": 2,
			"growing_tile": Vector2i(3, 6)
		})
	)
	if str(decision.get("action", "")) != "inspect_ready_crop":
		_fail("Seed memory without ready work did not bias Marigold toward checking growing crops.")
		return
	if decision.get("target_tile", Vector2i.ZERO) != Vector2i(3, 6):
		_fail("Seed memory crop-watch fallback did not keep the growing crop target.")
		return
	if str(decision.get("social_preference_source", "")) != "memory":
		_fail("Seed memory crop-watch fallback did not carry social metadata.")
		return


func _test_rush_truce_scans_structures_when_no_brush() -> void:
	var decision := _decision(
		_agent_state("chuck", "Chuck", "chaotic", {
			"truce_label": "Rush Kit",
			"truce_days": 1
		}),
		_world({
			"structures": 1,
			"structure_tile": Vector2i(7, 1)
		})
	)
	if str(decision.get("action", "")) != "inspect_structure":
		_fail("Rush truce without brush did not bias Chuck toward route inspection.")
		return
	if decision.get("target_tile", Vector2i.ZERO) != Vector2i(7, 1):
		_fail("Rush truce route inspection did not keep the structure target.")
		return
	if str(decision.get("social_preference_source", "")) != "truce":
		_fail("Rush truce route inspection did not carry social metadata.")
		return


func _test_fence_memory_checks_open_ground_when_no_boundary() -> void:
	var decision := _decision(
		_agent_state("bert", "Bert", "grizzled", {
			"remembered_help_label": "Fence Kit",
			"remembered_help_days": 1
		}),
		_world({
			"empty_soil": 1,
			"soil_tile": Vector2i(5, 4)
		})
	)
	if str(decision.get("action", "")) != "inspect_soil":
		_fail("Fence memory without boundary work did not bias Bert toward open-ground checks.")
		return
	if decision.get("target_tile", Vector2i.ZERO) != Vector2i(5, 4):
		_fail("Fence memory open-ground fallback did not keep the soil target.")
		return
	if str(decision.get("social_preference_source", "")) != "memory":
		_fail("Fence memory open-ground fallback did not carry social metadata.")
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
	if str(decision.get("social_preference_source", "")) != "" or str(decision.get("social_preference_label", "")) != "":
		_fail("Plain utility should not carry social preference metadata.")
		return


func _test_model_metadata() -> bool:
	var decision := _decision(
		_agent_state("bert", "Bert", "grizzled", {
			"truce_label": "Fence Kit",
			"truce_days": 1
		}),
		_world({
			"brush_tiles": 1,
			"brush_tile": Vector2i(3, 3)
		})
	)
	if str(decision.get("social_preference_source", "")) != "truce":
		_fail("Fallback fence-space preference did not record truce metadata.")
		return false
	if str(decision.get("social_preference_label", "")) != "Fence Kit":
		_fail("Fallback fence-space preference did not preserve the truce label.")
		return false
	return true


func _test_scene_world_snapshot_exposes_growing_crop() -> void:
	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var grid = scene.get_node("FarmWorld/GridManager")
	var agent_manager = scene.get_node("FarmWorld/AgentManager")
	var agent = agent_manager.agents[1]
	var target := Vector2i(4, 4)
	var tile = grid.get_tile(target)
	if tile == null:
		_fail("Scene growing-crop setup could not find the target tile.")
		return
	tile.erase()
	tile.till()
	tile.plant_corn()
	tile.crop.setup("corn", 1)

	var world: Dictionary = agent.call("_build_world_snapshot")
	if int(world.get("growing_crops", 0)) <= 0:
		_fail("Agent world snapshot did not count growing crops.")
		return
	if not world.has("growing_tile") or world.get("growing_tile", Vector2i(-1, -1)) != target:
		_fail("Agent world snapshot did not expose a nearest growing crop tile.")
		return

	scene.queue_free()
	await process_frame


func _test_scene_social_preference_receipts() -> void:
	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var grid = scene.get_node("FarmWorld/GridManager")
	var agent_manager = scene.get_node("FarmWorld/AgentManager")
	var agent = agent_manager.agents[2]
	agent.move_speed = 36.0

	var target: Vector2i = agent.current_grid_pos
	var tile = grid.get_tile(target)
	if tile == null:
		_fail("Scene social-preference setup could not find Chuck's tile.")
		return
	tile.erase()
	tile.place_item("tall_grass")

	agent.call("_start_decision", {
		"action": "clear_brush",
		"reason": "truce points toward clearing work: Rush Kit",
		"score": 100.0,
		"target_tile": target,
		"comment": "Truce says Rush Kit. The weeds have been notified.",
		"social_preference_source": "truce",
		"social_preference_label": "Rush Kit"
	})
	await create_timer(1.0).timeout

	if str(tile.decor_id) != "":
		_fail("Scene social-preference setup did not complete the brush work.")
		return

	var log = scene.get_node("GameEventLog")
	var saw_agent_action := false
	var saw_world_action := false
	for event in log.get("events"):
		if typeof(event) != TYPE_DICTIONARY:
			continue
		if str(event.get("agent_id", "")) != "chuck":
			continue
		if str(event.get("social_preference_source", "")) != "truce" or str(event.get("social_preference_label", "")) != "Rush Kit":
			continue
		if str(event.get("type", "")) == "agent_action":
			saw_agent_action = true
		elif str(event.get("type", "")) == "agent_world_action" and bool(event.get("success", false)):
			saw_world_action = true
	if not saw_agent_action:
		_fail("Agent action receipt did not preserve social preference metadata.")
		return
	if not saw_world_action:
		_fail("Agent world-action receipt did not preserve social preference metadata.")
		return

	var entries: Array = scene.get_node("GameUI").get("_field_log_entries")
	var saw_field_log := false
	for entry in entries:
		if str(entry).contains("Truce: Rush Kit"):
			saw_field_log = true
			break
	if not saw_field_log:
		_fail("Field Log did not show the social preference context for autonomous work.")
		return

	var summary: Dictionary = log.call("build_day_summary", grid.day)
	var social_actions: Dictionary = summary.get("agent_social_preference_actions", {})
	if not social_actions.has("chuck"):
		_fail("Day summary did not count Chuck's social-preference autonomous work.")
		return
	var chuck_receipt: Dictionary = social_actions.get("chuck", {})
	if str(chuck_receipt.get("last_source", "")) != "truce" or str(chuck_receipt.get("last_label", "")) != "Rush Kit":
		_fail("Day summary did not keep the social-preference source and label.")
		return

	var summary_text := str(scene.call("_format_day_summary", summary))
	if not summary_text.contains("crew followed") or not summary_text.contains("Rush Kit"):
		_fail("Formatted day summary did not expose social-preference autonomous work. saw=%s" % summary_text)
		return

	scene.queue_free()
	await process_frame


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
	push_error(message)
	quit(1)
