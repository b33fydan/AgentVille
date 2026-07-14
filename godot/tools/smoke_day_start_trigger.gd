extends SceneTree


const VIEWPORT_SIZE := Vector2i(1600, 900)
const STEP_DELTA := 0.05
const MAX_AGENT_STEPS := 360

const DAY_START_CLEAR_PROGRAM := "agent \"Chuck\" {\n  on day_start\n  observe selected_tile\n  when inspect.has_brush {\n    use clear_brush(selected_tile)\n  }\n  verify tile_state\n  receipt \"Morning Brush run\"\n}"
const MANUAL_CLEAR_PROGRAM := "agent \"Chuck\" {\n  observe selected_tile\n  when inspect.has_brush {\n    use clear_brush(selected_tile)\n  }\n  verify tile_state\n  receipt \"Manual Brush run\"\n}"
const DAY_START_HARVEST_PROGRAM := "agent \"Marigold\" {\n  on day_start\n  observe selected_tile\n  when crop.ready {\n    use harvest_crop(selected_tile)\n  }\n  verify inventory_delta\n  receipt \"Morning Harvest run\"\n}"
const DAY_START_PLANT_PROGRAM := "agent \"Marigold\" {\n  on day_start\n  observe selected_tile\n  when tile.empty {\n    use plant_seed(selected_tile)\n  }\n  verify crop_state\n  receipt \"Morning Plant run\"\n}"
const DAY_START_PLANT_ALWAYS_PROGRAM := "agent \"Marigold\" {\n  on day_start\n  observe selected_tile\n  when always {\n    use plant_seed(selected_tile)\n  }\n  verify crop_state\n  receipt \"Morning Plant run\"\n}"

var _failed := false


func _initialize() -> void:
	root.content_scale_size = VIEWPORT_SIZE
	root.size = VIEWPORT_SIZE
	call_deferred("_run")


func _run() -> void:
	if not await _test_arm_fire_pass_and_one_shot():
		return
	if not await _test_explicit_disarm():
		return
	if not await _test_busy_runtime_skips_without_replacement():
		return
	if not await _test_guard_blocks_at_fire():
		return
	if not await _test_failed_triggered_agent_action_is_terminal():
		return
	if not _failed:
		quit()


