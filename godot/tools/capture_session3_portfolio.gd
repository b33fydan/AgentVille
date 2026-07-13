extends SceneTree

const PROGRESS_PATH := "user://agentville_session3_portfolio_capture.json"
const CAPTURE_SIZE := Vector2i(1600, 900)
const STEP_DELTA := 0.05
const MAX_AGENT_STEPS := 240
const MAX_CAPTURE_ATTEMPTS := 5
const MAX_BLACK_SAMPLE_RATIO := 0.02

const LESSON_ONE_ID := "run_brush_starter"
const LESSON_ONE_SOURCE := "agent \"Chuck\" {\n  observe selected_tile\n  when inspect.has_brush {\n    use clear_brush(selected_tile)\n  }\n  verify tile_state\n  receipt \"Clear Patch run\"\n}"
const FAILED_SOURCE := "agent \"Chuck\" {\n  observe selected_tile\n  when inspect.has_brush {\n    use clear_brush selected_tile)\n  }\n  verify tile_state\n  receipt \"Clear Patch run\"\n}"

const OUTPUTS := {
	"mid_lesson": "res://artifacts/screenshots/agentville-session3-mid-lesson.png",
	"failed_trace": "res://artifacts/screenshots/agentville-session3-failed-trace.png",
	"passed_receipt": "res://artifacts/screenshots/agentville-session3-passed-receipt.png",
	"farm": "res://artifacts/screenshots/agentville-session3-farm.png"
}

var _failed := false


func _initialize() -> void:
	root.content_scale_size = CAPTURE_SIZE
	root.size = CAPTURE_SIZE
	_cleanup_progress()
	call_deferred("_capture_portfolio")


