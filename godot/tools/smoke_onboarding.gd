extends SceneTree

const TEMP_PATH_PREFIX := "user://agentville_onboarding_smoke_"

var _failed := false
var _temp_progress_path := ""
var _observed_world_actions: Array = []


func _initialize() -> void:
	root.content_scale_size = Vector2i(1600, 900)
	root.size = Vector2i(1600, 900)
	_temp_progress_path = "%s%s.json" % [TEMP_PATH_PREFIX, Time.get_ticks_usec()]
	_cleanup_temp_progress()
	call_deferred("_run")


func _run() -> void:
	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	scene.set("progress_storage_path", _temp_progress_path)
	root.add_child(scene)
	await process_frame
	await process_frame
	await process_frame

	var systems := _onboarding_systems(scene)
	if systems.is_empty():
		return
	var progress = systems["progress"]
	var lesson_library = systems["lesson_library"]
	var game_ui = systems["game_ui"]
	var grid = systems["grid"]
	var placement_tool = systems["placement_tool"]
	var agent_manager = systems["agent_manager"]
	var event_log = systems["event_log"]
	var sound_manager = scene.get_node_or_null("SoundManager")
	if sound_manager == null:
		_fail("Onboarding integration did not expose SoundManager.")
		return
	agent_manager.connect("agent_world_action", _record_agent_world_action)

	var lesson_one_id := str(lesson_library.call("first_lesson_id"))
	var lesson_two_id := str(lesson_library.call("next_lesson_id", lesson_one_id))
	var lesson_one: Dictionary = lesson_library.call("get_lesson", lesson_one_id)
	var lesson_two: Dictionary = lesson_library.call("get_lesson", lesson_two_id)
	if lesson_one.is_empty() or lesson_two.is_empty():
		_fail("Onboarding smoke requires the first two curriculum lessons.")
		return

	if not _assert_fresh_boot(progress, game_ui, placement_tool, lesson_one, lesson_two):
		return
	if not _assert_no_synthetic_boot_selection(game_ui, event_log):
		return
	var lesson_brush = placement_tool.call("get_selected_tile")
	if lesson_brush == null or str(lesson_brush.decor_id) not in ["tall_grass", "flower_patch"]:
		_fail("Fresh onboarding did not preselect a live brush target for Lesson 1.")
		return

	# The lock must cover production mutation handlers, not just hide buttons.
	var brush_decor_before := str(lesson_brush.decor_id)
	var day_before := int(grid.day)
	scene.call("_on_tool_selected", "till")
	if str(placement_tool.call("_current_tool_name")) != "select" or str(lesson_brush.decor_id) != brush_decor_before:
		_fail("Locked onboarding allowed the FARM tool path to leave Select or mutate its target.")
		return
	scene.call("_on_advance_day_requested")
	if int(grid.day) != day_before:
		_fail("Locked onboarding allowed End Day to advance the farm.")
		return
	scene.call("_on_skill_forge_run_requested", "clear_patch_starter")
	if not (scene.get("_pending_skill_forge_run") as Dictionary).is_empty():
		_fail("Locked onboarding allowed the free-play Forge path to draft work before Lesson 1.")
		return
	scene.call("_on_work_order_tool_selected", "clear_brush")
	if bool(placement_tool.call("_is_targeting_crew_order")) or str(game_ui.get("_active_work_order_tool")) != "":
		_fail("Reachable CREW tab allowed free-play targeting before Lesson 1.")
		return

	# Selection and the Workbench-to-crew Send route remain available because that
	# real run is the action which earns the sandbox unlock.
	placement_tool.set_tool("select")
	placement_tool.call("_apply_to_tile", lesson_brush)
	var editor = game_ui.get("_code_editor") as CodeEdit
	var compile_button = game_ui.get("_workbench_compile_button") as Button
	if editor == null or compile_button == null:
		_fail("Fresh onboarding did not expose the Lesson 1 Workbench controls.")
		return
	editor.text = str(lesson_one.get("starting_editor_text", ""))
	compile_button.pressed.emit()
	if not _assert_feedback_event(game_ui, sound_manager, "compile", "compile_success", 1):
		return
	await process_frame

	var pending_value = scene.get("_pending_skill_forge_run")
	if typeof(pending_value) != TYPE_DICTIONARY or pending_value.is_empty():
		_fail("Lesson 1 Compile did not draft the crew order needed to unlock the sandbox.")
		return
	var pending: Dictionary = pending_value.duplicate(true)
	if str(pending.get("origin", "")) != "workbench" or pending.get("target_tile", Vector2i(-1, -1)) != lesson_brush.grid_pos:
		_fail("Lesson 1 onboarding run lost its Workbench origin or preselected target. pending=%s" % str(pending))
		return
	if not _assert_locked_surfaces(game_ui, placement_tool):
		return
	if not await _complete_brush_run(scene, game_ui, agent_manager, lesson_brush, pending):
		return
	await process_frame
	await process_frame

	if not bool(progress.call("is_lesson_completed", lesson_one_id)) or str(progress.call("get_current_lesson")) != lesson_two_id:
		_fail("The real Lesson 1 run did not persist mastery and advance to Lesson 2.")
		return
	if not FileAccess.file_exists(_temp_progress_path):
		_fail("Lesson 1 completion did not create the isolated progress file.")
		return
	if not _assert_unlocked_surfaces(game_ui, placement_tool, lesson_two, "CURRENT GOAL"):
		return

	# Prove the farm tool path itself is live after mastery, without using a UI
	# state flag as a proxy for the actual sandbox behavior.
	var tillable_tile = _find_tillable_tile(grid)
	if tillable_tile == null:
		_fail("Starter map did not expose an empty grass tile for the unlock proof.")
		return
	placement_tool.set_tool("till")
	placement_tool.call("_apply_to_tile", tillable_tile)
	if not bool(tillable_tile.is_tilled):
		_fail("Farm sandbox reported unlocked after Lesson 1, but Till still could not mutate a valid tile.")
		return

	scene.queue_free()
	await process_frame
	await process_frame
	_observed_world_actions.clear()

	var resumed_scene: Node = load("res://scenes/Main.tscn").instantiate()
	resumed_scene.set("progress_storage_path", _temp_progress_path)
	root.add_child(resumed_scene)
	await process_frame
	await process_frame
	await process_frame

	var resumed_systems := _onboarding_systems(resumed_scene)
	if resumed_systems.is_empty():
		return
	var resumed_progress = resumed_systems["progress"]
	var resumed_ui = resumed_systems["game_ui"]
	var resumed_placement = resumed_systems["placement_tool"]
	if str(resumed_progress.call("get_storage_path")) != _temp_progress_path:
		_fail("Returning boot did not reopen the isolated progress path.")
		return
	if resumed_progress.call("get_completed_lessons") != [lesson_one_id] or str(resumed_progress.call("get_current_lesson")) != lesson_two_id:
		_fail("Returning boot did not restore exactly Lesson 1 DONE and Lesson 2 current. progress=%s" % str(resumed_progress.call("snapshot")))
		return
	if not _assert_resumed_lesson(resumed_ui, resumed_placement, lesson_one, lesson_two):
		return

	resumed_scene.queue_free()
	await process_frame
	await process_frame
	_cleanup_temp_progress()
	if not _failed:
		quit()