func _test_arm_fire_pass_and_one_shot() -> bool:
	var scene: Node = await _boot_game()
	if scene == null:
		return false
	var systems := _systems(scene)
	if systems.is_empty() or not _prepare_agents(systems["agent_manager"]):
		return false
	var grid = systems["grid"]
	var placement_tool = systems["placement_tool"]
	var game_ui = systems["game_ui"]
	var progress = systems["progress"]
	var scheduler = systems["scheduler"]
	var event_log = systems["event_log"]

	var target = _find_brush_tile(grid)
	if target == null:
		_fail("Starter map did not expose brush for the day-start pass route.")
		return false
	var moved_selection = _find_other_tile(grid, target.grid_pos)
	if moved_selection == null:
		_fail("Starter map did not expose a second tile for captured-target coverage.")
		return false

	_select_tile(placement_tool, target)
	var tile_before := _tile_snapshot(target)
	var resources_before: Dictionary = scene.resources.duplicate(true)
	var day_before := int(grid.day)
	var orders_before: Array = scene.work_order_ids.duplicate()
	var completed_lessons_before: Array = progress.call("get_completed_lessons").duplicate()
	if not await _compile(game_ui, DAY_START_CLEAR_PROGRAM):
		return false

	if not bool(scheduler.call("has_armed")):
		_fail("Valid on day_start source did not arm the production scheduler.")
		return false
	var arm: Dictionary = scheduler.call("snapshot")
	var arm_id := str(arm.get("id", ""))
	if arm_id == "" or str(arm.get("trigger_type", "")) != "day_start":
		_fail("Armed trigger lost its deterministic id or declared event. arm=%s" % str(arm))
		return false
	if arm.get("request", {}).get("target_tile", Vector2i(-1, -1)) != target.grid_pos:
		_fail("Compile did not capture the selected tile in the one-shot arm. arm=%s" % str(arm))
		return false
	if not (scene.get("_pending_skill_forge_run") as Dictionary).is_empty() or scene.work_order_ids != orders_before:
		_fail("Arming drafted a pending Forge run or crew order before day start.")
		return false
	if _tile_snapshot(target) != tile_before or scene.resources != resources_before or int(grid.day) != day_before:
		_fail("Arming mutated the farm, inventory, or day before its event fired.")
		return false
	if _any_actor_has_forge_run(systems["agent_manager"]):
		_fail("Arming assigned a farmhand before day start.")
		return false
	var disarm_button = game_ui.get("_workbench_disarm_button") as Button
	var compiler_output = game_ui.get("_compiler_output") as RichTextLabel
	if disarm_button == null or not disarm_button.visible or disarm_button.disabled:
		_fail("Armed production Workbench did not expose its enabled DISARM control.")
		return false
	if compiler_output == null or not _trace_contains_all(compiler_output.text, [
		"stage     TRIGGER ARMED",
		"status    WAITING FOR DAY START",
		"target    (%s, %s) · captured selected_tile" % [target.grid_pos.x, target.grid_pos.y],
		"No guard checked, crew order drafted, or farm tile changed at Compile."
	]):
		_fail("Armed Workbench trace did not explain the deferred, captured-target contract. trace=%s" % (compiler_output.text if compiler_output else ""))
		return false
	if not _has_trigger_event(event_log, "skill_trigger_armed", arm_id, target.grid_pos):
		_fail("GameEventLog did not record the correlated trigger arm.")
		return false
	if not _entries_contain(game_ui.get("_field_log_entries"), "Day-start trigger armed once"):
		_fail("Field Log did not expose the one-shot arm receipt.")
		return false

	_select_tile(placement_tool, moved_selection)
	var arm_after_selection: Dictionary = scheduler.call("snapshot")
	if arm_after_selection.get("request", {}).get("target_tile", Vector2i(-1, -1)) != target.grid_pos:
		_fail("Moving selection retargeted the already armed program.")
		return false
	if compiler_output == null or not compiler_output.text.contains("the armed target remains (%s,%s)" % [target.grid_pos.x, target.grid_pos.y]):
		_fail("Selection-move trace did not preserve the captured target evidence. trace=%s" % (compiler_output.text if compiler_output else ""))
		return false

	var fired_events_before := _count_event(event_log, "skill_trigger_fired")
	scene.call("_on_advance_day_requested")
	await process_frame
	if int(grid.day) != day_before + 1:
		_fail("End Day did not advance the farm before firing the trigger.")
		return false
	if bool(scheduler.call("has_armed")):
		_fail("Fired one-shot remained armed after the new day began.")
		return false
	var pending: Dictionary = scene.get("_pending_skill_forge_run").duplicate(true)
	if pending.is_empty():
		_fail("Day-start activation did not establish the real pending world check.")
		return false
	if str(pending.get("origin", "")) != "workbench_trigger" \
			or str(pending.get("trigger_type", "")) != "day_start" \
			or str(pending.get("lesson_id", "")) != "" \
			or str(pending.get("trigger_arm_id", "")) != arm_id \
			or pending.get("target_tile", Vector2i(-1, -1)) != target.grid_pos:
		_fail("Automatic pending run lost its trigger origin, empty lesson id, arm id, or captured target. pending=%s" % str(pending))
		return false
	var order_id := str(pending.get("order_id", ""))
	var run_id := str(pending.get("run_id", ""))
	var order: Dictionary = scene.work_orders.get(order_id, {})
	if order.is_empty() or str(order.get("status", "")) != "queued":
		_fail("End Day did not auto-dispatch the fired order without Send. order=%s" % str(order))
		return false
	if _count_event(event_log, "skill_trigger_fired") != fired_events_before + 1 \
			or not _has_trigger_event(event_log, "skill_trigger_fired", arm_id, target.grid_pos):
		_fail("GameEventLog did not record exactly one correlated fire.")
		return false
	if _last_event_index(event_log, "day_advanced") >= _last_event_index(event_log, "skill_trigger_fired"):
		_fail("Trigger fired before the authoritative day_advanced event.")
		return false
	if not _entries_contain(game_ui.get("_field_log_entries"), "Work order queued"):
		_fail("Field Log did not expose the auto-dispatched crew route. entries=%s" % str(game_ui.get("_field_log_entries")))
		return false

	var actor = _actor_by_id(systems["agent_manager"], "chuck")
	if actor == null:
		_fail("Named trigger agent Chuck was unavailable.")
		return false
	var active: Dictionary = actor.get("_active_decision")
	if str(active.get("forge_run_id", "")) != run_id \
			or str(active.get("work_order_id", "")) != order_id \
			or str(active.get("action", "")) != "clear_brush" \
			or active.get("target_tile", Vector2i(-1, -1)) != target.grid_pos:
		_fail("Real AgentActor did not claim the auto-dispatched captured-target directive. active=%s" % str(active))
		return false
	if not await _step_actor_until_terminal(scene, actor, order_id, true):
		return false
	if str(target.decor_id) != "":
		_fail("Automatic AgentActor pass did not clear its captured brush target.")
		return false
	if not _has_correlated_agent_event(event_log, run_id, order_id, target.grid_pos, "clear_brush", true):
		_fail("GameEventLog did not retain the successful real-AgentActor world action.")
		return false
	if not _has_trigger_event(event_log, "skill_trigger_passed", arm_id, target.grid_pos, run_id, order_id):
		_fail("GameEventLog did not retain the correlated terminal trigger pass.")
		return false
	if progress.call("get_completed_lessons") != completed_lessons_before:
		_fail("Automatic day-start run incorrectly completed a manual curriculum lesson.")
		return false
	compiler_output = game_ui.get("_compiler_output") as RichTextLabel
	if compiler_output == null or not _trace_contains_all(compiler_output.text, [
		"stage     DAY START WORLD CHECK",
		"status    PASSED",
		"target    (%s, %s) · captured selected_tile" % [target.grid_pos.x, target.grid_pos.y]
	]):
		_fail("Terminal trigger trace did not expose its passed world check. trace=%s" % (compiler_output.text if compiler_output else ""))
		return false
	if not _entries_contain(game_ui.get("_field_log_entries"), "Day-start trigger passed: Morning Brush"):
		_fail("Field Log did not expose the terminal automatic receipt. entries=%s" % str(game_ui.get("_field_log_entries")))
		return false

	var fired_events_after_pass := _count_event(event_log, "skill_trigger_fired")
	var trigger_runs_after_pass := _count_origin_runs(event_log, "workbench_trigger")
	scene.call("_on_advance_day_requested")
	await process_frame
	if bool(scheduler.call("has_armed")) \
			or not (scene.get("_pending_skill_forge_run") as Dictionary).is_empty() \
			or _count_event(event_log, "skill_trigger_fired") != fired_events_after_pass \
			or _count_origin_runs(event_log, "workbench_trigger") != trigger_runs_after_pass:
		_fail("Consumed one-shot fired or created another automatic run on the following day.")
		return false

	await _dispose_game(scene)
	return true


