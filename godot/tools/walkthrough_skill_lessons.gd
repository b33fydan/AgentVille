extends SceneTree

const PROGRESS_PATH := "user://agentville_session2_walkthrough.json"
const PROGRAM_NAME := "Session 2 Brush Proof"
const LESSON_IDS := [
	"run_brush_starter",
	"name_brush_receipt",
	"reassign_brush_agent",
	"retarget_selected_tile"
]
const PROGRAMS := [
	"agent \"Chuck\" {\n  observe selected_tile\n  when inspect.has_brush {\n    use clear_brush(selected_tile)\n  }\n  verify tile_state\n  receipt \"Clear Patch run\"\n}",
	"agent \"Chuck\" {\n  observe selected_tile\n  when inspect.has_brush {\n    use clear_brush(selected_tile)\n  }\n  verify tile_state\n  receipt \"Brush Proof run\"\n}",
	"agent \"Bert\" {\n  observe selected_tile\n  when inspect.has_brush {\n    use clear_brush(selected_tile)\n  }\n  verify tile_state\n  receipt \"Brush Proof run\"\n}"
]
const STEP_DELTA := 0.05
const MAX_AGENT_STEPS := 240

var _failed := false
var _mode := ""


func _initialize() -> void:
	root.content_scale_size = Vector2i(1600, 900)
	root.size = Vector2i(1600, 900)
	var user_args := OS.get_cmdline_user_args()
	if user_args.size() != 1 or str(user_args[0]) not in ["fresh", "verify"]:
		push_error("Usage: -- fresh|verify")
		quit(1)
		return
	_mode = str(user_args[0])
	if _mode == "fresh":
		_cleanup_progress()
	call_deferred("_run")


func _run() -> void:
	if _mode == "fresh":
		await _run_fresh()
	else:
		await _run_verify()


func _run_fresh() -> void:
	var scene: Node = await _boot_game()
	if scene == null:
		return
	var progress = scene.get("_player_progress")
	var game_ui = scene.get_node_or_null("GameUI")
	var grid = scene.get_node_or_null("FarmWorld/GridManager")
	var agent_manager = scene.get_node_or_null("FarmWorld/AgentManager")
	var placement_tool = scene.get_node_or_null("PlacementTool")
	if progress == null or game_ui == null or grid == null or agent_manager == null or placement_tool == null:
		_fail("Fresh boot did not expose progress, UI, grid, crew, and selection systems.")
		return
	if str(progress.call("get_storage_path")) != PROGRESS_PATH:
		_fail("Fresh boot did not inject the isolated progress path before _ready().")
		return
	if not progress.call("get_completed_lessons").is_empty() or str(progress.call("get_current_lesson")) != LESSON_IDS[0]:
		_fail("Fresh boot did not start with lesson 1 and no receipts.")
		return

	var editor = game_ui.get("_code_editor") as CodeEdit
	var compile_button = game_ui.get("_workbench_compile_button") as Button
	if editor == null or compile_button == null:
		_fail("Workbench editor or Compile button was unavailable.")
		return
	if not _prepare_agents(agent_manager):
		return

	print("SESSION 2 WALKTHROUGH · FRESH")
	print("progress path: %s" % ProjectSettings.globalize_path(PROGRESS_PATH))
	for index in range(3):
		var lesson_id := str(LESSON_IDS[index])
		if str(progress.call("get_current_lesson")) != lesson_id:
			_fail("Lesson %s was not current before its run." % (index + 1))
			return
		var brush_tile = _find_brush_tile(grid)
		if brush_tile == null:
			_fail("Lesson %s could not find a fresh brush tile." % (index + 1))
			return

		placement_tool.call("set_tool", "select")
		placement_tool.call("_apply_to_tile", brush_tile)
		await process_frame
		editor.text = str(PROGRAMS[index])
		compile_button.pressed.emit()
		await process_frame

		var pending_value = scene.get("_pending_skill_forge_run")
		if typeof(pending_value) != TYPE_DICTIONARY or pending_value.is_empty():
			_fail("Lesson %s did not establish a pending world check." % (index + 1))
			return
		var pending: Dictionary = pending_value.duplicate(true)
		if str(pending.get("origin", "")) != "workbench":
			_fail("Lesson %s lost its Workbench origin." % (index + 1))
			return
		if str(pending.get("lesson_id", "")) != lesson_id:
			_fail("Lesson %s pending run targeted the wrong curriculum step." % (index + 1))
			return
		if pending.get("target_tile", Vector2i(-1, -1)) != brush_tile.grid_pos:
			_fail("Lesson %s pending run lost the selected brush target." % (index + 1))
			return
		if str(pending.get("source_text", "")) != str(PROGRAMS[index]):
			_fail("Lesson %s pending run did not preserve the exact editor source." % (index + 1))
			return

		if index == 2 and not await _save_current_program(game_ui, progress):
			return
		if not await _send_and_complete_brush_run(scene, game_ui, agent_manager, brush_tile, pending):
			return
		await process_frame
		await process_frame

		if not bool(progress.call("is_lesson_completed", lesson_id)):
			_fail("Lesson %s did not complete after its correlated terminal event." % (index + 1))
			return
		var expected_next := str(LESSON_IDS[index + 1])
		if str(progress.call("get_current_lesson")) != expected_next:
			_fail("Lesson %s did not advance to %s." % [index + 1, expected_next])
			return
		var receipt := _latest_lesson_receipt(game_ui)
		print("lesson %s: %s tile=(%s,%s)" % [index + 1, receipt, brush_tile.grid_pos.x, brush_tile.grid_pos.y])
		print("program %s:\n%s" % [index + 1, PROGRAMS[index]])

	if not await _set_live_view_toggles(game_ui, progress):
		return
	if not FileAccess.file_exists(PROGRESS_PATH):
		_fail("Fresh walkthrough did not write its progress file.")
		return

	print("saved program: %s (exact=%s)" % [PROGRAM_NAME, str(progress.call("get_program", PROGRAM_NAME)) == PROGRAMS[2]])
	print("view toggles: %s" % str(progress.call("get_view_toggles")))
	print("fresh persisted: completed=%s current=%s" % [str(progress.call("get_completed_lessons")), progress.call("get_current_lesson")])
	print("Run the verify mode in a new Godot process.")
	scene.queue_free()
	await process_frame
	await process_frame
	if not _failed:
		quit()


