extends SceneTree

const PROGRESS_PATH := "user://agentville_qa_cold_start.json"
const PROGRAM_NAME := "Cold Start Brush"
const CAPTURE_SIZE := Vector2i(1600, 900)
const STEP_DELTA := 0.05
const MAX_AGENT_STEPS := 240
const MAX_CAPTURE_ATTEMPTS := 5
const MAX_BLACK_SAMPLE_RATIO := 0.02

const LESSON_ONE_ID := "run_brush_starter"
const LESSON_TWO_ID := "name_brush_receipt"
const LESSON_THREE_ID := "reassign_brush_agent"
const LESSON_ONE_SOURCE := "agent \"Chuck\" {\n  observe selected_tile\n  when inspect.has_brush {\n    use clear_brush(selected_tile)\n  }\n  verify tile_state\n  receipt \"Clear Patch run\"\n}"
const LESSON_ONE_GOAL := "LESSON 01 · Run the brush starter\nSelect a brush tile, run the starter, send its order, then read the receipt."
const LESSON_TWO_GOAL := "LESSON 02 · Name the proof\nChange the receipt label to Brush Proof run, then clear a second brush tile."
const LESSON_ONE_FIRST_HINT := "A trigger starts the sequence. Select brush, then run and send the starter."
const PENDING_TUTOR_COPY := "The crew is changing the farm. Wait for the world check."
const PASSED_CHECK_TUTOR_COPY := "The tile-state check matched the farm. Read the receipt to see which decor state it proved."
const LESSON_ONE_SUCCESS_COPY := "The receipt proves the brush left the tile. That sequence is a manually triggered agent run."
const FREE_PLAY_LESSON_COPY := "Lesson Spec -> world change checked against the success condition."
const DAY_ADVANCE_COPY := "A warm morning rolls in. Crops advanced one stage."

var _failed := false