func _test_explicit_disarm() -> bool:
	var scene: Node = await _boot_game()
	if scene == null:
		return false
	var systems := _systems(scene)
	if systems.is_empty():
		return false
	var target = _find_brush_tile(systems["grid"])
	if target == null:
		_fail("Starter map did not expose brush for DISARM coverage.")
		return false
	_select_tile(systems["placement_tool"], target)
	var tile_before := _tile_snapshot(target)
	if not await _compile(systems["game_ui"], DAY_START_CLEAR_PROGRAM):
		return false
	var arm: Dictionary = systems["scheduler"].call("snapshot")
	var arm_id := str(arm.get("id", ""))
	var fired_before := _count_event(systems["event_log"], "skill_trigger_fired")
	var disarm_button = systems["game_ui"].get("_workbench_disarm_button") as Button
	if disarm_button == null or not disarm_button.visible or disarm_button.disabled:
		_fail("Production DISARM control was unavailable after arming.")
		return false
	disarm_button.pressed.emit()
	await process_frame
	if bool(systems["scheduler"].call("has_armed")) \
			or not (scene.get("_pending_skill_forge_run") as Dictionary).is_empty() \
			or not scene.work_order_ids.is_empty() \
			or _tile_snapshot(target) != tile_before:
		_fail("Explicit DISARM left an arm, run, order, or farm mutation behind.")
		return false
	if disarm_button.visible or not disarm_button.disabled:
		_fail("Controller acknowledgement did not hide and disable DISARM.")
		return false
	if not _has_trigger_event(systems["event_log"], "skill_trigger_disarmed", arm_id, target.grid_pos):
		_fail("GameEventLog did not record the explicit correlated disarm.")
		return false
	if not _entries_contain(systems["game_ui"].get("_field_log_entries"), "Day-start trigger disarmed"):
		_fail("Field Log did not expose the disarm receipt.")
		return false
	var compiler_output = systems["game_ui"].get("_compiler_output") as RichTextLabel
	if compiler_output == null or not _trace_contains_all(compiler_output.text, [
		"stage     TRIGGER DISARMED",
		"The one-shot arm was removed before day start."
	]):
		_fail("Workbench did not teach the explicit disarm result. trace=%s" % (compiler_output.text if compiler_output else ""))
		return false

	scene.call("_on_advance_day_requested")
	await process_frame
	if _count_event(systems["event_log"], "skill_trigger_fired") != fired_before \
			or not (scene.get("_pending_skill_forge_run") as Dictionary).is_empty():
		_fail("Explicitly disarmed program still fired on the next day.")
		return false

	await _dispose_game(scene)
	return true


