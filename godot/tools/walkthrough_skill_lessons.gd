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
	var placement_tool = scene.get_node_or_null("PlacementTool")
	if progress == null or game_ui == null or grid == null or placement_tool == null:
		_fail("Fresh boot did not expose progress, UI, grid, and selection systems.")
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
		if not _complete_brush_run(scene, brush_tile, pending):
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


func _complete_brush_run(scene: Node, tile, pending: Dictionary) -> bool:
	var decor_before := str(tile.decor_id)
	if decor_before not in ["tall_grass", "flower_patch"]:
		_fail("Correlated brush target changed before completion.")
		return false
	if int(tile.cut_with_sickle()) != -1 or str(tile.decor_id) != "":
		_fail("Walkthrough could not apply the real brush world mutation.")
		return false
	var start_result: Dictionary = pending.get("start_result", {})
	var run: Dictionary = start_result.get("run", {})
	scene.call("_on_agent_world_action", {
		"actor": "agent",
		"agent_id": str(pending.get("agent_id", run.get("agent_id", "chuck"))),
		"agent_name": str(pending.get("agent_name", run.get("agent_name", "Chuck"))),
		"action": "clear_brush",
		"grid_pos": tile.grid_pos,
		"success": true,
		"message": "%s cleared %s." % [str(pending.get("agent_name", "Crew")), decor_before.replace("_", " ")],
		"value": 0,
		"subject": decor_before,
		"resources": {"fiber": 2},
		"crafted_cost": {},
		"stamps": [],
		"work_order_id": str(pending.get("order_id", "")),
		"forge_run_id": str(pending.get("run_id", "")),
		"skill_id": str(run.get("skill_id", "")),
		"skill_name": str(run.get("skill_name", "Clear Patch"))
	})
	return true


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
