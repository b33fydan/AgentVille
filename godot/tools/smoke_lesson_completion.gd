extends SceneTree

const TEMP_PATH_PREFIX := "user://agentville_lesson_completion_smoke_"
const SAVED_PROGRAM_NAME := "Lesson One Clear"

var _failed := false
var _temp_progress_path := ""


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

	var progress = scene.get("_player_progress")
	var lesson_library = scene.get("_skill_lesson_library")
	var game_ui = scene.get_node_or_null("GameUI")
	var grid = scene.get_node_or_null("FarmWorld/GridManager")
	var placement_tool = scene.get_node_or_null("PlacementTool")
	if progress == null or lesson_library == null or game_ui == null or grid == null or placement_tool == null:
		_fail("Lesson integration did not expose progress, curriculum, UI, grid, and selection systems.")
		return
	if str(progress.call("get_storage_path")) != _temp_progress_path:
		_fail("Game did not use the isolated progress path before boot.")
		return

	var lessons_value = game_ui.get("_lesson_rows")
	if typeof(lessons_value) != TYPE_ARRAY or lessons_value.size() < 2:
		_fail("Lesson UI did not receive at least the first two curriculum rows.")
		return
	var lessons: Array = lessons_value
	if typeof(lessons[0]) != TYPE_DICTIONARY or typeof(lessons[1]) != TYPE_DICTIONARY:
		_fail("Lesson UI rows were not data dictionaries.")
		return
	var lesson_one: Dictionary = lessons[0]
	var lesson_two: Dictionary = lessons[1]
	var lesson_one_id := str(lesson_one.get("id", ""))
	var lesson_two_id := str(lesson_two.get("id", ""))
	if lesson_one_id == "" or lesson_two_id == "":
		_fail("First two curriculum rows did not expose stable ids.")
		return
	if str(progress.call("get_current_lesson")) != lesson_one_id:
		_fail("Fresh progress did not start on lesson 1. current=%s expected=%s" % [progress.call("get_current_lesson"), lesson_one_id])
		return
	if not _assert_initial_lesson_ui(game_ui, lesson_one, lesson_two):
		return

	# The legacy template Run path may execute real farm work, but it cannot award
	# mastery because it was not compiled by the player in the Workbench.
	var legacy_brush = _find_brush_tile(grid)
	if legacy_brush == null:
		_fail("Starter map did not expose brush for the legacy-run mastery guard.")
		return
	placement_tool.set_tool("select")
	placement_tool.call("_apply_to_tile", legacy_brush)
	if not _select_forge_template(game_ui, "clear_patch_starter"):
		return
	var forge_run_button = game_ui.get("_skill_forge_run_button") as Button
	if forge_run_button == null:
		_fail("Legacy Skill Forge Run button was unavailable.")
		return
	forge_run_button.pressed.emit()
	await process_frame
	var legacy_pending_value = scene.get("_pending_skill_forge_run")
	if typeof(legacy_pending_value) != TYPE_DICTIONARY or legacy_pending_value.is_empty():
		_fail("Legacy Skill Forge Run did not establish a correlated world check.")
		return
	var legacy_pending: Dictionary = legacy_pending_value.duplicate(true)
	if str(legacy_pending.get("origin", "")) != "skill_forge":
		_fail("Legacy Skill Forge run lost its non-Workbench origin. pending=%s" % str(legacy_pending))
		return
	if not _complete_brush_run(scene, legacy_brush, legacy_pending):
		return
	await process_frame
	if bool(progress.call("is_lesson_completed", lesson_one_id)) or str(progress.call("get_current_lesson")) != lesson_one_id:
		_fail("Legacy Skill Forge Run incorrectly granted lesson mastery.")
		return

	# Drive lesson 1 through the actual editor and Compile button. The lesson is
	# intentionally brush-backed so the terminal verifier observes a real change.
	var lesson_brush = _find_brush_tile(grid)
	if lesson_brush == null:
		_fail("Starter map did not expose a second brush for the Workbench lesson run.")
		return
	placement_tool.set_tool("select")
	placement_tool.call("_apply_to_tile", lesson_brush)
	var editor = game_ui.get("_code_editor") as CodeEdit
	var compile_button = game_ui.get("_workbench_compile_button") as Button
	if editor == null or compile_button == null:
		_fail("Workbench editor or Compile button was unavailable.")
		return
	var lesson_source := str(lesson_one.get("starting_editor_text", editor.text))
	if lesson_source.strip_edges() == "" or not lesson_source.contains("clear_brush"):
		_fail("Lesson 1 was not the brush-backed starter required by its integration smoke. source=%s" % lesson_source)
		return
	editor.text = lesson_source
	compile_button.pressed.emit()
	await process_frame

	var pending_value = scene.get("_pending_skill_forge_run")
	if typeof(pending_value) != TYPE_DICTIONARY or pending_value.is_empty():
		_fail("Lesson 1 Compile did not draft a pending correlated world check.")
		return
	var pending: Dictionary = pending_value.duplicate(true)
	if str(pending.get("origin", "")) != "workbench" or pending.get("target_tile", Vector2i(-1, -1)) != lesson_brush.grid_pos:
		_fail("Lesson 1 pending run lost its Workbench origin or selected brush target. pending=%s" % str(pending))
		return
	if bool(progress.call("is_lesson_completed", lesson_one_id)) or str(progress.call("get_current_lesson")) != lesson_one_id:
		_fail("Lesson 1 completed before the correlated world mutation.")
		return
	var lesson_two_button_before = (game_ui.get("_lesson_buttons") as Dictionary).get(lesson_two_id, null) as Button
	if lesson_two_button_before == null or not lesson_two_button_before.disabled:
		_fail("Lesson 2 unlocked while lesson 1 was still pending.")
		return

	# A parser/validator-clean pending compile is eligible for the player's shelf.
	var program_name_edit = game_ui.get("_program_name_edit") as LineEdit
	var save_program_button = game_ui.get("_program_save_button") as Button
	if program_name_edit == null or save_program_button == null:
		_fail("Program shelf save controls were unavailable.")
		return
	program_name_edit.text = SAVED_PROGRAM_NAME
	program_name_edit.text_changed.emit(SAVED_PROGRAM_NAME)
	await process_frame
	if save_program_button.disabled:
		_fail("Valid compiled lesson source did not enable named program saving.")
		return
	save_program_button.pressed.emit()
	await process_frame
	if str(progress.call("get_program", SAVED_PROGRAM_NAME)) != lesson_source:
		_fail("Program shelf did not persist the exact compiled lesson source.")
		return

	editor.text = "agent draft intentionally replaced"
	var program_picker = game_ui.get("_program_picker") as OptionButton
	var load_program_button = game_ui.get("_program_load_button") as Button
	if program_picker == null or load_program_button == null:
		_fail("Program shelf load controls were unavailable.")
		return
	var program_index := _program_item_index(program_picker, SAVED_PROGRAM_NAME)
	if program_index < 0:
		_fail("Saved program was not exposed by the shelf picker.")
		return
	program_picker.select(program_index)
	if load_program_button.disabled:
		_fail("Program shelf Load stayed disabled after saving a compiled program.")
		return
	load_program_button.pressed.emit()
	await process_frame
	if editor.text != lesson_source:
		_fail("Program shelf did not restore the compiled source exactly.")
		return

	if not _complete_brush_run(scene, lesson_brush, pending):
		return
	await process_frame
	await process_frame

	if not bool(progress.call("is_lesson_completed", lesson_one_id)):
		_fail("Terminal Workbench world check did not complete lesson 1.")
		return
	if str(progress.call("get_current_lesson")) != lesson_two_id:
		_fail("Lesson 1 completion did not advance progress to lesson 2. current=%s" % progress.call("get_current_lesson"))
		return
	if not _assert_completed_lesson_ui(game_ui, lesson_one, lesson_two):
		return
	if not _assert_lesson_receipt_and_trace(game_ui, lesson_one):
		return

	scene.queue_free()
	await process_frame
	await process_frame
	_cleanup_temp_progress()
	if not _failed:
		quit()