func _capture_portfolio() -> void:
	if DisplayServer.get_name() == "headless":
		_fail("Session 3 portfolio capture needs a normal renderer; run without --headless.")
		return

	var packed_scene = load("res://scenes/Main.tscn")
	if packed_scene == null:
		_fail("Session 3 portfolio capture could not load res://scenes/Main.tscn.")
		return
	var scene: Node = packed_scene.instantiate()
	scene.set("progress_storage_path", PROGRESS_PATH)
	root.add_child(scene)
	await process_frame
	await process_frame
	await process_frame

	var game_ui = scene.get_node_or_null("GameUI")
	var grid = scene.get_node_or_null("FarmWorld/GridManager")
	var placement_tool = scene.get_node_or_null("PlacementTool")
	var agent_manager = scene.get_node_or_null("FarmWorld/AgentManager")
	var camera_controller = scene.get_node_or_null("CameraController")
	if game_ui == null or grid == null or placement_tool == null or agent_manager == null or camera_controller == null:
		_fail("Session 3 portfolio capture could not reach the production game systems.")
		return
	if str(scene.get("_active_lesson_id")) != LESSON_ONE_ID:
		_fail("Fresh portfolio boot did not land in lesson 1.")
		return
	if not _prepare_agents(agent_manager):
		return

	var brush_tile = _find_brush_tile(grid)
	if brush_tile == null:
		_fail("Session 3 portfolio capture could not find a lesson-1 brush tile.")
		return
	placement_tool.call("set_tool", "select")
	placement_tool.call("_apply_to_tile", brush_tile)
	await process_frame
	if not bool(placement_tool.call("has_selected_tile")) or placement_tool.call("get_selected_grid_pos") != brush_tile.grid_pos:
		_fail("Production tile selection did not retain the lesson target.")
		return

	var editor = game_ui.get("_code_editor") as CodeEdit
	var compile_button = game_ui.get("_workbench_compile_button") as Button
	var compiler_output = game_ui.get("_compiler_output") as RichTextLabel
	if editor == null or compile_button == null or compiler_output == null:
		_fail("Session 3 portfolio capture could not reach the production Workbench controls.")
		return
	_select_command_tab(game_ui, "agent")
	_scroll_command_page_to_top(game_ui)
	editor.text = LESSON_ONE_SOURCE
	editor.set_caret_line(3)
	editor.set_caret_column(8)
	await process_frame
	if not compiler_output.text.contains("stage     TARGET SELECTED"):
		_fail("Mid-lesson Workbench did not show the selected-target teaching state.")
		return
	if not await _save_capture("mid_lesson"):
		return

	editor.text = FAILED_SOURCE
	editor.set_caret_line(3)
	editor.set_caret_column(20)
	compile_button.pressed.emit()
	await process_frame
	if not _trace_contains_all(compiler_output.text, [
		"stage     PARSE ERROR",
		"status    BLOCKED",
		"line 4:21",
		"token selected_tile",
		"cause     Expected '('",
		"fix       "
	]):
		_fail("Failed-run portfolio trace lost its location, token, cause, or fix. trace=%s" % compiler_output.text)
		return
	_scroll_trace_to_end(compiler_output)
	await process_frame
	if not await _save_capture("failed_trace"):
		return

	editor.text = LESSON_ONE_SOURCE
	editor.set_caret_line(3)
	editor.set_caret_column(8)
	compile_button.pressed.emit()
	await process_frame
	var pending_value = scene.get("_pending_skill_forge_run")
	if typeof(pending_value) != TYPE_DICTIONARY or pending_value.is_empty():
		_fail("Corrected Workbench compile did not draft a production work order.")
		return
	var pending: Dictionary = pending_value.duplicate(true)
	if str(pending.get("origin", "")) != "workbench" or str(pending.get("lesson_id", "")) != LESSON_ONE_ID:
		_fail("Corrected Workbench compile lost its lesson-run correlation.")
		return
	if pending.get("target_tile", Vector2i(-1, -1)) != brush_tile.grid_pos or str(pending.get("agent_id", "")) != "chuck":
		_fail("Corrected Workbench compile did not retain Chuck or the selected brush tile.")
		return

	_select_command_tab(game_ui, "crew")
	await process_frame
	if not await _send_and_complete_run(scene, game_ui, agent_manager, brush_tile, pending):
		return
	await process_frame
	await process_frame
	compiler_output = game_ui.get("_compiler_output") as RichTextLabel
	if compiler_output == null or not _trace_contains_all(compiler_output.text, [
		"stage     WORLD CHECK",
		"status    PASSED",
		"agent     Chuck"
	]):
		_fail("Passed-receipt portfolio state did not expose the verified terminal trace.")
		return
	_select_command_tab(game_ui, "agent")
	_scroll_command_page_to_top(game_ui)
	_scroll_trace_to(compiler_output, "stage     WORLD CHECK")
	await process_frame
	if not await _save_capture("passed_receipt"):
		return

	var world_tab = _command_tab_button(game_ui, "world")
	if world_tab == null or world_tab.disabled:
		_fail("Unlocked portfolio state did not expose the WORLD camera controls.")
		return
	world_tab.pressed.emit()
	await process_frame
	var command_dock = game_ui.get_node_or_null("UIRoot/CommandDock")
	var zoom_out = command_dock.find_child("CameraZoomOut", true, false) as Button if command_dock else null
	var recenter = command_dock.find_child("CameraRecenter", true, false) as Button if command_dock else null
	if zoom_out == null or recenter == null:
		_fail("WORLD did not expose the production zoom and recenter controls.")
		return
	recenter.pressed.emit()
	zoom_out.pressed.emit()
	await process_frame
	var camera = camera_controller.get("camera") as Camera3D
	if camera == null or camera.size <= float(camera_controller.get("default_zoom")):
		_fail("Production Zoom - control did not widen the farm view.")
		return
	_select_command_tab(game_ui, "farm")
	_scroll_command_page_to_top(game_ui)
	await process_frame
	if str(game_ui.get("_active_command_tab")) != "farm":
		_fail("Unlocked portfolio state could not open the FARM command page.")
		return
	if not await _save_capture("farm"):
		return

	scene.queue_free()
	await process_frame
	await process_frame
	_cleanup_progress()
	if not _failed:
		print("Session 3 portfolio capture passed: mid lesson -> failed trace -> passed receipt -> farm.")
		quit()


