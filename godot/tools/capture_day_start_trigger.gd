extends SceneTree

const OUTPUT_PATH := "res://artifacts/screenshots/agentville-day-start-trigger.png"
const PROGRESS_PATH := "user://agentville_day_start_trigger_capture.json"
const CAPTURE_SIZE := Vector2i(1600, 900)
const STEP_DELTA := 0.05
const MAX_AGENT_STEPS := 300
const MAX_CAPTURE_ATTEMPTS := 5
const MAX_BLACK_SAMPLE_RATIO := 0.02

const LESSON_ONE_ID := "run_brush_starter"
const LESSON_TWO_ID := "name_brush_receipt"
const DAY_START_SOURCE := "agent \"Chuck\" {\n  on day_start\n  observe selected_tile\n  when inspect.has_brush {\n    use clear_brush(selected_tile)\n  }\n  verify tile_state\n  receipt \"Morning Brush run\"\n}"

var _failed := false


func _initialize() -> void:
	root.content_scale_size = CAPTURE_SIZE
	root.size = CAPTURE_SIZE
	_cleanup_progress()
	if not _seed_unlocked_progress():
		_fail("Day-start capture could not seed isolated returning-player progress.")
		return
	call_deferred("_capture")


func _capture() -> void:
	if DisplayServer.get_name() == "headless":
		_fail("Day-start capture needs a normal renderer; run without --headless.")
		return

	var packed_scene = load("res://scenes/Main.tscn")
	if packed_scene == null:
		_fail("Day-start capture could not load res://scenes/Main.tscn.")
		return
	var scene: Node = packed_scene.instantiate()
	scene.set("progress_storage_path", PROGRESS_PATH)
	root.add_child(scene)
	await _wait_for_frames(4)

	var game_ui = scene.get_node_or_null("GameUI")
	var grid = scene.get_node_or_null("FarmWorld/GridManager")
	var placement_tool = scene.get_node_or_null("PlacementTool")
	var agent_manager = scene.get_node_or_null("FarmWorld/AgentManager")
	var progress = scene.get("_player_progress")
	var scheduler = scene.get("_skill_trigger_scheduler")
	var event_log = scene.get("_event_log")
	if game_ui == null or grid == null or placement_tool == null or agent_manager == null \
			or progress == null or scheduler == null or event_log == null:
		_fail("Day-start capture could not reach the production game, UI, crew, progress, scheduler, and event log.")
		return
	if not bool(game_ui.call("is_farm_sandbox_unlocked")) or not bool(progress.call("is_lesson_completed", LESSON_ONE_ID)):
		_fail("Day-start capture did not boot into the isolated unlocked Workbench state.")
		return
	if not _prepare_agents(agent_manager):
		return

	var brush_tile = _find_brush_tile(grid)
	if brush_tile == null:
		_fail("Day-start capture could not find a brush-backed selected_tile target.")
		return
	var target: Vector2i = brush_tile.grid_pos
	var original_decor := str(brush_tile.decor_id)
	placement_tool.call("set_tool", "select")
	placement_tool.call("_apply_to_tile", brush_tile)
	await process_frame
	if not bool(placement_tool.call("has_selected_tile")) or placement_tool.call("get_selected_grid_pos") != target:
		_fail("Production tile selection did not retain the day-start target.")
		return

	var editor = game_ui.get("_code_editor") as CodeEdit
	var compile_button = game_ui.get("_workbench_compile_button") as Button
	var disarm_button = game_ui.get("_workbench_disarm_button") as Button
	var runtime_label = game_ui.get("_workbench_runtime_label") as Label
	var compiler_output = game_ui.get("_compiler_output") as RichTextLabel
	var day_label = game_ui.get("_day_label") as Label
	var command_dock = game_ui.get_node_or_null("UIRoot/CommandDock")
	var end_day_button = command_dock.find_child("EndDayButton", true, false) as Button if command_dock else null
	if editor == null or compile_button == null or disarm_button == null or runtime_label == null \
			or compiler_output == null or day_label == null or end_day_button == null:
		_fail("Day-start capture could not reach the production Workbench and End Day controls.")
		return
	if end_day_button.disabled:
		_fail("The isolated returning-player state did not unlock the production End Day control.")
		return

	_select_command_tab(game_ui, "agent")
	_scroll_command_page_to_top(game_ui)
	editor.text = DAY_START_SOURCE
	editor.set_caret_line(1)
	editor.set_caret_column(6)
	var order_count_before := (scene.get("work_orders") as Dictionary).size()
	var day_before := int(grid.day)
	compile_button.pressed.emit()
	await _wait_for_frames(2)

	if not bool(scheduler.call("has_armed")):
		_fail("Compile did not arm the production one-shot day-start scheduler.")
		return
	var arm: Dictionary = scheduler.call("snapshot")
	var arm_request: Dictionary = arm.get("request", {})
	if str(arm.get("trigger_type", "")) != "day_start" \
			or str(arm_request.get("agent_id", "")) != "chuck" \
			or arm_request.get("target_tile", Vector2i(-1, -1)) != target:
		_fail("The armed trigger lost its event, named farmhand, or captured target. arm=%s" % str(arm))
		return
	var pending_after_compile = scene.get("_pending_skill_forge_run")
	if typeof(pending_after_compile) != TYPE_DICTIONARY or not pending_after_compile.is_empty():
		_fail("Compile created a pending Forge run before day start.")
		return
	if (scene.get("work_orders") as Dictionary).size() != order_count_before or str(brush_tile.decor_id) != original_decor:
		_fail("Compile drafted an order or changed the selected farm tile before day start.")
		return
	if not disarm_button.visible or disarm_button.disabled \
			or runtime_label.text != "ARMED ONCE  ·  DAY START" \
			or not _trace_contains_all(compiler_output.text, ["stage     TRIGGER ARMED", "agent     Chuck", "target    (%s, %s) · captured selected_tile" % [target.x, target.y]]):
		_fail("The armed Workbench state did not expose its one-shot, agent, and captured-target evidence. trace=%s" % compiler_output.text)
		return

	_select_command_tab(game_ui, "world")
	_scroll_command_page_to_control(game_ui, end_day_button)
	end_day_button.pressed.emit()
	await _wait_for_frames(2)
	if int(grid.day) != day_before + 1 or int(grid.day) != 2 or day_label.text != "DAY 2 / 10:00 AM":
		_fail("Production End Day did not advance the live world and UI to Day 2.")
		return
	if bool(scheduler.call("has_armed")) or disarm_button.visible:
		_fail("The one-shot arm remained active after day start fired.")
		return

	var pending_value = scene.get("_pending_skill_forge_run")
	if typeof(pending_value) != TYPE_DICTIONARY or pending_value.is_empty():
		_fail("Day start did not create the correlated automatic Forge run.")
		return
	var pending: Dictionary = pending_value.duplicate(true)
	if str(pending.get("origin", "")) != "workbench_trigger" \
			or str(pending.get("trigger_type", "")) != "day_start" \
			or str(pending.get("agent_id", "")) != "chuck" \
			or pending.get("target_tile", Vector2i(-1, -1)) != target:
		_fail("The fired run lost its trigger, agent, or captured target. pending=%s" % str(pending))
		return

	var order_id := str(pending.get("order_id", ""))
	var actor = _agent_by_id(agent_manager, "chuck")
	if order_id == "" or actor == null:
		_fail("The automatic run did not expose its real crew order and Chuck actor.")
		return
	var work_orders: Dictionary = scene.get("work_orders")
	if str(work_orders.get(order_id, {}).get("status", "")) != "queued":
		_fail("The day-start order was not auto-dispatched through the production crew route. order=%s" % str(work_orders.get(order_id, {})))
		return

	var terminal_step := -1
	for step in range(MAX_AGENT_STEPS):
		actor.call("_process", STEP_DELTA)
		await process_frame
		var live_pending = scene.get("_pending_skill_forge_run")
		var live_orders = scene.get("work_orders")
		var status := str(live_orders.get(order_id, {}).get("status", "")) if typeof(live_orders) == TYPE_DICTIONARY else ""
		if typeof(live_pending) == TYPE_DICTIONARY and live_pending.is_empty() \
				and status == "done" and bool(actor.call("is_available")):
			terminal_step = step + 1
			break
	if terminal_step < 0:
		_fail("The day-start AgentActor route timed out before its verified terminal receipt.")
		return
	if str(brush_tile.decor_id) != "":
		_fail("Chuck completed the automatic run without clearing the captured brush tile.")
		return

	compiler_output = game_ui.get("_compiler_output") as RichTextLabel
	runtime_label = game_ui.get("_workbench_runtime_label") as Label
	if compiler_output == null or runtime_label == null \
			or runtime_label.text != "PASSED  ·  DAY START" \
			or not _trace_contains_all(compiler_output.text, [
				"stage     DAY START WORLD CHECK",
				"status    PASSED",
				"agent     Chuck",
				"target    (%s, %s) · captured selected_tile" % [target.x, target.y]
			]):
		_fail("The terminal Workbench lost its PASSED day-start, agent, or target evidence. trace=%s" % compiler_output.text)
		return
	if not _has_trigger_event(event_log, "skill_trigger_armed", target, "chuck") \
			or not _has_trigger_event(event_log, "skill_trigger_fired", target, "chuck") \
			or not _has_trigger_event(event_log, "skill_trigger_passed", target, "chuck"):
		_fail("The Field Log evidence did not correlate the armed, fired, and passed trigger lifecycle.")
		return

	_select_command_tab(game_ui, "agent")
	_scroll_command_page_to_top(game_ui)
	editor.set_caret_line(1)
	editor.set_caret_column(6)
	_scroll_trace_to(compiler_output, "stage     DAY START WORLD CHECK")
	game_ui.call("show_message", "DAY 2 · DAY START PASSED · Chuck verified (%s, %s)" % [target.x, target.y])
	await _wait_for_frames(4)
	await create_timer(0.4).timeout
	await _wait_for_frames(2)

	if not await _save_capture():
		return
	scene.queue_free()
	await _wait_for_frames(2)
	_cleanup_progress()
	if not _failed:
		print("Day-start trigger capture passed after %s AgentActor steps: %s" % [terminal_step, OUTPUT_PATH])
		quit()