func _assert_initial_lesson_ui(game_ui, lesson_one: Dictionary, lesson_two: Dictionary) -> bool:
	var lesson_one_id := str(lesson_one.get("id", ""))
	var lesson_two_id := str(lesson_two.get("id", ""))
	var buttons_value = game_ui.get("_lesson_buttons")
	if typeof(buttons_value) != TYPE_DICTIONARY:
		_fail("Lesson button registry was not a dictionary.")
		return false
	var buttons: Dictionary = buttons_value
	var lesson_one_button = buttons.get(lesson_one_id, null) as Button
	var lesson_two_button = buttons.get(lesson_two_id, null) as Button
	if lesson_one_button == null or lesson_two_button == null:
		_fail("Lesson UI did not expose lesson 1 and lesson 2 buttons.")
		return false
	if lesson_one_button.disabled or not lesson_one_button.text.begins_with("NOW"):
		_fail("Fresh lesson 1 was not presented as the current unlocked lesson. text=%s" % lesson_one_button.text)
		return false
	if not lesson_two_button.disabled or not lesson_two_button.text.begins_with("LOCK"):
		_fail("Fresh lesson 2 was not locked behind lesson 1. text=%s" % lesson_two_button.text)
		return false
	var goal_label = game_ui.get("_workbench_lesson_goal_label") as Label
	var title := str(lesson_one.get("title", ""))
	if goal_label == null or title == "" or not goal_label.text.contains(title):
		_fail("Workbench goal did not name current lesson 1. text=%s" % (goal_label.text if goal_label else ""))
		return false
	return true