func _initialize() -> void:
	root.content_scale_size = CAPTURE_SIZE
	root.size = CAPTURE_SIZE
	_cleanup_progress()
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		_fail("Cold-start QA needs a normal renderer; run without --headless.")
		return

	var scene: Node = await _boot_game()
	if scene == null or _failed:
		return
	var systems := _scene_systems(scene)
	if systems.is_empty():
		return
	var progress = systems["progress"]
	var game_ui = systems["game_ui"]
	var grid = systems["grid"]
	var agent_manager = systems["agent_manager"]
	var placement_tool = systems["placement_tool"]

	if not await _capture_step(1, "boot"):
		return
	if str(progress.call("get_storage_path")) != PROGRESS_PATH:
		_fail("Fresh boot did not inject the isolated progress path before _ready().")
		return
	if not progress.call("get_completed_lessons").is_empty() or str(progress.call("get_current_lesson")) != LESSON_ONE_ID:
		_fail("Fresh boot did not start with lesson 1 and no completed lessons.")
		return
	if str(game_ui.get("_active_command_tab")) != "agent":
		_fail("Fresh boot opened the %s command tab instead of landing the player in AGENT lesson 1." % str(game_ui.get("_active_command_tab")).to_upper())
		return
	if not _assert_fresh_lesson_ui(game_ui):
		return
	if not _prepare_agents(agent_manager):
		return

	var lesson_tile = _find_brush_tile(grid)
	if lesson_tile == null:
		_fail("Fresh farm did not expose a brush tile for lesson 1.")
		return
	placement_tool.call("set_tool", "select")
	placement_tool.call("_apply_to_tile", lesson_tile)
	await process_frame
	if not bool(placement_tool.call("has_selected_tile")) or placement_tool.call("get_selected_grid_pos") != lesson_tile.grid_pos:
		_fail("Lesson 1 did not retain the production selected_tile target.")
		return
	var compiler_output = game_ui.get("_compiler_output") as RichTextLabel
	if compiler_output == null or not _trace_contains_all(compiler_output.text, ["TUTOR", LESSON_ONE_FIRST_HINT, "TECHNICAL", "stage     TARGET SELECTED"]):
		_fail("Selected lesson target did not render the exact first tutor hint before the technical trace.")
		return

	var editor = game_ui.get("_code_editor") as CodeEdit
	var compile_button = game_ui.get("_workbench_compile_button") as Button
	if editor == null or compile_button == null:
		_fail("Lesson 1 Workbench editor or Compile button was unavailable.")
		return
	editor.text = LESSON_ONE_SOURCE
	compile_button.pressed.emit()
	await process_frame

	var pending_value = scene.get("_pending_skill_forge_run")
	if typeof(pending_value) != TYPE_DICTIONARY or pending_value.is_empty():
		_fail("Lesson 1 Compile did not establish a pending world check.")
		return
	var lesson_pending: Dictionary = pending_value.duplicate(true)
	if not _assert_pending_run(lesson_pending, "workbench", LESSON_ONE_ID, lesson_tile.grid_pos, LESSON_ONE_SOURCE):
		return
	compiler_output = game_ui.get("_compiler_output") as RichTextLabel
	if compiler_output == null or not _trace_contains_all(compiler_output.text, [
		"TUTOR",
		PENDING_TUTOR_COPY,
		"TECHNICAL",
		"stage     ORDER DRAFTED",
		"status    PENDING WORLD CHECK",
		"target    (%s, %s) · selected_tile" % [lesson_tile.grid_pos.x, lesson_tile.grid_pos.y]
	]):
		_fail("Lesson 1 draft lost its exact pending tutor copy, technical stage, or selected target.")
		return
	if not await _save_compiled_program(game_ui, progress):
		return
	_select_command_tab(game_ui, "crew")
	if not await _capture_step(2, "lesson-drafted"):
		return
	if not await _send_and_complete_brush_run(scene, game_ui, agent_manager, lesson_tile, lesson_pending):
		return
	await process_frame
	await process_frame

	if progress.call("get_completed_lessons") != [LESSON_ONE_ID] or str(progress.call("get_current_lesson")) != LESSON_TWO_ID:
		_fail("Lesson 1 completion did not persist exactly one mastery receipt and advance to lesson 2.")
		return
	if not _assert_lesson_one_complete_ui(game_ui):
		return
	compiler_output = game_ui.get("_compiler_output") as RichTextLabel
	if compiler_output == null or not _trace_contains_all(compiler_output.text, [
		"TUTOR",
		PASSED_CHECK_TUTOR_COPY,
		LESSON_ONE_SUCCESS_COPY,
		"TECHNICAL",
		"stage     WORLD CHECK",
		"status    PASSED"
	]):
		_fail("Lesson 1 terminal trace lost its exact passed tutor and technical evidence.")
		return
	_select_command_tab(game_ui, "agent")
	_scroll_command_page_to_top(game_ui)
	if not await _capture_step(3, "lesson-complete"):
		return

	var free_play_tile = _find_brush_tile(grid)
	if free_play_tile == null:
		_fail("Fresh farm did not expose a second brush tile for free play.")
		return
	placement_tool.call("set_tool", "select")
	placement_tool.call("_apply_to_tile", free_play_tile)
	await process_frame
	if placement_tool.call("get_selected_grid_pos") != free_play_tile.grid_pos:
		_fail("Free-play Forge run did not retain its selected tile.")
		return
	if not await _select_forge_template(game_ui, "clear_patch_starter"):
		return
	var forge_run_button = game_ui.get("_skill_forge_run_button") as Button
	if forge_run_button == null or forge_run_button.disabled:
		_fail("Clear Patch free-play Run button was unavailable.")
		return
	forge_run_button.pressed.emit()
	await process_frame

	pending_value = scene.get("_pending_skill_forge_run")
	if typeof(pending_value) != TYPE_DICTIONARY or pending_value.is_empty():
		_fail("Free-play Clear Patch did not establish a pending world check.")
		return
	var free_play_pending: Dictionary = pending_value.duplicate(true)
	if not _assert_pending_run(free_play_pending, "skill_forge", "", free_play_tile.grid_pos, ""):
		return
	if not _assert_free_play_forge_ui(game_ui, false):
		return
	if not await _send_and_complete_brush_run(scene, game_ui, agent_manager, free_play_tile, free_play_pending):
		return
	await process_frame
	await process_frame
	if progress.call("get_completed_lessons") != [LESSON_ONE_ID] or str(progress.call("get_current_lesson")) != LESSON_TWO_ID:
		_fail("Legacy free play incorrectly granted lesson 2 mastery.")
		return
	if not _assert_free_play_forge_ui(game_ui, true):
		return
	_select_command_tab(game_ui, "agent")
	_scroll_command_page_to_control(game_ui, game_ui.get("_skill_forge_result_label") as Control)
	if not await _capture_step(4, "free-play"):
		return

	_select_command_tab(game_ui, "world")
	var end_day_button = game_ui.get_node_or_null("UIRoot/CommandDock").find_child("EndDayButton", true, false) as Button
	if end_day_button == null or end_day_button.disabled:
		_fail("WORLD did not expose the production END DAY button.")
		return
	_scroll_command_page_to_control(game_ui, end_day_button)
	var event_log = scene.get("_event_log")
	var day_before := int(grid.day)
	end_day_button.pressed.emit()
	await process_frame
	await process_frame
	if int(grid.day) != day_before + 1 or int(grid.day) != 2:
		_fail("END DAY did not advance the live GridManager from day 1 to day 2.")
		return
	var day_label = game_ui.get("_day_label") as Label
	var toast_label = game_ui.get("_toast_label") as Label
	if day_label == null or day_label.text != "DAY 2 · MORNING":
		_fail("END DAY did not refresh the live day label to day 2.")
		return
	if toast_label == null or toast_label.text != DAY_ADVANCE_COPY:
		_fail("END DAY did not render the expected player-facing day-advance copy.")
		return
	if not _has_day_event(event_log, "day_summary", 1, 0) or not _has_day_event(event_log, "day_advanced", 2, 1):
		_fail("END DAY did not log both the day-1 summary and day-2 advance event.")
		return
	if not _assert_no_stuck_run(scene, agent_manager, "after END DAY"):
		return
	if not await _capture_step(5, "day-advanced"):
		return

	if not FileAccess.file_exists(PROGRESS_PATH):
		_fail("Cold-start QA did not write its isolated progress file before reload.")
		return
	var old_scene = scene
	old_scene.queue_free()
	await process_frame
	await process_frame
	await process_frame
	if is_instance_valid(old_scene):
		_fail("Cold-start QA could not fully tear down the first Main scene before reload.")
		return

	scene = await _boot_game()
	if scene == null or _failed:
		return
	systems = _scene_systems(scene)
	if systems.is_empty():
		return
	progress = systems["progress"]
	game_ui = systems["game_ui"]
	grid = systems["grid"]
	agent_manager = systems["agent_manager"]
	if str(progress.call("get_storage_path")) != PROGRESS_PATH:
		_fail("Reloaded Main scene did not reuse the isolated progress file.")
		return
	if progress.call("get_completed_lessons") != [LESSON_ONE_ID] or str(progress.call("get_current_lesson")) != LESSON_TWO_ID:
		_fail("Reload did not restore lesson 1 DONE and lesson 2 NOW exactly.")
		return
	if str(progress.call("get_program", PROGRAM_NAME)) != LESSON_ONE_SOURCE:
		_fail("Reload did not restore the exact named compiled program.")
		return
	if not _assert_reloaded_lesson_ui(game_ui):
		return
	if not await _load_saved_program_from_ui(game_ui):
		return
	if not scene.get("_pending_skill_forge_run").is_empty() or not scene.get("work_orders").is_empty():
		_fail("Reload restored stale runtime work instead of a clean farm session.")
		return
	_select_command_tab(game_ui, "agent")
	_scroll_command_page_to_top(game_ui)
	if not await _capture_step(6, "reloaded"):
		return

	scene.queue_free()
	await process_frame
	await process_frame
	_cleanup_progress()
	if FileAccess.file_exists(PROGRESS_PATH):
		_fail("Cold-start QA could not clean its isolated progress file.")
		return
	if not _failed:
		print("Cold-start QA passed: fresh boot -> lesson 1 -> free play -> day 2 -> save/reload.")
		quit()