func _prepare_agents(agent_manager) -> bool:
	if agent_manager.agents.is_empty():
		_fail("Session 3 portfolio capture did not spawn the farm crew.")
		return false
	for actor in agent_manager.agents:
		actor.call("_complete_active_decision")
		actor.set_process(false)
		actor.set("_decision_timer", 999.0)
		actor.move_speed = 24.0
		if not bool(actor.call("is_available")):
			_fail("%s was not available before the portfolio run." % str(actor.display_name))
			return false
	return true


func _send_and_complete_run(scene: Node, game_ui, agent_manager, tile, pending: Dictionary) -> bool:
	var order_id := str(pending.get("order_id", ""))
	var run_id := str(pending.get("run_id", ""))
	var actor = _agent_by_id(agent_manager, str(pending.get("agent_id", "")))
	if order_id == "" or run_id == "" or actor == null:
		_fail("Portfolio run did not expose a correlated order, run, and agent.")
		return false

	var rows_value = game_ui.get("_work_order_rows")
	if typeof(rows_value) != TYPE_DICTIONARY or not rows_value.has(order_id):
		_fail("Portfolio run did not reach the production CREW order list.")
		return false
	var row: Dictionary = rows_value[order_id]
	var send_button = row.get("button", null) as Button
	if send_button == null or send_button.disabled or send_button.text != "Send" or str(row.get("intent", "")) != "send":
		_fail("Portfolio work order was not ready on its production Send control.")
		return false
	send_button.pressed.emit()

	var terminal_step := -1
	for step in range(MAX_AGENT_STEPS):
		actor.call("_process", STEP_DELTA)
		await process_frame
		var live_pending = scene.get("_pending_skill_forge_run")
		var live_orders = scene.get("work_orders")
		var status := str(live_orders.get(order_id, {}).get("status", "")) if typeof(live_orders) == TYPE_DICTIONARY else ""
		if typeof(live_pending) == TYPE_DICTIONARY and live_pending.is_empty() and status == "done" and bool(actor.call("is_available")):
			terminal_step = step + 1
			break
	if terminal_step < 0:
		_fail("Portfolio run timed out before its verified receipt.")
		return false
	if str(tile.decor_id) != "":
		_fail("Portfolio AgentActor completed without clearing the selected brush.")
		return false
	return true


func _save_capture(key: String) -> bool:
	var output_path := str(OUTPUTS.get(key, ""))
	if output_path == "":
		_fail("Portfolio capture %s has no output path." % key)
		return false
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
			print("Portfolio capture retry %s/%s for %s: black sample ratio %.3f." % [attempt, MAX_CAPTURE_ATTEMPTS, key, black_ratio])
			continue
		var error := image.save_png(output_path)
		if error != OK:
			_fail("Session 3 portfolio capture could not save %s." % output_path)
			return false
		print("Session 3 portfolio capture: %s" % output_path)
		return true
	_fail("Portfolio capture %s never produced a complete 1600x900 frame." % key)
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
	var button = _command_tab_button(game_ui, tab_id)
	if button:
		button.pressed.emit()


func _command_tab_button(game_ui, tab_id: String) -> Button:
	var buttons_value = game_ui.get("_command_tab_buttons")
	if typeof(buttons_value) != TYPE_DICTIONARY:
		return null
	return buttons_value.get(tab_id, null) as Button


func _scroll_command_page_to_top(game_ui) -> void:
	var dock = game_ui.get_node_or_null("UIRoot/CommandDock")
	if dock == null:
		return
	var scroll = dock.find_child("CommandScroll", true, false) as ScrollContainer
	if scroll:
		scroll.scroll_vertical = 0


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


func _trace_contains_all(trace: String, expected_parts: Array) -> bool:
	for expected in expected_parts:
		if not trace.contains(str(expected)):
			return false
	return true


func _scroll_trace_to(trace_label: RichTextLabel, marker: String) -> void:
	var lines := trace_label.text.split("\n")
	var line_index := lines.find(marker)
	if line_index >= 0:
		trace_label.scroll_to_line(line_index)


func _scroll_trace_to_end(trace_label: RichTextLabel) -> void:
	var lines := trace_label.text.split("\n")
	trace_label.scroll_to_line(maxi(0, lines.size() - 1))


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