func _assert_completed_lesson_ui(game_ui, lesson_one: Dictionary, lesson_two: Dictionary) -> bool:
	var buttons: Dictionary = game_ui.get("_lesson_buttons")
	var lesson_one_button = buttons.get(str(lesson_one.get("id", "")), null) as Button
	var lesson_two_button = buttons.get(str(lesson_two.get("id", "")), null) as Button
	if lesson_one_button == null or lesson_two_button == null:
		_fail("Lesson list did not rebuild after lesson 1 completion.")
		return false
	if lesson_one_button.disabled or not lesson_one_button.text.begins_with("DONE"):
		_fail("Completed lesson 1 did not remain replayable and marked DONE. text=%s" % lesson_one_button.text)
		return false
	if lesson_two_button.disabled or not lesson_two_button.text.begins_with("NOW"):
		_fail("Lesson 2 did not unlock as the new current lesson. text=%s" % lesson_two_button.text)
		return false
	var goal_label = game_ui.get("_workbench_lesson_goal_label") as Label
	var title := str(lesson_two.get("title", ""))
	if goal_label == null or title == "" or not goal_label.text.contains(title):
		_fail("Workbench goal did not advance to lesson 2. text=%s" % (goal_label.text if goal_label else ""))
		return false
	return true


func _assert_lesson_receipt_and_trace(game_ui, lesson_one: Dictionary) -> bool:
	var title := str(lesson_one.get("title", "")).to_lower()
	var found_receipt := false
	var entries_value = game_ui.get("_field_log_entries")
	if typeof(entries_value) == TYPE_ARRAY:
		for entry in entries_value:
			var normalized := str(entry).to_lower()
			if normalized.contains("lesson") and (title == "" or normalized.contains(title)):
				found_receipt = true
				break
	if not found_receipt:
		_fail("Lesson 1 completion did not celebrate through a named Field Log receipt.")
		return false

	var compiler_output = game_ui.get("_compiler_output") as RichTextLabel
	var trace: String = compiler_output.text if compiler_output else ""
	var tutor_index: int = trace.find("TUTOR")
	var technical_index: int = trace.find("TECHNICAL")
	var observation_index: int = trace.find("observed no decor")
	if observation_index < 0:
		observation_index = trace.find("Expected no decor")
	if tutor_index < 0 or technical_index <= tutor_index or observation_index <= technical_index:
		_fail("Terminal lesson trace did not layer tutor copy before preserved technical evidence. trace=%s" % trace)
		return false
	return true


func _select_forge_template(game_ui, template_id: String) -> bool:
	var buttons_value = game_ui.get("_skill_forge_template_buttons")
	if typeof(buttons_value) != TYPE_DICTIONARY:
		_fail("Legacy Skill Forge template registry was unavailable.")
		return false
	var button = (buttons_value as Dictionary).get(template_id, null) as Button
	if button == null:
		_fail("Legacy Skill Forge template %s was unavailable." % template_id)
		return false
	button.pressed.emit()
	return true


func _complete_brush_run(scene: Node, tile, pending: Dictionary) -> bool:
	var decor_before := str(tile.decor_id)
	if decor_before not in ["tall_grass", "flower_patch"]:
		_fail("Correlated brush target changed before its completion event.")
		return false
	if int(tile.cut_with_sickle()) != -1 or str(tile.decor_id) != "":
		_fail("Smoke could not apply the real brush world mutation.")
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


func _program_item_index(picker: OptionButton, program_name: String) -> int:
	for index in range(picker.item_count):
		if picker.get_item_text(index) == program_name:
			return index
	return -1


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