func _onboarding_systems(scene: Node) -> Dictionary:
	var systems := {
		"progress": scene.get("_player_progress"),
		"lesson_library": scene.get("_skill_lesson_library"),
		"game_ui": scene.get_node_or_null("GameUI"),
		"grid": scene.get_node_or_null("FarmWorld/GridManager"),
		"placement_tool": scene.get_node_or_null("PlacementTool"),
		"agent_manager": scene.get("_agent_manager"),
		"event_log": scene.get("_event_log")
	}
	for key in systems.keys():
		if systems[key] == null:
			_fail("Onboarding integration did not expose %s." % str(key).replace("_", " "))
			return {}
	if str(systems["progress"].call("get_storage_path")) != _temp_progress_path:
		_fail("Game did not use the isolated onboarding progress path before boot.")
		return {}
	if not bool(systems["progress"].call("is_disk_enabled")):
		_fail("Explicit onboarding progress path did not enable real persistence.")
		return {}
	return systems


func _assert_fresh_boot(progress, game_ui, placement_tool, lesson_one: Dictionary, lesson_two: Dictionary) -> bool:
	var lesson_one_id := str(lesson_one.get("id", ""))
	if progress.call("get_completed_lessons") != [] or str(progress.call("get_current_lesson")) != lesson_one_id:
		_fail("Fresh onboarding did not start with no mastery and Lesson 1 current. progress=%s" % str(progress.call("snapshot")))
		return false
	if str(game_ui.get("_active_command_tab")) != "agent":
		_fail("Fresh onboarding did not land in the AGENT command tab. active=%s" % str(game_ui.get("_active_command_tab")))
		return false
	var workbench = game_ui.get("_code_workbench") as Control
	if workbench == null or not workbench.is_visible_in_tree():
		_fail("Fresh onboarding did not leave the Agent Workbench open.")
		return false
	var goal_panel = game_ui.get("_onboarding_goal_panel") as Control
	var goal_label = game_ui.get("_onboarding_goal_label") as Label
	var lesson_goal = game_ui.get("_workbench_lesson_goal_label") as Label
	var expected_goal := str(lesson_one.get("goal", ""))
	if goal_panel == null or not goal_panel.is_visible_in_tree() or goal_label == null:
		_fail("Fresh onboarding did not expose its prominent goal panel.")
		return false
	if not goal_label.text.contains("START HERE") or not goal_label.text.contains("LESSON 01") or not goal_label.text.contains(expected_goal):
		_fail("Fresh onboarding goal did not unambiguously name Lesson 1 and its action. text=%s" % goal_label.text)
		return false
	if lesson_goal == null or not lesson_goal.text.contains(str(lesson_one.get("title", ""))) or not lesson_goal.text.contains(expected_goal):
		_fail("Workbench goal did not mirror the active Lesson 1 goal. text=%s" % (lesson_goal.text if lesson_goal else ""))
		return false
	var editor = game_ui.get("_code_editor") as CodeEdit
	if editor == null or editor.text != str(lesson_one.get("starting_editor_text", "")):
		_fail("Fresh onboarding did not load the exact Lesson 1 starter source.")
		return false
	if not _assert_tutor_trace(game_ui, lesson_one):
		return false
	if not _assert_lesson_buttons(game_ui, lesson_one, lesson_two, "NOW", "LOCK"):
		return false
	return _assert_locked_surfaces(game_ui, placement_tool)