func _test_busy_runtime_skips_without_replacement() -> bool:
	var scene: Node = await _boot_game()
	if scene == null:
		return false
	var systems := _systems(scene)
	if systems.is_empty() or not _prepare_agents(systems["agent_manager"]):
		return false
	var brush = _find_brush_tile(systems["grid"])
	var trigger_target = _find_empty_tile(systems["grid"], brush.grid_pos if brush != null else Vector2i(-1, -1))
	if brush == null or trigger_target == null:
		_fail("Starter map did not expose manual and trigger targets for runtime-busy coverage.")
		return false

	_select_tile(systems["placement_tool"], brush)
	if not await _compile(systems["game_ui"], MANUAL_CLEAR_PROGRAM):
		return false
	var manual_pending: Dictionary = scene.get("_pending_skill_forge_run").duplicate(true)
	var manual_run_id := str(manual_pending.get("run_id", ""))
	var manual_order_id := str(manual_pending.get("order_id", ""))
	if manual_run_id == "" or manual_order_id == "":
		_fail("Manual compile did not establish the authoritative busy run.")
		return false

	_select_tile(systems["placement_tool"], trigger_target)
	if not await _compile(systems["game_ui"], DAY_START_PLANT_PROGRAM):
		return false
	var arm: Dictionary = systems["scheduler"].call("snapshot")
	var arm_id := str(arm.get("id", ""))
	var pending_after_arm: Dictionary = scene.get("_pending_skill_forge_run")
	if str(pending_after_arm.get("run_id", "")) != manual_run_id \
			or str(pending_after_arm.get("order_id", "")) != manual_order_id:
		_fail("Arming a day-start program replaced the already pending manual run.")
		return false

	scene.call("_on_advance_day_requested")
	await process_frame
	var pending_after_fire: Dictionary = scene.get("_pending_skill_forge_run")
	if str(pending_after_fire.get("run_id", "")) != manual_run_id \
			or str(pending_after_fire.get("order_id", "")) != manual_order_id \
			or not scene.work_orders.has(manual_order_id):
		_fail("Busy trigger fire replaced or removed the authoritative manual run.")
		return false
	if bool(systems["scheduler"].call("has_armed")):
		_fail("Runtime-busy skip did not consume its one-shot arm.")
		return false
	if not _has_trigger_event(systems["event_log"], "skill_trigger_fired", arm_id, trigger_target.grid_pos) \
			or not _has_trigger_event(systems["event_log"], "skill_trigger_skipped", arm_id, trigger_target.grid_pos):
		_fail("Busy activation did not record both fired and skipped trigger evidence.")
		return false
	if not _entries_contain(systems["game_ui"].get("_field_log_entries"), "Day-start trigger skipped"):
		_fail("Field Log did not expose the runtime-busy skipped receipt.")
		return false
	var compiler_output = systems["game_ui"].get("_compiler_output") as RichTextLabel
	if compiler_output == null or not _trace_contains_all(compiler_output.text, [
		"stage     TRIGGER SKIPPED",
		"status    PIPELINE BUSY",
		"line 2:6 · token day_start",
		"another Forge world check is still pending",
		"existing run and crew order remain authoritative"
	]):
		_fail("Runtime-busy trace lost source-linked skip evidence. trace=%s" % (compiler_output.text if compiler_output else ""))
		return false

	await _dispose_game(scene)
	return true


