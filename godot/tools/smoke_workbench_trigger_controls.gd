extends SceneTree

const GameUIScript := preload("res://scripts/ui/GameUI.gd")
const VIEWPORT_SIZES: Array[Vector2i] = [Vector2i(1600, 900), Vector2i(1280, 720)]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for viewport_size in VIEWPORT_SIZES:
		if not await _assert_trigger_controls(viewport_size):
			return
	quit()


func _assert_trigger_controls(viewport_size: Vector2i) -> bool:
	root.content_scale_size = viewport_size
	root.size = viewport_size
	var game_ui = GameUIScript.new()
	root.add_child(game_ui)
	await process_frame
	await process_frame

	var workbench := game_ui.get("_code_workbench") as Control
	var editor := game_ui.get("_code_editor") as CodeEdit
	var runtime_label := game_ui.get("_workbench_runtime_label") as Label
	var compile_button := game_ui.get("_workbench_compile_button") as Button
	var disarm_button := game_ui.get("_workbench_disarm_button") as Button
	if workbench == null or editor == null or runtime_label == null or compile_button == null or disarm_button == null:
		_fail("Workbench trigger controls were not constructed at %sx%s." % [viewport_size.x, viewport_size.y])
		return false
	if disarm_button.name != "WorkbenchDisarmButton" or disarm_button.text != "DISARM":
		_fail("Workbench did not expose the compact named DISARM control.")
		return false
	if disarm_button.visible or not disarm_button.disabled:
		_fail("Workbench DISARM control was active before a trigger was armed.")
		return false

	var highlighter := editor.syntax_highlighter as CodeHighlighter
	if highlighter == null or not highlighter.has_keyword_color("on"):
		_fail("Skill Script trigger keyword 'on' is not syntax highlighted.")
		return false

	game_ui.set_workbench_trigger_armed(true)
	await process_frame
	if not disarm_button.visible or disarm_button.disabled:
		_fail("Arming did not reveal an enabled DISARM control.")
		return false
	if runtime_label.text != "ARMED ONCE  ·  DAY START":
		_fail("Arming did not publish the one-shot day-start runtime state.")
		return false
	if not workbench.get_global_rect().grow(1.0).encloses(disarm_button.get_global_rect()):
		_fail("DISARM escaped the Workbench at %sx%s." % [viewport_size.x, viewport_size.y])
		return false
	if disarm_button.get_global_rect().intersects(compile_button.get_global_rect()):
		_fail("DISARM overlapped COMPILE at %sx%s." % [viewport_size.x, viewport_size.y])
		return false

	editor.set_caret_line(editor.get_line_count() - 1)
	editor.set_caret_column(editor.get_line(editor.get_line_count() - 1).length())
	editor.insert_text_at_caret("\n# edited after arming")
	await process_frame
	if runtime_label.text != "EDITED  ·  TRIGGER STILL ARMED":
		_fail("Editing armed source did not preserve an explicit trigger hazard.")
		return false
	if not disarm_button.visible or disarm_button.disabled:
		_fail("Editing armed source incorrectly consumed the controller-owned trigger.")
		return false

	var disarm_requests: Array[bool] = []
	game_ui.workbench_trigger_disarm_requested.connect(func() -> void:
		disarm_requests.append(true)
	)
	disarm_button.pressed.emit()
	if disarm_requests.size() != 1:
		_fail("DISARM did not emit exactly one controller-owned request.")
		return false
	if not disarm_button.visible:
		_fail("DISARM mutated its own state before the controller acknowledged it.")
		return false

	game_ui.set_workbench_trigger_armed(false, "DISARMED  ·  DAY START")
	if disarm_button.visible or not disarm_button.disabled:
		_fail("Controller acknowledgement did not hide and disable DISARM.")
		return false
	if runtime_label.text != "DISARMED  ·  DAY START":
		_fail("Controller acknowledgement did not publish the supplied status.")
		return false

	game_ui.queue_free()
	await process_frame
	return true


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