func _boot_game() -> Node:
	var packed_scene = load("res://scenes/Main.tscn")
	if packed_scene == null:
		_fail("Cold-start QA could not load res://scenes/Main.tscn.")
		return null
	var scene: Node = packed_scene.instantiate()
	scene.set("progress_storage_path", PROGRESS_PATH)
	root.add_child(scene)
	await process_frame
	await process_frame
	await process_frame
	return scene


func _scene_systems(scene: Node) -> Dictionary:
	var systems := {
		"progress": scene.get("_player_progress"),
		"game_ui": scene.get_node_or_null("GameUI"),
		"grid": scene.get_node_or_null("FarmWorld/GridManager"),
		"agent_manager": scene.get_node_or_null("FarmWorld/AgentManager"),
		"placement_tool": scene.get_node_or_null("PlacementTool")
	}
	for key in systems.keys():
		if systems[key] == null:
			_fail("Cold-start QA boot did not expose its %s integration." % str(key).replace("_", " "))
			return {}
	return systems


func _assert_fresh_lesson_ui(game_ui) -> bool:
	var workbench = game_ui.get("_code_workbench") as Control
	var goal = game_ui.get("_workbench_lesson_goal_label") as Label
	var editor = game_ui.get("_code_editor") as CodeEdit
	var runtime = game_ui.get("_workbench_runtime_label") as Label
	if workbench == null or not workbench.visible:
		_fail("Fresh boot did not leave the Agent Workbench open.")
		return false
	if goal == null or goal.text != LESSON_ONE_GOAL:
		_fail("Fresh boot did not present the one exact lesson-1 goal. observed=%s" % (goal.text if goal else "missing"))
		return false
	if editor == null or editor.text != LESSON_ONE_SOURCE:
		_fail("Fresh boot did not load the exact lesson-1 starter source.")
		return false
	if runtime == null or runtime.text != "READY  ·  LOCAL COMPILER":
		_fail("Fresh Workbench did not start in the local compiler READY state.")
		return false
	var buttons_value = game_ui.get("_lesson_buttons")
	if typeof(buttons_value) != TYPE_DICTIONARY:
		_fail("Fresh lesson ladder button registry was unavailable.")
		return false
	var buttons: Dictionary = buttons_value
	var lesson_one = buttons.get(LESSON_ONE_ID, null) as Button
	var lesson_two = buttons.get(LESSON_TWO_ID, null) as Button
	if lesson_one == null or lesson_one.disabled or not lesson_one.text.begins_with("NOW"):
		_fail("Fresh lesson 1 was not the current unlocked ladder row.")
		return false
	if lesson_two == null or not lesson_two.disabled or not lesson_two.text.begins_with("LOCK"):
		_fail("Fresh lesson 2 was not locked behind lesson 1.")
		return false
	return true