func _run_verify() -> void:
	if not FileAccess.file_exists(PROGRESS_PATH):
		_fail("Verify mode could not find the progress file created by fresh mode.")
		return
	var scene: Node = await _boot_game()
	if scene == null:
		return
	var progress = scene.get("_player_progress")
	var game_ui = scene.get_node_or_null("GameUI")
	var grid = scene.get_node_or_null("FarmWorld/GridManager")
	if progress == null or game_ui == null or grid == null:
		_fail("Verify boot did not expose progress, UI, and world systems.")
		return

	var completed: Array = progress.call("get_completed_lessons")
	if completed != LESSON_IDS.slice(0, 3):
		_fail("Restart did not restore exactly lessons 1-3. completed=%s" % str(completed))
		return
	if str(progress.call("get_current_lesson")) != LESSON_IDS[3]:
		_fail("Restart did not restore lesson 4 as current.")
		return
	if not _verify_ladder(game_ui):
		return
	if str(progress.call("get_program", PROGRAM_NAME)) != PROGRAMS[2]:
		_fail("Restart did not restore the exact saved Bert program.")
		return
	if not _verify_saved_program_ui(game_ui):
		return

	var expected_toggles := {
		"grid": true,
		"shadows": false,
		"ambient_occlusion": false
	}
	if progress.call("get_view_toggles") != expected_toggles:
		_fail("Restart did not restore view toggle persistence. observed=%s" % str(progress.call("get_view_toggles")))
		return
	if game_ui.call("get_view_toggle_states") != expected_toggles:
		_fail("Restart did not apply persisted toggles to the live UI.")
		return
	if not bool(grid.get("show_grid")):
		_fail("Restart did not apply the persisted grid setting to the world.")
		return
	var sun = scene.get("_sun")
	var environment = scene.get("_environment")
	if sun == null or bool(sun.shadow_enabled):
		_fail("Restart did not apply the persisted shadows setting.")
		return
	if environment == null or bool(environment.ssao_enabled):
		_fail("Restart did not apply the persisted ambient occlusion setting.")
		return

	print("SESSION 2 WALKTHROUGH · VERIFY")
	print("restart restored: completed=%s current=%s" % [str(completed), progress.call("get_current_lesson")])
	print("ladder: L1 DONE · L2 DONE · L3 DONE · L4 NOW · L5 LOCK")
	print("saved program: %s (exact source restored)" % PROGRAM_NAME)
	print("view toggles: %s (UI and world applied)" % str(expected_toggles))
	print("restart verification passed; cleaning isolated progress file")
	scene.queue_free()
	await process_frame
	await process_frame
	_cleanup_progress()
	if FileAccess.file_exists(PROGRESS_PATH):
		_fail("Verify mode could not clean its isolated progress file.")
		return
	if not _failed:
		quit()


