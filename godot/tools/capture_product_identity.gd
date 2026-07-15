extends SceneTree

const OUTPUT_PATH := "res://artifacts/screenshots/agentville-product-identity.png"
const PROGRESS_PATH := "user://agentville_product_identity_capture.json"
const CAPTURE_SIZE := Vector2i(1600, 900)
const MAX_CAPTURE_ATTEMPTS := 5
const MAX_BLACK_SAMPLE_RATIO := 0.02
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
	root.content_scale_size = CAPTURE_SIZE
	root.size = CAPTURE_SIZE
	_cleanup_progress()
	if not _seed_unlocked_progress():
		_fail("Product identity capture could not seed isolated returning-player progress.")
		return
	call_deferred("_capture")


func _capture() -> void:
	if DisplayServer.get_name() == "headless":
		_fail("Product identity capture needs a normal renderer; run without --headless.")
		return
	if str(ProjectSettings.get_setting("application/config/name", "")) != EXPECTED_INTERNAL_PROJECT_NAME:
		_fail("Product identity capture found a save-incompatible internal project name: '%s'." % ProjectSettings.get_setting("application/config/name", ""))
		return

	var packed_scene = load("res://scenes/Main.tscn")
	if packed_scene == null:
		_fail("Product identity capture could not load res://scenes/Main.tscn.")
		return
	var scene: Node = packed_scene.instantiate()
	scene.set("progress_storage_path", PROGRESS_PATH)
	root.add_child(scene)
	await _wait_for_frames(4)
	if root.title != EXPECTED_WINDOW_TITLE:
		_fail("Product identity capture found a stale window title: '%s'." % root.title)
		return

	var game_ui = scene.get_node_or_null("GameUI")
	var grid = scene.get_node_or_null("FarmWorld/GridManager")
	if game_ui == null or grid == null:
		_fail("Product identity capture could not reach the production game UI and farm day loop.")
		return
	if not _assert_identity_contract(game_ui):
		return
	if not _assert_title_card_containment(game_ui):
		return

	var day_label = game_ui.get("_day_label") as Label
	var command_dock = game_ui.get_node_or_null("UIRoot/CommandDock") as Control
	var end_day_button = command_dock.find_child("EndDayButton", true, false) as Button if command_dock != null else null
	if day_label == null or day_label.text != EXPECTED_DAY_ONE or int(grid.day) != 1:
		_fail("Product identity capture did not begin at '%s'." % EXPECTED_DAY_ONE)
		return
	if end_day_button == null or end_day_button.disabled:
		_fail("Product identity capture could not use the unlocked production End Day control.")
		return

	end_day_button.pressed.emit()
	await _wait_for_frames(2)
	if int(grid.day) != 2 or day_label.text != EXPECTED_DAY_TWO:
		_fail("Product identity capture did not reach '%s' through the production day loop." % EXPECTED_DAY_TWO)
		return

	var tab_buttons_value = game_ui.get("_command_tab_buttons")
	if typeof(tab_buttons_value) != TYPE_DICTIONARY:
		_fail("Product identity capture could not reach the production command tabs.")
		return
	var agent_tab = (tab_buttons_value as Dictionary).get("agent", null) as Button
	if agent_tab == null or agent_tab.disabled:
		_fail("Product identity capture could not open the AGENT command page.")
		return
	agent_tab.pressed.emit()
	await _wait_for_frames(2)
	var command_scroll = command_dock.find_child("CommandScroll", true, false) as ScrollContainer
	if command_scroll != null:
		command_scroll.scroll_vertical = 0

	# Let the End Day toast clear so the captured checkpoint shows the persistent
	# product hierarchy rather than transient feedback.
	await create_timer(2.8).timeout
	await _wait_for_frames(3)
	if not await _save_capture():
		return

	scene.queue_free()
	await _wait_for_frames(2)
	_cleanup_progress()
	if not _failed:
		print("Product identity capture passed: %s" % OUTPUT_PATH)
		quit()


func _assert_identity_contract(game_ui) -> bool:
	var title_card = game_ui.get_node_or_null("UIRoot/TitleCard") as Control
	var command_dock = game_ui.get_node_or_null("UIRoot/CommandDock") as Control
	var field_desk = game_ui.get_node_or_null("UIRoot/StatusPanel") as Control
	var compile_button = game_ui.get("_workbench_compile_button") as Button
	if title_card == null or command_dock == null or field_desk == null or compile_button == null:
		_fail("Product identity capture could not reach the title, Command Dock, Field Desk, and Workbench controls.")
		return false
	if _count_labels_with_text(title_card, EXPECTED_BRAND_TITLE) != 1 \
			or _count_labels_with_text(title_card, EXPECTED_BRAND_SUBTITLE) != 1:
		_fail("Product identity capture found stale title-card language.")
		return false
	if compile_button.tooltip_text != EXPECTED_COMPILE_TOOLTIP:
		_fail("Product identity capture found a stale compile tooltip: '%s'." % compile_button.tooltip_text)
		return false
	if _count_labels_with_text(command_dock, "READY") > 0:
		_fail("Product identity capture found the static Command Dock READY ornament.")
		return false
	if not field_desk.find_children("*", "ProgressBar", true, false).is_empty():
		_fail("Product identity capture found a decorative Field Desk ProgressBar.")
		return false
	return true


func _assert_title_card_containment(game_ui) -> bool:
	var title_card = game_ui.get_node_or_null("UIRoot/TitleCard") as Control
	if title_card == null:
		_fail("Product identity capture lost TitleCard.")
		return false
	var title_label := _find_label_with_text(title_card, EXPECTED_BRAND_TITLE)
	var subtitle_label := _find_label_with_text(title_card, EXPECTED_BRAND_SUBTITLE)
	if title_label == null or subtitle_label == null:
		_fail("Product identity capture could not inspect title-card bounds.")
		return false
	var title_bounds := title_card.get_global_rect().grow(0.5)
	for label in [title_label, subtitle_label]:
		if not title_bounds.encloses((label as Label).get_global_rect()):
			_fail("Product identity capture found title text outside TitleCard: '%s'." % (label as Label).text)
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


func _save_capture() -> bool:
	for attempt in range(1, MAX_CAPTURE_ATTEMPTS + 1):
		await _wait_for_frames(2)
		var viewport_texture := root.get_texture()
		if viewport_texture == null:
			continue
		var image := viewport_texture.get_image()
		if image == null or image.get_size() != CAPTURE_SIZE:
			continue
		var black_ratio := _black_sample_ratio(image)
		if black_ratio > MAX_BLACK_SAMPLE_RATIO:
			print("Product identity capture retry %s/%s: black sample ratio %.3f." % [attempt, MAX_CAPTURE_ATTEMPTS, black_ratio])
			continue
		var error := image.save_png(OUTPUT_PATH)
		if error != OK:
			_fail("Product identity capture could not save %s." % OUTPUT_PATH)
			return false
		var saved := Image.load_from_file(ProjectSettings.globalize_path(OUTPUT_PATH))
		if saved == null or saved.get_size() != CAPTURE_SIZE or _black_sample_ratio(saved) > MAX_BLACK_SAMPLE_RATIO:
			_fail("Saved product identity artifact failed its 1600x900 frame-integrity check.")
			return false
		return true
	_fail("Product identity capture never produced a complete 1600x900 frame.")
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
