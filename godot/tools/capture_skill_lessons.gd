extends SceneTree

const OUTPUT_PATH := "res://artifacts/screenshots/agentville-skill-lessons.png"
const CAPTURE_SIZE := Vector2i(1600, 900)
const TEMP_PROGRESS_PATH := "user://agentville_skill_lessons_capture.json"

var _failed := false


func _initialize() -> void:
	root.content_scale_size = CAPTURE_SIZE
	root.size = CAPTURE_SIZE
	_cleanup_temp_progress()
	call_deferred("_capture")


func _capture() -> void:
	if DisplayServer.get_name() == "headless":
		_fail("Skill lesson capture needs a normal renderer; run without --headless.")
		return

	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	scene.set("progress_storage_path", TEMP_PROGRESS_PATH)
	root.add_child(scene)
	await process_frame
	await process_frame
	await process_frame

	var game_ui = scene.get_node_or_null("GameUI")
	var grid = scene.get_node_or_null("FarmWorld/GridManager")
	var placement_tool = scene.get_node_or_null("PlacementTool")
	if game_ui == null or grid == null or placement_tool == null:
		_fail("Could not capture Skill lessons: scene integration is unavailable.")
		return
	var lesson_rows_value = game_ui.get("_lesson_rows")
	var lesson_buttons_value = game_ui.get("_lesson_buttons")
	if typeof(lesson_rows_value) != TYPE_ARRAY or lesson_rows_value.is_empty() or typeof(lesson_buttons_value) != TYPE_DICTIONARY or lesson_buttons_value.is_empty():
		_fail("Could not capture Skill lessons: lesson ladder is empty.")
		return

	var brush_tile = _find_brush_tile(grid)
	var editor = game_ui.get("_code_editor") as CodeEdit
	var compile_button = game_ui.get("_workbench_compile_button") as Button
	if brush_tile == null or editor == null or compile_button == null:
		_fail("Could not capture Skill lessons: brush-backed Workbench controls are unavailable.")
		return
	var first_lesson: Dictionary = lesson_rows_value[0]
	var lesson_source := str(first_lesson.get("starting_editor_text", editor.text))
	if lesson_source.strip_edges() == "" or not lesson_source.contains("clear_brush"):
		_fail("Could not capture Skill lessons: lesson 1 is not the brush starter.")
		return

	placement_tool.set_tool("select")
	placement_tool.call("_apply_to_tile", brush_tile)
	editor.text = lesson_source
	compile_button.pressed.emit()
	await process_frame

	var compiler_output = game_ui.get("_compiler_output") as RichTextLabel
	var goal_label = game_ui.get("_workbench_lesson_goal_label") as Label
	if compiler_output == null or not compiler_output.text.contains("TUTOR") or not compiler_output.text.contains("TECHNICAL"):
		_fail("Could not capture Skill lessons: pending compile trace lacks tutor and technical layers.")
		return
	if goal_label == null or not goal_label.text.contains(str(first_lesson.get("title", ""))):
		_fail("Could not capture Skill lessons: Workbench goal does not name lesson 1.")
		return

	var tab_buttons_value = game_ui.get("_command_tab_buttons")
	if typeof(tab_buttons_value) != TYPE_DICTIONARY:
		_fail("Could not capture Skill lessons: command tabs are unavailable.")
		return
	var agent_tab = (tab_buttons_value as Dictionary).get("agent", null) as Button
	if agent_tab == null:
		_fail("Could not capture Skill lessons: AGENT tab is unavailable.")
		return
	agent_tab.pressed.emit()
	await process_frame
	var command_scroll = game_ui.get_node_or_null("UIRoot/CommandDock")
	if command_scroll:
		var scroll = command_scroll.find_child("CommandScroll", true, false) as ScrollContainer
		if scroll:
			scroll.scroll_vertical = 0

	await create_timer(0.45).timeout
	var viewport_texture := root.get_texture()
	if viewport_texture == null:
		_fail("Could not capture Skill lessons: viewport texture is unavailable.")
		return
	var image := viewport_texture.get_image()
	if image == null:
		_fail("Could not capture Skill lessons: viewport image is unavailable.")
		return
	var error := image.save_png(OUTPUT_PATH)
	if error != OK:
		_fail("Could not save Skill lesson capture to %s." % OUTPUT_PATH)
		return

	scene.queue_free()
	await process_frame
	_cleanup_temp_progress()
	print("Captured Skill lesson review to %s." % OUTPUT_PATH)
	quit()


func _find_brush_tile(grid):
	for tile in grid.tiles.values():
		if str(tile.decor_id) in ["tall_grass", "flower_patch"]:
			return tile
	return null


func _cleanup_temp_progress() -> void:
	var absolute_path := ProjectSettings.globalize_path(TEMP_PROGRESS_PATH)
	if FileAccess.file_exists(absolute_path):
		DirAccess.remove_absolute(absolute_path)


func _fail(message: String) -> void:
	if _failed:
		return
	_failed = true
	_cleanup_temp_progress()
	push_error(message)
	quit(1)