func _boot_game() -> Node:
	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	scene.set("progress_storage_path", PROGRESS_PATH)
	root.add_child(scene)
	await process_frame
	await process_frame
	await process_frame
	return scene


func _save_current_program(game_ui, progress) -> bool:
	var program_name_edit = game_ui.get("_program_name_edit") as LineEdit
	var save_button = game_ui.get("_program_save_button") as Button
	if program_name_edit == null or save_button == null:
		_fail("Program shelf save controls were unavailable.")
		return false
	program_name_edit.text = PROGRAM_NAME
	program_name_edit.text_changed.emit(PROGRAM_NAME)
	await process_frame
	if save_button.disabled:
		_fail("Compiled Bert program did not enable Program Shelf saving.")
		return false
	save_button.pressed.emit()
	await process_frame
	if str(progress.call("get_program", PROGRAM_NAME)) != PROGRAMS[2]:
		_fail("Program Shelf did not save the exact compiled Bert source.")
		return false
	return true


func _set_live_view_toggles(game_ui, progress) -> bool:
	var buttons_value = game_ui.get("_view_toggle_buttons")
	if typeof(buttons_value) != TYPE_DICTIONARY:
		_fail("Live view toggle registry was unavailable.")
		return false
	var buttons: Dictionary = buttons_value
	var desired := {
		"grid": true,
		"shadows": false,
		"ambient_occlusion": false
	}
	for toggle_id in desired.keys():
		var button = buttons.get(toggle_id, null) as Button
		if button == null:
			_fail("Live %s toggle was unavailable." % toggle_id)
			return false
		button.button_pressed = bool(desired[toggle_id])
		await process_frame
	if progress.call("get_view_toggles") != desired:
		_fail("Live view controls did not persist through Game. observed=%s" % str(progress.call("get_view_toggles")))
		return false
	if game_ui.call("get_view_toggle_states") != desired:
		_fail("Live view controls did not retain their requested UI states.")
		return false
	return true


func _verify_ladder(game_ui) -> bool:
	var buttons_value = game_ui.get("_lesson_buttons")
	if typeof(buttons_value) != TYPE_DICTIONARY:
		_fail("Restart lesson button registry was unavailable.")
		return false
	var buttons: Dictionary = buttons_value
	for index in range(3):
		var button = buttons.get(LESSON_IDS[index], null) as Button
		if button == null or button.disabled or not button.text.begins_with("DONE"):
			_fail("Restart ladder did not mark lesson %s DONE." % (index + 1))
			return false
	var lesson_four = buttons.get(LESSON_IDS[3], null) as Button
	if lesson_four == null or lesson_four.disabled or not lesson_four.text.begins_with("NOW"):
		_fail("Restart ladder did not mark lesson 4 NOW.")
		return false
	var rows_value = game_ui.get("_lesson_rows")
	if typeof(rows_value) != TYPE_ARRAY or rows_value.size() < 5:
		_fail("Restart ladder did not expose lesson 5 for its lock check.")
		return false
	var lesson_five_id := str(rows_value[4].get("id", ""))
	var lesson_five = buttons.get(lesson_five_id, null) as Button
	if lesson_five == null or not lesson_five.disabled or not lesson_five.text.begins_with("LOCK"):
		_fail("Restart ladder did not keep lesson 5 locked.")
		return false
	var goal = game_ui.get("_workbench_lesson_goal_label") as Label
	if goal == null or not goal.text.begins_with("LESSON 04"):
		_fail("Restart Workbench goal did not name lesson 4.")
		return false
	return true


func _verify_saved_program_ui(game_ui) -> bool:
	var picker = game_ui.get("_program_picker") as OptionButton
	if picker == null:
		_fail("Restart Program Shelf picker was unavailable.")
		return false
	for index in range(picker.item_count):
		if picker.get_item_text(index) == PROGRAM_NAME:
			return true
	_fail("Restart Program Shelf did not list the saved program.")
	return false