func _assert_pending_run(pending: Dictionary, origin: String, lesson_id: String, target: Vector2i, source_text: String) -> bool:
	if str(pending.get("origin", "")) != origin:
		_fail("Pending run lost its %s origin." % origin)
		return false
	if str(pending.get("lesson_id", "")) != lesson_id:
		_fail("Pending %s run carried the wrong lesson id." % origin)
		return false
	if pending.get("target_tile", Vector2i(-1, -1)) != target or str(pending.get("target_source", "")) != "selected_tile":
		_fail("Pending %s run lost its selected tile target." % origin)
		return false
	if str(pending.get("guard_condition", "")) != "inspect.has_brush" or str(pending.get("guard_action", "")) != "clear_brush":
		_fail("Pending %s run lost its brush guard or action." % origin)
		return false
	if str(pending.get("agent_id", "")) != "chuck":
		_fail("Pending %s run did not name Chuck." % origin)
		return false
	if str(pending.get("order_id", "")) == "" or str(pending.get("run_id", "")) == "":
		_fail("Pending %s run did not expose correlated run and order ids." % origin)
		return false
	if source_text != "" and str(pending.get("source_text", "")) != source_text:
		_fail("Pending Workbench run did not preserve the exact editor source.")
		return false
	return true


func _save_compiled_program(game_ui, progress) -> bool:
	var name_edit = game_ui.get("_program_name_edit") as LineEdit
	var save_button = game_ui.get("_program_save_button") as Button
	if name_edit == null or save_button == null:
		_fail("Program Shelf save controls were unavailable.")
		return false
	name_edit.text = PROGRAM_NAME
	name_edit.text_changed.emit(PROGRAM_NAME)
	await process_frame
	if save_button.disabled:
		_fail("Exact compiled lesson source did not enable Program Shelf saving.")
		return false
	save_button.pressed.emit()
	await process_frame
	if str(progress.call("get_program", PROGRAM_NAME)) != LESSON_ONE_SOURCE:
		_fail("Program Shelf did not persist the exact compiled lesson source.")
		return false
	if not FileAccess.file_exists(PROGRESS_PATH):
		_fail("Program Shelf did not write the isolated progress file.")
		return false
	return true