func _test_guard_blocks_at_fire() -> bool:
	var scene: Node = await _boot_game()
	if scene == null:
		return false
	var systems := _systems(scene)
	if systems.is_empty():
		return false
	var target = _find_empty_tile(systems["grid"])
	if target == null:
		_fail("Starter map did not expose an empty tile for fire-time guard coverage.")
		return false
	_select_tile(systems["placement_tool"], target)
	var tile_before := _tile_snapshot(target)
	if not await _compile(systems["game_ui"], DAY_START_HARVEST_PROGRAM):
		return false
	var arm: Dictionary = systems["scheduler"].call("snapshot")
	var arm_id := str(arm.get("id", ""))
	if arm_id == "" or not (scene.get("_pending_skill_forge_run") as Dictionary).is_empty() or not scene.work_order_ids.is_empty():
		_fail("False-at-Compile crop.ready guard was checked early instead of arming cleanly.")
		return false
	if _tile_snapshot(target) != tile_before:
		_fail("False-at-Compile guard mutated its target while arming.")
		return false

	scene.call("_on_advance_day_requested")
	await process_frame
	if bool(systems["scheduler"].call("has_armed")) \
			or not (scene.get("_pending_skill_forge_run") as Dictionary).is_empty() \
			or not scene.work_order_ids.is_empty():
		_fail("Fire-time guard block left an arm, pending verifier, or crew order behind.")
		return false
	if not _has_trigger_event(systems["event_log"], "skill_trigger_fired", arm_id, target.grid_pos) \
			or not _has_trigger_event(systems["event_log"], "skill_trigger_blocked", arm_id, target.grid_pos):
		_fail("Fire-time guard block did not record correlated fired and blocked evidence.")
		return false
	var compiler_output = systems["game_ui"].get("_compiler_output") as RichTextLabel
	if compiler_output == null or not _trace_contains_all(compiler_output.text, [
		"stage     TRIGGER BLOCKED",
		"status    BLOCKED",
		"line 4:8 · token crop.ready",
		"Guard crop.ready blocked at tile",
		"observed an empty tile"
	]):
		_fail("Fire-time guard trace lost its source-linked authored condition. trace=%s" % (compiler_output.text if compiler_output else ""))
		return false
	if not _entries_contain(systems["game_ui"].get("_field_log_entries"), "Skill Forge blocked Morning Harvest"):
		_fail("Field Log did not expose the fire-time blocked receipt. entries=%s" % str(systems["game_ui"].get("_field_log_entries")))
		return false

	await _dispose_game(scene)
	return true


func _test_failed_triggered_agent_action_is_terminal() -> bool:
	var scene: Node = await _boot_game()
	if scene == null:
		return false
	var systems := _systems(scene)
	if systems.is_empty() or not _prepare_agents(systems["agent_manager"]):
		return false
	var target = _find_empty_tile(systems["grid"])
	if target == null:
		_fail("Starter map did not expose an empty tile for automatic action-failure coverage.")
		return false
	_select_tile(systems["placement_tool"], target)
	if not await _compile(systems["game_ui"], DAY_START_PLANT_ALWAYS_PROGRAM):
		return false
	var arm: Dictionary = systems["scheduler"].call("snapshot")
	var arm_id := str(arm.get("id", ""))
	scene.call("_on_advance_day_requested")
	await process_frame
	var pending: Dictionary = scene.get("_pending_skill_forge_run").duplicate(true)
	var run_id := str(pending.get("run_id", ""))
	var order_id := str(pending.get("order_id", ""))
	if run_id == "" or order_id == "" or str(scene.work_orders.get(order_id, {}).get("status", "")) != "queued":
		_fail("Plant trigger did not reach an auto-dispatched real AgentActor order before drift. pending=%s" % str(pending))
		return false
	if str(pending.get("origin", "")) != "workbench_trigger" or str(pending.get("lesson_id", "")) != "":
		_fail("Failed-action activation lost its automatic origin or carried a manual lesson id.")
		return false
	var actor = _actor_by_id(systems["agent_manager"], "marigold")
	if actor == null or str((actor.get("_active_decision") as Dictionary).get("forge_run_id", "")) != run_id:
		_fail("Marigold did not claim the correlated plant trigger before target drift.")
		return false

	# The declared guard is always, so this post-dispatch rock does not turn the
	# route into a guard block. The real AgentActor reaches the tile, attempts the
	# allowlisted plant_seed action, and emits its natural unsuccessful receipt.
	if not bool(target.call("place_item", "rock")):
		_fail("Could not arrange post-dispatch target drift for real action failure.")
		return false
	if not await _step_actor_until_terminal(scene, actor, order_id, false):
		return false
	if not (scene.get("_pending_skill_forge_run") as Dictionary).is_empty() \
			or scene.work_orders.has(order_id) \
			or scene.work_order_ids.has(order_id):
		_fail("Failed automatic AgentActor action did not terminalize and remove its order.")
		return false
	if not _has_correlated_agent_event(systems["event_log"], run_id, order_id, target.grid_pos, "plant_seed", false):
		_fail("GameEventLog did not retain the real AgentActor's failed plant action.")
		return false
	if not _has_trigger_event(systems["event_log"], "skill_trigger_failed", arm_id, target.grid_pos, run_id, order_id):
		_fail("GameEventLog did not retain the correlated terminal trigger failure.")
		return false
	if not _has_work_order_event(systems["event_log"], order_id, "trigger_action_failed"):
		_fail("Removed order did not leave trigger_action_failed work-order evidence.")
		return false
	var compiler_output = systems["game_ui"].get("_compiler_output") as RichTextLabel
	if compiler_output == null or not _trace_contains_all(compiler_output.text, [
		"stage     DAY START WORLD CHECK",
		"status    FAILED",
		"line 7:10 · token crop_state",
		"found no open planting tile"
	]):
		_fail("Failed automatic action trace did not close with source-linked evidence. trace=%s" % (compiler_output.text if compiler_output else ""))
		return false
	if not _entries_contain(systems["game_ui"].get("_field_log_entries"), "Day-start trigger failed: Morning Plant"):
		_fail("Field Log did not expose the terminal failed automatic receipt. entries=%s" % str(systems["game_ui"].get("_field_log_entries")))
		return false

	await _dispose_game(scene)
	return true