func _prepare_agents(agent_manager) -> bool:
	if agent_manager.agents.is_empty():
		_fail("Fresh walkthrough did not spawn the farm crew.")
		return false
	for actor in agent_manager.agents:
		actor.call("_complete_active_decision")
		actor.set_process(false)
		actor.set("_decision_timer", 999.0)
		actor.move_speed = 24.0
		if not bool(actor.call("is_available")):
			_fail("%s was not available before the live lesson runs." % str(actor.display_name))
			return false
	return true


func _send_and_complete_brush_run(scene: Node, game_ui, agent_manager, tile, pending: Dictionary) -> bool:
	var decor_before := str(tile.decor_id)
	if decor_before not in ["tall_grass", "flower_patch"]:
		_fail("Correlated brush target changed before Send.")
		return false

	var order_id := str(pending.get("order_id", ""))
	var run_id := str(pending.get("run_id", ""))
	var expected_agent_id := str(pending.get("agent_id", "")).to_lower()
	if order_id == "" or run_id == "" or expected_agent_id == "":
		_fail("Pending lesson run did not expose its order, run, and named agent ids.")
		return false

	var expected_actor = _agent_by_id(agent_manager, expected_agent_id)
	if expected_actor == null:
		_fail("Named lesson agent %s was not present in the live crew." % expected_agent_id)
		return false
	if not bool(expected_actor.call("is_available")):
		_fail("Named lesson agent %s was busy before Send." % expected_agent_id)
		return false

	var rows_value = game_ui.get("_work_order_rows")
	if typeof(rows_value) != TYPE_DICTIONARY or not rows_value.has(order_id):
		_fail("Compiled lesson order %s was not rendered in the live CREW ORDERS list." % order_id)
		return false
	var row: Dictionary = rows_value[order_id]
	var send_button = row.get("button", null) as Button
	if send_button == null or send_button.name != "WorkOrderCommand_%s" % order_id:
		_fail("Compiled lesson order %s did not expose its production command button." % order_id)
		return false
	if str(row.get("intent", "")) != "send" or send_button.text != "Send" or send_button.disabled:
		_fail("Compiled lesson order was not ready for live Send. intent=%s text=%s disabled=%s" % [row.get("intent", ""), send_button.text, send_button.disabled])
		return false

	# This is the same control the player clicks. Its signal crosses GameUI,
	# Game, AgentManager, and the named AgentActor before any world mutation.
	send_button.pressed.emit()

	var work_orders_value = scene.get("work_orders")
	if typeof(work_orders_value) != TYPE_DICTIONARY or not work_orders_value.has(order_id):
		_fail("Live Send lost correlated order %s." % order_id)
		return false
	var queued_order: Dictionary = work_orders_value[order_id]
	if str(queued_order.get("status", "")) != "queued":
		_fail("Live Send did not queue order %s. status=%s" % [order_id, queued_order.get("status", "")])
		return false

	var active: Dictionary = expected_actor.get("_active_decision")
	if str(active.get("forge_run_id", "")) != run_id \
		or str(active.get("work_order_id", "")) != order_id \
		or str(active.get("action", "")) != "clear_brush" \
		or active.get("target_tile", Vector2i(-1, -1)) != tile.grid_pos \
		or str(active.get("guard_condition", "")) != "inspect.has_brush" \
		or str(active.get("guard_action", "")) != "clear_brush":
		_fail("Named agent did not accept the exact correlated brush directive. active=%s" % str(active))
		return false
	for actor in agent_manager.agents:
		if actor == expected_actor:
			continue
		if str((actor.get("_active_decision") as Dictionary).get("forge_run_id", "")) == run_id:
			_fail("More than one crew member claimed lesson run %s." % run_id)
			return false

	var terminal_step := -1
	for step in range(MAX_AGENT_STEPS):
		# Pump only the assigned actor. Selection is a real player event and can
		# shorten another crew member's autonomy timer; unrelated NPC decisions
		# must not make this acceptance walkthrough nondeterministic.
		expected_actor.call("_process", STEP_DELTA)
		await process_frame
		var live_pending = scene.get("_pending_skill_forge_run")
		var live_orders = scene.get("work_orders")
		var order_status := str(live_orders.get(order_id, {}).get("status", "")) if typeof(live_orders) == TYPE_DICTIONARY else "missing"
		if typeof(live_pending) == TYPE_DICTIONARY and live_pending.is_empty() and order_status != "done":
			_fail("Lesson run closed without completing its real crew order. status=%s" % order_status)
			return false
		if typeof(live_pending) == TYPE_DICTIONARY and live_pending.is_empty() \
			and order_status == "done" and bool(expected_actor.call("is_available")):
			terminal_step = step + 1
			break

	if terminal_step < 0:
		var compiler_output = game_ui.get("_compiler_output") as RichTextLabel
		_fail("Live lesson order timed out. actor=%s active=%s path=%s reachable=%s order=%s pending=%s tile=%s trace=%s" % [
			expected_agent_id,
			expected_actor.get("_active_decision"),
			expected_actor.get("_movement_path"),
			expected_actor.get("_route_reachable"),
			scene.get("work_orders").get(order_id, {}),
			scene.get("_pending_skill_forge_run"),
			tile.decor_id,
			compiler_output.text if compiler_output else "missing"
		])
		return false
	if str(tile.decor_id) != "":
		_fail("Named AgentActor finished without clearing its target brush.")
		return false
	if not _has_correlated_agent_event(scene, pending, tile.grid_pos):
		_fail("GameEventLog did not record the real correlated AgentActor world action.")
		return false
	if not _has_correlated_queued_event(scene, pending, tile.grid_pos):
		_fail("GameEventLog did not record the live queued work order.")
		return false

	await process_frame
	rows_value = game_ui.get("_work_order_rows")
	if typeof(rows_value) != TYPE_DICTIONARY or not rows_value.has(order_id):
		_fail("Completed live order disappeared before its terminal UI proof.")
		return false
	row = rows_value[order_id]
	var clear_button = row.get("button", null) as Button
	if str(row.get("intent", "")) != "clear" or clear_button == null or clear_button.text != "Clear" or clear_button.disabled:
		_fail("Completed live order did not become a clearable Done row.")
		return false

	var compiler_output = game_ui.get("_compiler_output") as RichTextLabel
	var trace: String = compiler_output.text if compiler_output else ""
	if not trace.contains("WORLD CHECK") or not trace.contains("PASSED") or not trace.contains("TUTOR") or not trace.contains("TECHNICAL"):
		_fail("Live lesson terminal trace lost its passed tutor/technical evidence. trace=%s" % trace)
		return false
	print("live Send: order=%s agent=%s run=%s steps=%s event=agent_world_action" % [order_id, expected_agent_id, run_id, terminal_step])
	return true


