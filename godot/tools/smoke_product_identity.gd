extends SceneTree

const VIEWPORT_SIZE := Vector2i(1600, 900)
const RESPONSIVE_VIEWPORT_SIZE := Vector2i(1280, 720)
const PROGRESS_PATH := "user://agentville_product_identity_smoke.json"
const EXPECTED_INTERNAL_PROJECT_NAME := "AgentVille Voxel Farm Prototype"
const EXPECTED_WINDOW_TITLE := "AgentVille — Learn-to-Code Voxel Farm"
const EXPECTED_BRAND_TITLE := "AgentVille"
const EXPECTED_BRAND_SUBTITLE := "Build agents. Prove their work."
const EXPECTED_COMPILE_TOOLTIP := "Compile Skill Script · Cmd/Ctrl+Enter"
const EXPECTED_DAY_ONE := "DAY 1 · MORNING"
const EXPECTED_DAY_TWO := "DAY 2 · MORNING"
const LESSON_ONE_ID := "run_brush_starter"
const LESSON_TWO_ID := "name_brush_receipt"

var _failed := false


func _initialize() -> void:
	root.content_scale_size = VIEWPORT_SIZE
	root.size = VIEWPORT_SIZE
	_cleanup_progress()
	if not _seed_unlocked_progress():
		_fail("Product identity smoke could not seed isolated returning-player progress.")
		return
	call_deferred("_run")


func _run() -> void:
	if str(ProjectSettings.get_setting("application/config/name", "")) != EXPECTED_INTERNAL_PROJECT_NAME:
		_fail("Internal project name changed and would move user:// saves. expected='%s' actual='%s'" % [EXPECTED_INTERNAL_PROJECT_NAME, ProjectSettings.get_setting("application/config/name", "")])
		return

	var packed_scene = load("res://scenes/Main.tscn")
	if packed_scene == null:
		_fail("Product identity smoke could not load res://scenes/Main.tscn.")
		return
	var scene: Node = packed_scene.instantiate()
	scene.set("progress_storage_path", PROGRESS_PATH)
	root.add_child(scene)
	await _wait_for_frames(4)
	if root.title != EXPECTED_WINDOW_TITLE:
		_fail("Visible product window title drifted. expected='%s' actual='%s'" % [EXPECTED_WINDOW_TITLE, root.title])
		return

	var game_ui = scene.get_node_or_null("GameUI")
	var grid = scene.get_node_or_null("FarmWorld/GridManager")
	if game_ui == null or grid == null:
		_fail("Product identity smoke could not reach the production game UI and farm day loop.")
		return
	if not _assert_identity_contract(game_ui):
		return
	if not _assert_title_card_containment(game_ui, VIEWPORT_SIZE):
		return

	root.content_scale_size = RESPONSIVE_VIEWPORT_SIZE
	root.size = RESPONSIVE_VIEWPORT_SIZE
	await _wait_for_frames(3)
	if not _assert_title_card_containment(game_ui, RESPONSIVE_VIEWPORT_SIZE):
		return

	var day_label = game_ui.get("_day_label") as Label
	var command_dock = game_ui.get_node_or_null("UIRoot/CommandDock") as Control
	var end_day_button = command_dock.find_child("EndDayButton", true, false) as Button if command_dock != null else null
	if day_label == null or day_label.text != EXPECTED_DAY_ONE or int(grid.day) != 1:
		_fail("The production Field Desk did not begin at '%s'. label='%s' day=%s" % [EXPECTED_DAY_ONE, day_label.text if day_label else "missing", grid.day])
		return
	if end_day_button == null or end_day_button.disabled:
		_fail("Product identity smoke could not use the unlocked production End Day control.")
		return

	end_day_button.pressed.emit()
	await _wait_for_frames(2)
	if int(grid.day) != 2 or day_label.text != EXPECTED_DAY_TWO:
		_fail("The production day transition did not update the truthful morning label. label='%s' day=%s" % [day_label.text, grid.day])
		return

	scene.queue_free()
	await _wait_for_frames(2)
	_cleanup_progress()
	if not _failed:
		quit()