func _assert_locked_surfaces(game_ui, placement_tool) -> bool:
	if bool(game_ui.call("is_farm_sandbox_unlocked")) or bool(placement_tool.call("is_farm_sandbox_unlocked")):
		_fail("Fresh onboarding did not lock both UI and PlacementTool farm surfaces.")
		return false
	var tabs_value = game_ui.get("_command_tab_buttons")
	if typeof(tabs_value) != TYPE_DICTIONARY:
		_fail("Onboarding command-tab registry was unavailable.")
		return false
	var tabs: Dictionary = tabs_value
	var farm_tab = tabs.get("farm", null) as Button
	if farm_tab == null or not farm_tab.disabled:
		_fail("Fresh onboarding did not lock the FARM command tab.")
		return false
	var crew_tab = tabs.get("crew", null) as Button
	if crew_tab == null or crew_tab.disabled:
		_fail("Fresh onboarding hid the CREW tab needed to reach the lesson's Send command.")
		return false
	var forge_section = game_ui.get("_skill_forge_onboarding_section") as Control
	if forge_section == null or forge_section.visible:
		_fail("Fresh onboarding exposed free-play Forge recipes before Lesson 1.")
		return false
	var end_day = game_ui.get("_end_day_button") as Button
	if end_day == null or not end_day.disabled:
		_fail("Fresh onboarding left End Day enabled before Lesson 1.")
		return false
	return true