func _prepare_agents(agent_manager) -> bool:
	if agent_manager.agents.is_empty():
		_fail("Cold-start QA did not spawn the farm crew.")
		return false
	for actor in agent_manager.agents:
		actor.call("_complete_active_decision")
		actor.set_process(false)
		actor.set("_decision_timer", 999.0)
		actor.move_speed = 24.0
		if not bool(actor.call("is_available")):
			_fail("%s was not available before the scripted runs." % str(actor.display_name))
			return false
	return true


func _send_and_complete_brush_run(scene: Node, game_ui, agent_manager, tile, pending: Dictionary) -> bool:
	var decor_before := str(tile.decor_id)
	if decor_before not in ["tall_grass", "flower_patch"]:
		_fail("Correlated brush target changed before live Send.")
		return false
	var order_id := str(pending.get("order_id", ""))
	var run_id := str(pending.get("run_id", ""))
	var agent_id := str(pending.get("agent_id", ""))
	var actor = _agent_by_id(agent_manager, agent_id)
	if actor == null or not bool(actor.call("is_available")):
		_fail("Named agent %s was unavailable before live Send." % agent_id)
		return false

	var rows_value = game_ui.get("_work_order_rows")
	if typeof(rows_value) != TYPE_DICTIONARY or not rows_value.has(order_id):
		_fail("Correlated order %s was absent from the live CREW ORDERS list." % order_id)
		return false
	var row: Dictionary = rows_value[order_id]
	var send_button = row.get("button", null) as Button
	if send_button == null or send_button.name != "WorkOrderCommand_%s" % order_id or send_button.disabled or send_button.text != "Send" or str(row.get("intent", "")) != "send":
		_fail("Correlated order %s was not ready on its production Send control." % order_id)
		return false
	send_button.pressed.emit()

	var orders_value = scene.get("work_orders")
	if typeof(orders_value) != TYPE_DICTIONARY or str(orders_value.get(order_id, {}).get("status", "")) != "queued":
		_fail("Live Send did not queue correlated order %s." % order_id)
		return false
	var active: Dictionary = actor.get("_active_decision")
	if str(active.get("forge_run_id", "")) != run_id or str(active.get("work_order_id", "")) != order_id or str(active.get("action", "")) != "clear_brush" or active.get("target_tile", Vector2i(-1, -1)) != tile.grid_pos:
		_fail("Named AgentActor did not accept the exact correlated brush directive.")
		return false
	for other_actor in agent_manager.agents:
		if other_actor != actor and str((other_actor.get("_active_decision") as Dictionary).get("forge_run_id", "")) == run_id:
			_fail("More than one farmhand claimed Forge run %s." % run_id)
			return false

	var terminal_step := -1
	for step in range(MAX_AGENT_STEPS):
		actor.call("_process", STEP_DELTA)
		await process_frame
		var live_pending = scene.get("_pending_skill_forge_run")
		var live_orders = scene.get("work_orders")
		var status := str(live_orders.get(order_id, {}).get("status", "")) if typeof(live_orders) == TYPE_DICTIONARY else "missing"
		if typeof(live_pending) == TYPE_DICTIONARY and live_pending.is_empty() and status != "done":
			_fail("Correlated run closed without a Done crew order. status=%s" % status)
			return false
		if typeof(live_pending) == TYPE_DICTIONARY and live_pending.is_empty() and status == "done" and bool(actor.call("is_available")):
			terminal_step = step + 1
			break
	if terminal_step < 0:
		_fail("Live Send timed out for run %s; actor=%s order=%s pending=%s" % [run_id, str(actor.get("_active_decision")), str(scene.get("work_orders").get(order_id, {})), str(scene.get("_pending_skill_forge_run"))])
		return false
	if str(tile.decor_id) != "":
		_fail("Named AgentActor finished without clearing its target brush.")
		return false
	if not _has_correlated_agent_event(scene, pending, tile.grid_pos):
		_fail("GameEventLog did not record the matching successful AgentActor world action.")
		return false
	if not _has_correlated_queued_event(scene, pending, tile.grid_pos):
		_fail("GameEventLog did not record the matching queued work order.")
		return false

	await process_frame
	rows_value = game_ui.get("_work_order_rows")
	if typeof(rows_value) != TYPE_DICTIONARY or not rows_value.has(order_id):
		_fail("Done order disappeared before its terminal UI proof.")
		return false
	row = rows_value[order_id]
	var clear_button = row.get("button", null) as Button
	if str(row.get("intent", "")) != "clear" or clear_button == null or clear_button.text != "Clear" or clear_button.disabled:
		_fail("Done order did not become a clearable terminal row.")
		return false
	return true