func _prepare_agents(agent_manager) -> bool:
	if agent_manager.agents.is_empty():
		_fail("Day-start capture did not spawn the farm crew.")
		return false
	for actor in agent_manager.agents:
		actor.call("_complete_active_decision")
		actor.set_process(false)
		actor.set("_decision_timer", 999.0)
		actor.move_speed = 24.0
		if not bool(actor.call("is_available")):
			_fail("%s was not available before the day-start run." % str(actor.display_name))
			return false
	return true


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


func _has_trigger_event(event_log, event_type: String, target: Vector2i, agent_id: String) -> bool:
	for event in event_log.events:
		if str(event.get("type", "")) == event_type \
				and str(event.get("agent_id", "")) == agent_id \
				and event.get("target_tile", Vector2i(-1, -1)) == target:
			return true
	return false


func _select_command_tab(game_ui, tab_id: String) -> void:
	var buttons_value = game_ui.get("_command_tab_buttons")
	if typeof(buttons_value) != TYPE_DICTIONARY:
		return
	var button = buttons_value.get(tab_id, null) as Button
	if button != null and not button.disabled:
		button.pressed.emit()


func _scroll_command_page_to_top(game_ui) -> void:
	var dock = game_ui.get_node_or_null("UIRoot/CommandDock")
	var scroll = dock.find_child("CommandScroll", true, false) as ScrollContainer if dock != null else null
	if scroll != null:
		scroll.scroll_vertical = 0