func _assert_no_synthetic_boot_selection(game_ui, event_log) -> bool:
	for event in event_log.events:
		if str(event.get("type", "")) == "player_action":
			_fail("Automatic Lesson 1 target selection fabricated a player action. event=%s" % str(event))
			return false
	var toast = game_ui.get("_toast_label") as Label
	if toast != null and toast.text.to_lower().contains("select"):
		_fail("Automatic Lesson 1 target selection fabricated a player-facing toast. text=%s" % toast.text)
		return false
	var entries_value = game_ui.get("_field_log_entries")
	if typeof(entries_value) == TYPE_ARRAY:
		for entry in entries_value:
			if str(entry).begins_with("Selected ("):
				_fail("Automatic Lesson 1 target selection fabricated a Field Log receipt. entry=%s" % str(entry))
				return false
	return true


func _assert_unlocked_surfaces(game_ui, placement_tool, lesson: Dictionary, goal_prefix: String) -> bool:
	if not bool(game_ui.call("is_farm_sandbox_unlocked")) or not bool(placement_tool.call("is_farm_sandbox_unlocked")):
		_fail("Lesson 1 completion did not unlock both UI and PlacementTool farm surfaces.")
		return false
	var tabs: Dictionary = game_ui.get("_command_tab_buttons")
	for tab_id in ["farm", "crew"]:
		var tab = tabs.get(tab_id, null) as Button
		if tab == null or tab.disabled:
			_fail("Lesson 1 completion did not enable the %s command tab." % tab_id.to_upper())
			return false
	var forge_section = game_ui.get("_skill_forge_onboarding_section") as Control
	if forge_section == null or not forge_section.visible:
		_fail("Lesson 1 completion did not reveal free-play Forge recipes.")
		return false
	var goal_panel = game_ui.get("_onboarding_goal_panel") as Control
	if goal_panel == null or goal_panel.visible:
		_fail("Unlocked curriculum did not collapse the starter-only goal panel and return space to the Forge.")
		return false
	var end_day = game_ui.get("_end_day_button") as Button
	if end_day == null or end_day.disabled:
		_fail("Lesson 1 completion did not enable End Day.")
		return false
	var goal_label = game_ui.get("_onboarding_goal_label") as Label
	if goal_label == null or not goal_label.text.contains(goal_prefix) or not goal_label.text.contains(str(lesson.get("title", ""))) or not goal_label.text.contains(str(lesson.get("goal", ""))):
		_fail("Unlocked onboarding goal did not advance to the next lesson. text=%s" % (goal_label.text if goal_label else ""))
		return false
	return true


func _assert_resumed_lesson(game_ui, placement_tool, lesson_one: Dictionary, lesson_two: Dictionary) -> bool:
	if str(game_ui.get("_active_command_tab")) != "agent":
		_fail("Returning player did not resume in the AGENT command tab. active=%s" % str(game_ui.get("_active_command_tab")))
		return false
	if not _assert_unlocked_surfaces(game_ui, placement_tool, lesson_two, "CURRENT GOAL"):
		return false
	var editor = game_ui.get("_code_editor") as CodeEdit
	if editor == null or editor.text != str(lesson_two.get("starting_editor_text", "")):
		_fail("Returning player did not resume with the exact Lesson 2 starter source.")
		return false
	if not _assert_tutor_trace(game_ui, lesson_two):
		return false
	return _assert_lesson_buttons(game_ui, lesson_one, lesson_two, "DONE", "NOW")