func _boot_game() -> Node:
	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	await process_frame
	var sound_manager = scene.get_node_or_null("SoundManager")
	if sound_manager != null:
		sound_manager.set("enabled", false)
	return scene


func _dispose_game(scene: Node) -> void:
	if is_instance_valid(scene):
		scene.queue_free()
	await process_frame
	await process_frame


func _systems(scene: Node) -> Dictionary:
	var systems := {
		"grid": scene.get_node_or_null("FarmWorld/GridManager"),
		"placement_tool": scene.get_node_or_null("PlacementTool"),
		"game_ui": scene.get_node_or_null("GameUI"),
		"agent_manager": scene.get("_agent_manager"),
		"event_log": scene.get("_event_log"),
		"scheduler": scene.get("_skill_trigger_scheduler"),
		"progress": scene.get("_player_progress")
	}
	for key in systems.keys():
		if systems[key] == null:
			_fail("Day-start integration did not expose %s." % str(key).replace("_", " "))
			return {}
	return systems


func _prepare_agents(agent_manager) -> bool:
	if agent_manager.agents.is_empty():
		_fail("Day-start integration did not spawn the farm crew.")
		return false
	for actor in agent_manager.agents:
		actor.call("_complete_active_decision")
		actor.set_process(false)
		actor.set("_decision_timer", 999.0)
		actor.move_speed = 24.0
		if not bool(actor.call("is_available")):
			_fail("%s was unavailable before deterministic trigger coverage." % str(actor.display_name))
			return false
	return true


func _compile(game_ui, source: String) -> bool:
	var editor = game_ui.get("_code_editor") as CodeEdit
	var compile_button = game_ui.get("_workbench_compile_button") as Button
	if editor == null or compile_button == null or compile_button.disabled:
		_fail("Production Workbench editor or Compile control was unavailable.")
		return false
	editor.text = source
	compile_button.pressed.emit()
	await process_frame
	return true


func _select_tile(placement_tool, tile) -> void:
	placement_tool.call("set_tool", "select")
	placement_tool.call("_apply_to_tile", tile)


func _step_actor_until_terminal(scene: Node, actor, order_id: String, expect_done_order: bool) -> bool:
	for _step in range(MAX_AGENT_STEPS):
		actor.call("_process", STEP_DELTA)
		await process_frame
		var pending: Dictionary = scene.get("_pending_skill_forge_run")
		var order_exists: bool = scene.work_orders.has(order_id)
		var order_status := str(scene.work_orders.get(order_id, {}).get("status", "missing"))
		if not pending.is_empty():
			continue
		if expect_done_order and order_exists and order_status == "done" and bool(actor.call("is_available")):
			return true
		if not expect_done_order and not order_exists and bool(actor.call("is_available")):
			return true
	_fail("Real AgentActor did not reach the expected terminal state. actor=%s order=%s pending=%s" % [
		str(actor.get("_active_decision")),
		str(scene.work_orders.get(order_id, {})),
		str(scene.get("_pending_skill_forge_run"))
	])
	return false