func _assert_lesson_one_complete_ui(game_ui) -> bool:
	var buttons: Dictionary = game_ui.get("_lesson_buttons")
	var lesson_one = buttons.get(LESSON_ONE_ID, null) as Button
	var lesson_two = buttons.get(LESSON_TWO_ID, null) as Button
	var goal = game_ui.get("_workbench_lesson_goal_label") as Label
	if lesson_one == null or lesson_one.disabled or not lesson_one.text.begins_with("DONE"):
		_fail("Lesson 1 was not replayable and marked DONE after mastery.")
		return false
	if lesson_two == null or lesson_two.disabled or not lesson_two.text.begins_with("NOW"):
		_fail("Lesson 2 did not unlock as NOW after lesson 1.")
		return false
	if goal == null or goal.text != LESSON_TWO_GOAL:
		_fail("Workbench did not advance to the exact lesson-2 goal.")
		return false
	var entries_value = game_ui.get("_field_log_entries")
	if typeof(entries_value) != TYPE_ARRAY:
		_fail("Field Log did not expose lesson completion receipts.")
		return false
	for entry in entries_value:
		if str(entry).begins_with("Lesson complete: 01 · Run the brush starter"):
			return true
	_fail("Lesson 1 did not leave its named Field Log mastery receipt.")
	return false


func _select_forge_template(game_ui, template_id: String) -> bool:
	_select_command_tab(game_ui, "agent")
	var buttons_value = game_ui.get("_skill_forge_template_buttons")
	if typeof(buttons_value) != TYPE_DICTIONARY:
		_fail("Free-play Forge template registry was unavailable.")
		return false
	var button = buttons_value.get(template_id, null) as Button
	if button == null or button.disabled:
		_fail("Free-play Forge template %s was unavailable." % template_id)
		return false
	button.pressed.emit()
	await process_frame
	if str(game_ui.get("_active_skill_forge_template_id")) != template_id:
		_fail("Free-play Forge did not activate %s through its real template button." % template_id)
		return false
	return true


func _assert_free_play_forge_ui(game_ui, passed: bool) -> bool:
	var result_label = game_ui.get("_skill_forge_result_label") as Label
	var stage_label = game_ui.get("_skill_forge_stage_label") as Label
	var next_label = game_ui.get("_skill_forge_next_label") as Label
	var lesson_label = game_ui.get("_skill_forge_lesson_label") as Label
	var trace_label = game_ui.get("_skill_forge_trace_label") as Label
	if result_label == null or stage_label == null or next_label == null or lesson_label == null or trace_label == null:
		_fail("Free-play Forge result copy was unavailable.")
		return false
	if not passed:
		if result_label.text != "Started: Clear Patch" or stage_label.text != "Stage: Work Order | Clear Patch" or next_label.text != "Next Step: Send crew order":
			_fail("Free-play Forge draft did not render its honest Work Order and Send-next state.")
			return false
		if lesson_label.text != "Lesson Spec -> crew work order; send it, then wait for the world check.":
			_fail("Free-play Forge draft lost its exact lifecycle teaching copy.")
			return false
		return true
	if result_label.text != "Passed: Clear Patch" or stage_label.text != "Stage: World Check | Clear Patch" or next_label.text != "Next Step: Review verified receipt":
		_fail("Free-play Forge completion did not render its verified World Check state.")
		return false
	if lesson_label.text != FREE_PLAY_LESSON_COPY:
		_fail("Free-play Forge completion lost its exact world-check teaching copy.")
		return false
	if trace_label.text != "Run Trace: Spec > Directive > Work Order > World Check":
		_fail("Free-play Forge completion lost its terminal run trace.")
		return false
	return true