func _assert_tutor_trace(game_ui, lesson: Dictionary) -> bool:
	var compiler_output = game_ui.get("_compiler_output") as RichTextLabel
	var trace: String = compiler_output.text if compiler_output else ""
	var first_hint := str(lesson.get("tutor", {}).get("first_hint", "")).strip_edges()
	if compiler_output == null or not trace.contains("TUTOR") or not trace.contains("TECHNICAL") or first_hint == "" or not trace.contains(first_hint):
		_fail("Onboarding trace did not show the active lesson's authored tutor hint before technical guidance. trace=%s" % trace)
		return false
	if trace.find("TUTOR") >= trace.find("TECHNICAL"):
		_fail("Onboarding trace placed technical output before its authored tutor guidance. trace=%s" % trace)
		return false
	return true


func _assert_lesson_buttons(game_ui, lesson_one: Dictionary, lesson_two: Dictionary, first_prefix: String, second_prefix: String) -> bool:
	var buttons_value = game_ui.get("_lesson_buttons")
	if typeof(buttons_value) != TYPE_DICTIONARY:
		_fail("Onboarding lesson-button registry was unavailable.")
		return false
	var buttons: Dictionary = buttons_value
	var lesson_one_button = buttons.get(str(lesson_one.get("id", "")), null) as Button
	var lesson_two_button = buttons.get(str(lesson_two.get("id", "")), null) as Button
	if lesson_one_button == null or lesson_two_button == null:
		_fail("Onboarding did not expose the first two lesson rows.")
		return false
	if not lesson_one_button.text.begins_with(first_prefix) or not lesson_two_button.text.begins_with(second_prefix):
		_fail("Onboarding lesson states were wrong. first=%s second=%s" % [lesson_one_button.text, lesson_two_button.text])
		return false
	if second_prefix == "LOCK" and not lesson_two_button.disabled:
		_fail("Fresh onboarding did not disable locked Lesson 2.")
		return false
	if second_prefix == "NOW" and lesson_two_button.disabled:
		_fail("Returning onboarding did not enable current Lesson 2.")
		return false
	return true