func _assert_identity_contract(game_ui) -> bool:
	var title_card = game_ui.get_node_or_null("UIRoot/TitleCard") as Control
	var command_dock = game_ui.get_node_or_null("UIRoot/CommandDock") as Control
	var field_desk = game_ui.get_node_or_null("UIRoot/StatusPanel") as Control
	var compile_button = game_ui.get("_workbench_compile_button") as Button
	if title_card == null or command_dock == null or field_desk == null or compile_button == null:
		_fail("Product identity smoke could not reach the title, Command Dock, Field Desk, and Workbench controls.")
		return false

	if _count_labels_with_text(title_card, EXPECTED_BRAND_TITLE) != 1:
		_fail("Title card did not expose exactly one '%s' brand title." % EXPECTED_BRAND_TITLE)
		return false
	if _count_labels_with_text(title_card, EXPECTED_BRAND_SUBTITLE) != 1:
		_fail("Title card did not expose the product promise '%s'." % EXPECTED_BRAND_SUBTITLE)
		return false
	if compile_button.tooltip_text != EXPECTED_COMPILE_TOOLTIP:
		_fail("Workbench compile tooltip drifted. expected='%s' actual='%s'" % [EXPECTED_COMPILE_TOOLTIP, compile_button.tooltip_text])
		return false
	if _count_labels_with_text(command_dock, "READY") > 0:
		_fail("Command Dock still contains the static READY ornament.")
		return false
	if not field_desk.find_children("*", "ProgressBar", true, false).is_empty():
		_fail("Field Desk still contains a decorative ProgressBar.")
		return false
	return true


func _assert_title_card_containment(game_ui, viewport_size: Vector2i) -> bool:
	var title_card = game_ui.get_node_or_null("UIRoot/TitleCard") as Control
	if title_card == null:
		_fail("Product identity smoke lost TitleCard at %sx%s." % [viewport_size.x, viewport_size.y])
		return false
	var title_label := _find_label_with_text(title_card, EXPECTED_BRAND_TITLE)
	var subtitle_label := _find_label_with_text(title_card, EXPECTED_BRAND_SUBTITLE)
	if title_label == null or subtitle_label == null:
		_fail("Product identity smoke could not inspect title-card bounds at %sx%s." % [viewport_size.x, viewport_size.y])
		return false
	var title_bounds := title_card.get_global_rect().grow(0.5)
	for label in [title_label, subtitle_label]:
		if not title_bounds.encloses((label as Label).get_global_rect()):
			_fail("TitleCard did not enclose %s at %sx%s. card=%s label=%s" % [(label as Label).text, viewport_size.x, viewport_size.y, title_card.get_global_rect(), (label as Label).get_global_rect()])
			return false
	return true


func _count_labels_with_text(root_control: Control, expected_text: String) -> int:
	var count := 0
	for node in root_control.find_children("*", "Label", true, false):
		var label := node as Label
		if label != null and label.text == expected_text:
			count += 1
	return count


func _find_label_with_text(root_control: Control, expected_text: String) -> Label:
	for node in root_control.find_children("*", "Label", true, false):
		var label := node as Label
		if label != null and label.text == expected_text:
			return label
	return null


func _seed_unlocked_progress() -> bool:
	var file := FileAccess.open(PROGRESS_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify({
		"version": 1,
		"completed_lessons": [LESSON_ONE_ID],
		"current_lesson": LESSON_TWO_ID,
		"saved_programs": {},
		"view_toggles": {
			"grid": false,
			"shadows": true,
			"ambient_occlusion": true
		}
	}, "\t"))
	file = null
	return true


func _cleanup_progress() -> void:
	var absolute_path := ProjectSettings.globalize_path(PROGRESS_PATH)
	if FileAccess.file_exists(absolute_path):
		DirAccess.remove_absolute(absolute_path)


func _wait_for_frames(frame_count: int) -> void:
	for _frame in range(maxi(1, frame_count)):
		await process_frame


func _fail(message: String) -> void:
	if _failed:
		return
	_failed = true
	_cleanup_progress()
	push_error(message)
	quit(1)