func _agent_by_id(agent_manager, agent_id: String):
	for actor in agent_manager.agents:
		if str(actor.agent_id).to_lower() == agent_id:
			return actor
	return null


func _has_correlated_agent_event(scene: Node, pending: Dictionary, target: Vector2i) -> bool:
	var event_log = scene.get("_event_log")
	if event_log == null:
		return false
	var start_result: Dictionary = pending.get("start_result", {})
	var run: Dictionary = start_result.get("run", {})
	for event in event_log.events:
		if str(event.get("type", "")) != "agent_world_action":
			continue
		if str(event.get("forge_run_id", "")) == str(pending.get("run_id", "")) \
			and str(event.get("work_order_id", "")) == str(pending.get("order_id", "")) \
			and str(event.get("agent_id", "")) == str(pending.get("agent_id", "")) \
			and str(event.get("action", "")) == "clear_brush" \
			and event.get("grid_pos", Vector2i(-1, -1)) == target \
			and bool(event.get("success", false)) \
			and str(event.get("skill_id", "")) == str(run.get("skill_id", "")) \
			and str(event.get("skill_name", "")) == str(run.get("skill_name", "")):
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


func _find_brush_tile(grid):
	for tile in grid.tiles.values():
		if str(tile.decor_id) in ["tall_grass", "flower_patch"]:
			return tile
	return null


func _latest_lesson_receipt(game_ui) -> String:
	var entries_value = game_ui.get("_field_log_entries")
	if typeof(entries_value) != TYPE_ARRAY:
		return "lesson receipt missing"
	var entries: Array = entries_value
	for index in range(entries.size() - 1, -1, -1):
		var entry := str(entries[index])
		if entry.begins_with("Lesson complete:"):
			return entry
	return "lesson receipt missing"


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