func _assert_no_stuck_run(scene: Node, agent_manager, context: String) -> bool:
	var pending_value = scene.get("_pending_skill_forge_run")
	if typeof(pending_value) != TYPE_DICTIONARY or not pending_value.is_empty():
		_fail("Cold-start QA retained a pending Forge run %s." % context)
		return false
	for actor in agent_manager.agents:
		if not bool(actor.call("is_available")):
			_fail("%s remained busy %s." % [str(actor.display_name), context])
			return false
	return true


func _assert_reloaded_lesson_ui(game_ui) -> bool:
	var buttons_value = game_ui.get("_lesson_buttons")
	if typeof(buttons_value) != TYPE_DICTIONARY:
		_fail("Reloaded lesson ladder was unavailable.")
		return false
	var buttons: Dictionary = buttons_value
	var lesson_one = buttons.get(LESSON_ONE_ID, null) as Button
	var lesson_two = buttons.get(LESSON_TWO_ID, null) as Button
	var lesson_three = buttons.get(LESSON_THREE_ID, null) as Button
	if lesson_one == null or lesson_one.disabled or not lesson_one.text.begins_with("DONE"):
		_fail("Reloaded ladder did not mark lesson 1 DONE.")
		return false
	if lesson_two == null or lesson_two.disabled or not lesson_two.text.begins_with("NOW"):
		_fail("Reloaded ladder did not mark lesson 2 NOW.")
		return false
	if lesson_three == null or not lesson_three.disabled or not lesson_three.text.begins_with("LOCK"):
		_fail("Reloaded ladder did not keep lesson 3 LOCKED.")
		return false
	var goal = game_ui.get("_workbench_lesson_goal_label") as Label
	if goal == null or goal.text != LESSON_TWO_GOAL:
		_fail("Reloaded Workbench did not restore the exact lesson-2 goal.")
		return false
	var picker = game_ui.get("_program_picker") as OptionButton
	if picker == null or _program_item_index(picker, PROGRAM_NAME) < 0:
		_fail("Reloaded Program Shelf did not list the saved cold-start program.")
		return false
	return true


func _load_saved_program_from_ui(game_ui) -> bool:
	var editor = game_ui.get("_code_editor") as CodeEdit
	var picker = game_ui.get("_program_picker") as OptionButton
	var load_button = game_ui.get("_program_load_button") as Button
	if editor == null or picker == null or load_button == null:
		_fail("Reloaded Program Shelf load controls were unavailable.")
		return false
	editor.text = "agent draft intentionally replaced"
	var index := _program_item_index(picker, PROGRAM_NAME)
	if index < 0:
		_fail("Reloaded Program Shelf could not select the saved cold-start program.")
		return false
	picker.select(index)
	if load_button.disabled:
		_fail("Reloaded Program Shelf kept Load disabled for a saved program.")
		return false
	load_button.pressed.emit()
	await process_frame
	if editor.text != LESSON_ONE_SOURCE:
		_fail("Reloaded Program Shelf did not restore the exact compiled source through Load.")
		return false
	return true


func _capture_step(index: int, slug: String) -> bool:
	var output_path := "res://artifacts/screenshots/agentville-qa-cold-start-%02d-%s.png" % [index, slug]
	for attempt in range(1, MAX_CAPTURE_ATTEMPTS + 1):
		await process_frame
		await process_frame
		await create_timer(0.45).timeout
		await process_frame
		var viewport_texture := root.get_texture()
		if viewport_texture == null:
			continue
		var image := viewport_texture.get_image()
		if image == null or image.get_size() != CAPTURE_SIZE:
			continue
		var black_ratio := _black_sample_ratio(image)
		if black_ratio > MAX_BLACK_SAMPLE_RATIO:
			print("Cold-start QA capture retry %s/%s for step %s: black sample ratio %.3f." % [attempt, MAX_CAPTURE_ATTEMPTS, index, black_ratio])
			continue
		var error := image.save_png(output_path)
		if error != OK:
			_fail("Cold-start QA could not save %s." % output_path)
			return false
		print("Cold-start QA capture: %s" % output_path)
		return true
	_fail("Cold-start QA capture %s never produced a complete 1600x900 frame." % index)
	return false