func _complete_brush_run(scene: Node, game_ui, agent_manager, tile, pending: Dictionary) -> bool:
	var decor_before := str(tile.decor_id)
	var start_result: Dictionary = pending.get("start_result", {})
	var run: Dictionary = start_result.get("run", {})
	var order_id := str(pending.get("order_id", ""))
	var run_id := str(pending.get("run_id", ""))
	var agent_id := str(pending.get("agent_id", run.get("agent_id", "")))
	if order_id == "" or run_id == "" or agent_id == "":
		_fail("Lesson 1 onboarding run did not expose its order, run, and named agent.")
		return false

	_prepare_agents(agent_manager)
	var assigned_actor = _agent_by_id(agent_manager, agent_id)
	if assigned_actor == null or not bool(assigned_actor.call("is_available")):
		_fail("Lesson 1 named agent %s was not available for Send." % agent_id)
		return false
	var rows_value = game_ui.get("_work_order_rows")
	if typeof(rows_value) != TYPE_DICTIONARY:
		_fail("Lesson 1 order was not exposed through the live crew-order surface.")
		return false
	var row_value = (rows_value as Dictionary).get(order_id, {})
	if typeof(row_value) != TYPE_DICTIONARY:
		_fail("Lesson 1 order row was not a UI dictionary.")
		return false
	var row: Dictionary = row_value
	var send_button = row.get("button", null) as Button
	if send_button == null or send_button.disabled or send_button.text != "Send" or str(row.get("intent", "")) != "send":
		_fail("Farm lock also blocked the Lesson 1 crew Send path. row=%s" % str(row))
		return false

	var event_start := _observed_world_actions.size()
	send_button.pressed.emit()
	var sound_manager = scene.get_node_or_null("SoundManager")
	if sound_manager == null or not _assert_feedback_event(game_ui, sound_manager, "run", "run_dispatch", 1):
		return false
	var active_value = assigned_actor.get("_active_decision")
	if typeof(active_value) != TYPE_DICTIONARY:
		_fail("Lesson 1 named agent did not accept the Send directive.")
		return false
	var active: Dictionary = active_value
	if str(active.get("forge_run_id", "")) != run_id or str(active.get("work_order_id", "")) != order_id:
		_fail("Lesson 1 Send lost its correlated run/order identity. active=%s" % str(active))
		return false

	for _frame in range(480):
		if scene.get("_pending_skill_forge_run").is_empty() and str(tile.decor_id) == "":
			break
		await process_frame
	if not scene.get("_pending_skill_forge_run").is_empty() or str(tile.decor_id) != "":
		_fail("Lesson 1 real Send did not finish and clear its brush target.")
		return false

	var matching_event: Dictionary = {}
	for index in range(event_start, _observed_world_actions.size()):
		var event_value = _observed_world_actions[index]
		if typeof(event_value) != TYPE_DICTIONARY:
			continue
		var event: Dictionary = event_value
		if str(event.get("forge_run_id", "")) == run_id and str(event.get("work_order_id", "")) == order_id:
			matching_event = event
			break
	if matching_event.is_empty() or not bool(matching_event.get("success", false)) or matching_event.get("grid_pos", Vector2i(-1, -1)) != tile.grid_pos:
		_fail("Lesson 1 unlock lacked a matching successful real world-action event. event=%s" % str(matching_event))
		return false
	if str(matching_event.get("subject", "")) != decor_before.replace("_", " "):
		_fail("Lesson 1 world-action receipt lost the observed brush subject. event=%s" % str(matching_event))
		return false
	if not _assert_feedback_event(game_ui, sound_manager, "receipt_passed", "receipt_pass", 1):
		return false
	if not _assert_feedback_event(game_ui, sound_manager, "lesson_complete", "lesson_complete", 1):
		return false
	return true


func _prepare_agents(agent_manager) -> void:
	for actor in agent_manager.agents:
		actor.call("_complete_active_decision")
		actor.set("_decision_timer", 999.0)
		actor.move_speed = 60.0


func _agent_by_id(agent_manager, agent_id: String):
	for actor in agent_manager.agents:
		if str(actor.agent_id) == agent_id:
			return actor
	return null


func _find_tillable_tile(grid):
	for tile in grid.tiles.values():
		if str(tile.terrain) == "grass" and not bool(tile.is_tilled) and tile.crop == null and str(tile.decor_id) == "" and str(tile.structure_id) == "":
			return tile
	return null


func _record_agent_world_action(event: Dictionary) -> void:
	_observed_world_actions.append(event.duplicate(true))


func _assert_feedback_event(game_ui, sound_manager: Node, feedback_state: String, stamp_name: String, expected_count: int) -> bool:
	var snapshot: Dictionary = game_ui.call("get_workbench_feedback_snapshot")
	var counts_value = snapshot.get("counts", {})
	var counts: Dictionary = counts_value if typeof(counts_value) == TYPE_DICTIONARY else {}
	if int(counts.get(feedback_state, 0)) != expected_count:
		_fail("Production %s feedback did not fire exactly once. snapshot=%s" % [feedback_state, str(snapshot)])
		return false
	if sound_manager.get_node_or_null("SFX_%s" % stamp_name) == null:
		_fail("Production %s feedback did not route through SoundManager stamp %s." % [feedback_state, stamp_name])
		return false
	return true


func _cleanup_temp_progress() -> void:
	if _temp_progress_path == "":
		return
	var absolute_path := ProjectSettings.globalize_path(_temp_progress_path)
	if FileAccess.file_exists(absolute_path):
		DirAccess.remove_absolute(absolute_path)


func _fail(message: String) -> void:
	if _failed:
		return
	_failed = true
	_cleanup_temp_progress()
	push_error(message)
	quit(1)
