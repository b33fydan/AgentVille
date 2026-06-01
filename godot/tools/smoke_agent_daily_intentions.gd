extends SceneTree

const AgentMemoryScript := preload("res://scripts/ai/AgentMemory.gd")
const UtilityAgentDecisionModelScript := preload("res://scripts/ai/UtilityAgentDecisionModel.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_intention_biases_utility_choice()
	await _test_scene_exposes_daily_intentions()
	await _test_intention_receipts_from_agent_work()
	quit()


func _test_intention_biases_utility_choice() -> void:
	var chuck_decision := _decision(
		_agent_state("chuck", "Chuck", "chaotic", {
			"daily_intention_id": "clear_paths",
			"daily_intention_label": "Clear the Way",
			"daily_intention_focus": "clear"
		}),
		_world({
			"ready_crops": 1,
			"ready_tile": Vector2i(6, 6),
			"brush_tiles": 1,
			"brush_tile": Vector2i(2, 3)
		})
	)
	if str(chuck_decision.get("action", "")) != "clear_brush":
		_fail("Chuck's daily clearing intention did not bias him toward brush work.")
		return
	if chuck_decision.get("target_tile", Vector2i.ZERO) != Vector2i(2, 3):
		_fail("Clearing intention did not keep the brush target.")
		return
	if str(chuck_decision.get("daily_intention_id", "")) != "clear_paths":
		_fail("Clearing intention decision did not carry intention metadata.")
		return

	var bert_decision := _decision(
		_agent_state("bert", "Bert", "grizzled", {
			"daily_intention_id": "shore_boundaries",
			"daily_intention_label": "Shore Boundaries",
			"daily_intention_focus": "boundary"
		}),
		_world({
			"ready_crops": 1,
			"ready_tile": Vector2i(6, 6),
			"structures": 1,
			"structure_tile": Vector2i(4, 5)
		})
	)
	if str(bert_decision.get("action", "")) != "inspect_structure":
		_fail("Bert's daily boundary intention did not bias him toward structure checks.")
		return
	if str(bert_decision.get("daily_intention_label", "")) != "Shore Boundaries":
		_fail("Boundary intention decision did not preserve the intention label.")
		return

	var marigold_decision := _decision(
		_agent_state("marigold", "Marigold", "hopeful", {
			"daily_intention_id": "tend_growth",
			"daily_intention_label": "Tend Growth",
			"daily_intention_focus": "grow"
		}),
		_world({
			"brush_tiles": 1,
			"brush_tile": Vector2i(2, 2),
			"growing_crops": 1,
			"growing_tile": Vector2i(5, 6)
		})
	)
	if str(marigold_decision.get("action", "")) != "inspect_ready_crop":
		_fail("Marigold's daily growth intention did not bias her toward crop watching.")
		return


func _test_scene_exposes_daily_intentions() -> void:
	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var snapshots: Array = scene.get_node("FarmWorld/AgentManager").call("get_agent_snapshots")
	var expected := {
		"bert": "Shore Boundaries",
		"marigold": "Tend Growth",
		"chuck": "Clear the Way"
	}
	for snapshot in snapshots:
		if typeof(snapshot) != TYPE_DICTIONARY:
			continue
		var agent_id := str(snapshot.get("id", ""))
		if not expected.has(agent_id):
			continue
		if str(snapshot.get("daily_intention_label", "")) != str(expected[agent_id]):
			_fail("%s did not expose the expected daily intention." % agent_id)
			return

	var social_label := _crew_social_label(scene, "bert")
	if social_label == null or not social_label.visible:
		_fail("Crew row did not show Bert's daily intention plan.")
		return
	if not str(social_label.text).contains("Plan") or not str(social_label.text).contains("Shore Boundaries"):
		_fail("Crew row did not label Bert's daily plan. saw=%s" % str(social_label.text))
		return

	scene.queue_free()
	await process_frame


func _test_intention_receipts_from_agent_work() -> void:
	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var grid = scene.get_node("FarmWorld/GridManager")
	var agent = scene.get_node("FarmWorld/AgentManager").agents[2]
	agent.move_speed = 36.0
	var target: Vector2i = agent.current_grid_pos
	var tile = grid.get_tile(target)
	if tile == null:
		_fail("Daily intention receipt setup could not find Chuck's tile.")
		return
	tile.erase()
	tile.place_item("tall_grass")

	var decision := _decision(
		agent.state.duplicate(true),
		_world({
			"home_tile": agent.home_tile,
			"brush_tiles": 1,
			"brush_tile": target,
			"wander_tile": target
		})
	)
	if str(decision.get("daily_intention_id", "")) != "clear_paths":
		_fail("Scene intention decision did not carry Chuck's daily plan.")
		return
	agent.call("_start_decision", decision)
	await create_timer(1.0).timeout

	if str(tile.decor_id) != "":
		_fail("Daily intention work did not clear Chuck's target brush.")
		return

	var log = scene.get_node("GameEventLog")
	var saw_agent_action := false
	var saw_world_action := false
	for event in log.get("events"):
		if typeof(event) != TYPE_DICTIONARY:
			continue
		if str(event.get("daily_intention_id", "")) != "clear_paths" or str(event.get("daily_intention_label", "")) != "Clear the Way":
			continue
		match str(event.get("type", "")):
			"agent_action":
				saw_agent_action = true
			"agent_world_action":
				if bool(event.get("success", false)):
					saw_world_action = true
	if not saw_agent_action:
		_fail("Agent action receipt did not record daily intention context.")
		return
	if not saw_world_action:
		_fail("Agent world-action receipt did not record daily intention context.")
		return

	var summary: Dictionary = log.call("build_day_summary", grid.day)
	var intention_actions: Dictionary = summary.get("agent_intention_actions", {})
	if not intention_actions.has("chuck"):
		_fail("Day summary did not count Chuck's daily-intention work.")
		return
	var chuck_receipt: Dictionary = intention_actions.get("chuck", {})
	if str(chuck_receipt.get("last_intention_label", "")) != "Clear the Way":
		_fail("Day summary did not preserve Chuck's daily intention label.")
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
		"truce_days": 0,
		"daily_intention_id": "",
		"daily_intention_label": "",
		"daily_intention_focus": ""
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


func _crew_social_label(scene: Node, agent_id: String) -> Label:
	var game_ui = scene.get_node("GameUI")
	var rows: Dictionary = game_ui.get("_crew_rows")
	if not rows.has(agent_id):
		return null
	var row: Dictionary = rows[agent_id]
	return row.get("social", null) as Label


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