func _black_sample_ratio(image: Image) -> float:
	var black_samples := 0
	var sample_count := 0
	for y in range(0, image.get_height(), 8):
		for x in range(0, image.get_width(), 8):
			var color := image.get_pixel(x, y)
			sample_count += 1
			if color.a > 0.99 and maxf(color.r, maxf(color.g, color.b)) < 0.01:
				black_samples += 1
	return float(black_samples) / float(maxi(sample_count, 1))


func _select_command_tab(game_ui, tab_id: String) -> void:
	var buttons_value = game_ui.get("_command_tab_buttons")
	if typeof(buttons_value) != TYPE_DICTIONARY:
		return
	var button = buttons_value.get(tab_id, null) as Button
	if button:
		button.pressed.emit()


func _scroll_command_page_to_top(game_ui) -> void:
	var dock = game_ui.get_node_or_null("UIRoot/CommandDock")
	if dock == null:
		return
	var scroll = dock.find_child("CommandScroll", true, false) as ScrollContainer
	if scroll:
		scroll.scroll_vertical = 0


func _scroll_command_page_to_control(game_ui, control: Control) -> void:
	if control == null:
		return
	var dock = game_ui.get_node_or_null("UIRoot/CommandDock")
	if dock == null:
		return
	var scroll = dock.find_child("CommandScroll", true, false) as ScrollContainer
	if scroll:
		scroll.ensure_control_visible(control)


func _find_brush_tile(grid):
	for tile in grid.tiles.values():
		if str(tile.decor_id) in ["tall_grass", "flower_patch"]:
			return tile
	return null


func _agent_by_id(agent_manager, agent_id: String):
	for actor in agent_manager.agents:
		if str(actor.agent_id).to_lower() == agent_id.to_lower():
			return actor
	return null


func _has_correlated_agent_event(scene: Node, pending: Dictionary, target: Vector2i) -> bool:
	var event_log = scene.get("_event_log")
	if event_log == null:
		return false
	var start_result: Dictionary = pending.get("start_result", {})
	var run: Dictionary = start_result.get("run", {})
	for event in event_log.events:
		if str(event.get("type", "")) == "agent_world_action" \
			and str(event.get("forge_run_id", "")) == str(pending.get("run_id", "")) \
			and str(event.get("work_order_id", "")) == str(pending.get("order_id", "")) \
			and str(event.get("agent_id", "")) == str(pending.get("agent_id", "")) \
			and str(event.get("action", "")) == "clear_brush" \
			and event.get("grid_pos", Vector2i(-1, -1)) == target \
			and bool(event.get("success", false)) \
			and str(event.get("skill_id", "")) == str(run.get("skill_id", "")):
			return true
	return false


func _has_correlated_queued_event(scene: Node, pending: Dictionary, target: Vector2i) -> bool:
	var event_log = scene.get("_event_log")
	if event_log == null:
		return false
	for event in event_log.events:
		if str(event.get("type", "")) == "work_order" \
			and str(event.get("status", "")) == "queued" \
			and str(event.get("order_id", "")) == str(pending.get("order_id", "")) \
			and str(event.get("forge_run_id", "")) == str(pending.get("run_id", "")) \
			and event.get("target_tile", Vector2i(-1, -1)) == target:
			return true
	return false


func _has_day_event(event_log, event_type: String, day: int, previous_day: int) -> bool:
	if event_log == null:
		return false
	for event in event_log.events:
		if str(event.get("type", "")) != event_type or int(event.get("day", -1)) != day:
			continue
		if event_type != "day_advanced" or int(event.get("previous_day", -1)) == previous_day:
			return true
	return false


func _program_item_index(picker: OptionButton, program_name: String) -> int:
	for index in range(picker.item_count):
		if picker.get_item_text(index) == program_name:
			return index
	return -1


func _trace_contains_all(trace: String, expected_parts: Array) -> bool:
	for expected in expected_parts:
		if not trace.contains(str(expected)):
			return false
	return true


func _cleanup_progress() -> void:
	var absolute_path := ProjectSettings.globalize_path(PROGRESS_PATH)
	if FileAccess.file_exists(absolute_path):
		DirAccess.remove_absolute(absolute_path)


func _fail(message: String) -> void:
	if _failed:
		return
	_failed = true
	_cleanup_progress()
	push_error(message)
	quit(1)