func _actor_by_id(agent_manager, agent_id: String):
	for actor in agent_manager.agents:
		if str(actor.agent_id) == agent_id:
			return actor
	return null


func _any_actor_has_forge_run(agent_manager) -> bool:
	for actor in agent_manager.agents:
		if str((actor.get("_active_decision") as Dictionary).get("forge_run_id", "")) != "":
			return true
	return false


func _find_brush_tile(grid):
	for tile in grid.tiles.values():
		if str(tile.decor_id) in ["tall_grass", "flower_patch"]:
			return tile
	return null


func _find_empty_tile(grid, excluded: Vector2i = Vector2i(-1, -1)):
	for tile in grid.tiles.values():
		if tile.grid_pos == excluded:
			continue
		if tile.crop == null \
				and str(tile.decor_id) == "" \
				and str(tile.structure_id) == "" \
				and str(tile.terrain) != "dirt_path":
			return tile
	return null


func _find_other_tile(grid, excluded: Vector2i):
	for tile in grid.tiles.values():
		if tile.grid_pos != excluded:
			return tile
	return null


func _tile_snapshot(tile) -> Dictionary:
	return {
		"grid_pos": tile.grid_pos,
		"terrain": str(tile.terrain),
		"is_tilled": bool(tile.is_tilled),
		"decor_id": str(tile.decor_id),
		"structure_id": str(tile.structure_id),
		"crop_id": str(tile.crop.crop_id) if tile.crop != null else "",
		"crop_stage": int(tile.crop.stage) if tile.crop != null else -1
	}


func _count_event(event_log, event_type: String) -> int:
	var count := 0
	for event in event_log.events:
		if str(event.get("type", "")) == event_type:
			count += 1
	return count


func _count_origin_runs(event_log, origin: String) -> int:
	var count := 0
	for event in event_log.events:
		if str(event.get("type", "")) == "skill_forge_run" and str(event.get("origin", "")) == origin:
			count += 1
	return count


func _last_event_index(event_log, event_type: String) -> int:
	var result := -1
	for index in range(event_log.events.size()):
		if str(event_log.events[index].get("type", "")) == event_type:
			result = index
	return result


func _has_trigger_event(
	event_log,
	event_type: String,
	arm_id: String,
	target: Vector2i,
	run_id: String = "",
	order_id: String = ""
) -> bool:
	for event in event_log.events:
		if str(event.get("type", "")) != event_type \
				or str(event.get("arm_id", "")) != arm_id \
				or event.get("target_tile", Vector2i(-1, -1)) != target:
			continue
		if run_id != "" and str(event.get("run_id", "")) != run_id:
			continue
		if order_id != "" and str(event.get("order_id", "")) != order_id:
			continue
		return true
	return false


func _has_correlated_agent_event(
	event_log,
	run_id: String,
	order_id: String,
	target: Vector2i,
	action: String,
	success: bool
) -> bool:
	for event in event_log.events:
		if str(event.get("type", "")) != "agent_world_action":
			continue
		if str(event.get("forge_run_id", "")) == run_id \
				and str(event.get("work_order_id", "")) == order_id \
				and event.get("grid_pos", Vector2i(-1, -1)) == target \
				and str(event.get("action", "")) == action \
				and bool(event.get("success", not success)) == success:
			return true
	return false


func _has_work_order_event(event_log, order_id: String, status: String) -> bool:
	for event in event_log.events:
		if str(event.get("type", "")) == "work_order" \
				and str(event.get("order_id", event.get("id", ""))) == order_id \
				and str(event.get("status", "")) == status:
			return true
	return false


func _entries_contain(entries, needle: String) -> bool:
	if typeof(entries) != TYPE_ARRAY:
		return false
	for entry in entries:
		if str(entry).contains(needle):
			return true
	return false


func _trace_contains_all(trace: String, fragments: Array) -> bool:
	for fragment in fragments:
		if not trace.contains(str(fragment)):
			return false
	return true


func _fail(message: String) -> void:
	if _failed:
		return
	_failed = true
	push_error(message)
	quit(1)