func _scroll_command_page_to_control(game_ui, control: Control) -> void:
	if control == null:
		return
	var dock = game_ui.get_node_or_null("UIRoot/CommandDock")
	var scroll = dock.find_child("CommandScroll", true, false) as ScrollContainer if dock != null else null
	if scroll != null:
		scroll.ensure_control_visible(control)


func _scroll_trace_to(trace_label: RichTextLabel, marker: String) -> void:
	var lines := trace_label.text.split("\n")
	var line_index := lines.find(marker)
	if line_index >= 0:
		trace_label.scroll_to_line(line_index)


func _trace_contains_all(trace: String, expected_parts: Array) -> bool:
	for expected in expected_parts:
		if not trace.contains(str(expected)):
			return false
	return true


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
			print("Day-start capture retry %s/%s: black sample ratio %.3f." % [attempt, MAX_CAPTURE_ATTEMPTS, black_ratio])
			continue
		var error := image.save_png(OUTPUT_PATH)
		if error != OK:
			_fail("Day-start capture could not save %s." % OUTPUT_PATH)
			return false
		var saved := Image.load_from_file(ProjectSettings.globalize_path(OUTPUT_PATH))
		if saved == null or saved.get_size() != CAPTURE_SIZE or _black_sample_ratio(saved) > MAX_BLACK_SAMPLE_RATIO:
			_fail("Saved day-start artifact failed its 1600x900 frame-integrity check.")
			return false
		return true
	_fail("Day-start capture never produced a complete 1600x900 frame.")
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


func _wait_for_frames(frame_count: int) -> void:
	for _frame in range(maxi(1, frame_count)):
		await process_frame


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


func _fail(message: String) -> void:
	if _failed:
		return
	_failed = true
	_cleanup_progress()
	push_error(message)
	quit(1)
