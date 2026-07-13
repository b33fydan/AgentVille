extends SceneTree

const SkillForgeTemplateLibraryScript := preload("res://scripts/systems/SkillForgeTemplateLibrary.gd")

const OUTPUT_PATH := "res://artifacts/screenshots/agentville-skill-forge-drift-visuals.png"
const PROGRESS_PATH := "user://agentville_skill_forge_drift_capture.json"
const CAPTURE_SIZE := Vector2i(1600, 900)
const LESSON_ONE_ID := "run_brush_starter"
const LESSON_TWO_ID := "name_brush_receipt"
const MAX_CAPTURE_ATTEMPTS := 5
const MAX_BLACK_SAMPLE_RATIO := 0.02
const STABLE_FRAME_COUNT := 5

var _failed := false


func _initialize() -> void:
	root.content_scale_size = CAPTURE_SIZE
	root.size = CAPTURE_SIZE
	_cleanup_progress()
	if not _seed_unlocked_progress():
		_fail("Forge Drift capture could not seed isolated returning-player progress.")
		return
	call_deferred("_capture")


func _capture() -> void:
	if DisplayServer.get_name() == "headless":
		_fail("Forge Drift capture needs a normal renderer; run without --headless.")
		return

	var packed_scene = load("res://scenes/Main.tscn")
	if packed_scene == null:
		_fail("Forge Drift capture could not load res://scenes/Main.tscn.")
		return
	var scene: Node = packed_scene.instantiate()
	scene.set("progress_storage_path", PROGRESS_PATH)
	root.add_child(scene)
	await _wait_for_stable_frames(3)

	var game_ui = scene.get_node_or_null("GameUI")
	var agent_manager = scene.get_node_or_null("FarmWorld/AgentManager")
	var camera_controller = scene.get_node_or_null("CameraController")
	var progress = scene.get("_player_progress")
	if game_ui == null or agent_manager == null or camera_controller == null or progress == null:
		_fail("Forge Drift capture could not reach the production game, UI, crew, camera, and progress systems.")
		return
	if not bool(game_ui.call("is_farm_sandbox_unlocked")) or not bool(progress.call("is_lesson_completed", LESSON_ONE_ID)):
		_fail("Forge Drift capture did not boot into the isolated unlocked free-play state.")
		return
	if not _prepare_agents(agent_manager):
		return

	var bert = _agent_actor(agent_manager, "bert")
	if bert == null:
		_fail("Forge Drift capture could not find Bert in the production crew.")
		return
	var active_before: Dictionary = bert.get("_active_decision").duplicate(true)
	var target_before: Vector2i = bert.target_grid_pos

	var library = SkillForgeTemplateLibraryScript.new()
	var spec: Dictionary = library.get_template_spec("clear_patch_starter")
	var steps: Array = spec.get("steps", []).duplicate(true)
	if steps.size() < 2:
		_fail("Forge Drift capture could not prepare the real starter spec.")
		return
	spec["tools"] = ["inspect_tile", "summon_rain"]
	steps[1]["tool"] = "summon_rain"
	spec["steps"] = steps

	var result: Dictionary = scene.call("_start_skill_forge_spec", spec, {
		"agent_id": "bert",
		"agent_name": "Bert",
		"target_tile": Vector2i(0, 1),
		"target_source": "selected_tile",
		"day": 3,
		"source_context": {
			"source": "capture_qa",
			"label": "Forge Drift visual proof"
		}
	}, "skill_forge")
	if not _assert_blocked_game_path(result, bert, active_before, target_before):
		return
	if not _assert_visible_forge_context(game_ui):
		return

	_select_command_tab(game_ui, "agent")
	await process_frame
	_scroll_command_page_to_control(game_ui, game_ui.get("_skill_forge_drift_label") as Control)
	camera_controller.call("focus_world_position", bert.global_position, 4.4)
	game_ui.call("show_message", "FORGE DRIFT · HALLUCINATING  |  Bert blocked safely  |  Crew worried")
	await _wait_for_stable_frames(STABLE_FRAME_COUNT)
	await create_timer(0.35).timeout
	await _wait_for_stable_frames(2)

	if not _assert_blocked_game_path(result, bert, active_before, target_before):
		return
	if not _assert_visible_forge_context(game_ui):
		return
	if not _assert_actor_is_visible(game_ui, camera_controller, bert):
		return
	if not await _save_capture():
		return

	scene.queue_free()
	await _wait_for_stable_frames(2)
	_cleanup_progress()
	if not _failed:
		print("Forge Drift visual capture passed: %s" % OUTPUT_PATH)
		quit()


func _prepare_agents(agent_manager) -> bool:
	if agent_manager.agents.is_empty():
		_fail("Forge Drift capture did not spawn the farm crew.")
		return false
	for actor in agent_manager.agents:
		actor.call("_complete_active_decision")
		actor.set_process(false)
		actor.state["expression"] = "neutral"
		actor.call("_update_expression_visuals")
		if not bool(actor.call("is_available")):
			_fail("%s was not available before the Forge Drift proof." % str(actor.display_name))
			return false
	return true


func _assert_blocked_game_path(result: Dictionary, bert, active_before: Dictionary, target_before: Vector2i) -> bool:
	if str(result.get("status", "")) != "blocked" or not result.get("directive", {}).is_empty():
		_fail("Hallucinating Forge spec did not stay sandbox-blocked. result=%s" % str(result))
		return false
	var run: Dictionary = result.get("run", {})
	var drift: Dictionary = run.get("drift", {})
	if str(run.get("agent_id", "")) != "bert" or str(run.get("agent_name", "")) != "Bert":
		_fail("Blocked Forge run lost its named farmhand context. run=%s" % str(run))
		return false
	if str(drift.get("level", "")) != "hallucinating" or str(drift.get("face_hint", "")) != "glitched" or str(drift.get("observer_hint", "")) != "crew_worried":
		_fail("Blocked Forge run lost its hallucinating visual hints. drift=%s" % str(drift))
		return false

	var snapshot: Dictionary = bert.call("get_snapshot")
	if str(snapshot.get("forge_drift_level", "")) != "hallucinating" \
			or str(snapshot.get("forge_face_hint", "")) != "glitched" \
			or str(snapshot.get("forge_observer_hint", "")) != "crew_worried" \
			or not bool(snapshot.get("forge_drift_transient", false)):
		_fail("Bert did not expose the live hallucinating Drift state. snapshot=%s" % str(snapshot))
		return false
	if bert.get("_active_decision") != active_before or bert.target_grid_pos != target_before or not bool(bert.call("is_available")):
		_fail("Sandbox-blocked Drift proof dispatched or occupied Bert.")
		return false

	var face = bert.get_node_or_null("VoxelRig/FaceLabel")
	var badge = bert.get_node_or_null("VoxelRig/ReasonBadge")
	if face == null or str(face.text) != "x_x":
		_fail("Bert's glitched Forge Drift face is not visible. face=%s" % str(face.text if face != null else "missing"))
		return false
	if badge == null or not badge.visible or str(badge.text) != "Crew worried":
		_fail("Bert's crew observer badge is not visible. badge=%s" % str(badge.text if badge != null else "missing"))
		return false

	var head_color := _mesh_color(bert.get("_head") as MeshInstance3D)
	var pip_color := _mesh_color(bert.get("_mood_pip") as MeshInstance3D)
	var irritation := float(bert.state.get("irritation", 0.0))
	var heat := clampf(irritation / 80.0, 0.0, 1.0)
	var expected_head: Color = (bert.get("_skin_color") as Color).lerp(Color("#ff8a68"), heat * 0.68).lerp(Color("#d58cff"), 0.38)
	if not head_color.is_equal_approx(expected_head) or not pip_color.is_equal_approx(Color("#a959d1")):
		_fail("Bert's hallucinating Drift tint is not active. head=%s pip=%s" % [head_color, pip_color])
		return false
	return true


func _assert_visible_forge_context(game_ui) -> bool:
	var forge_section = game_ui.get("_skill_forge_onboarding_section") as Control
	var result_label = game_ui.get("_skill_forge_result_label") as Label
	var detail_label = game_ui.get("_skill_forge_detail_label") as Label
	var drift_label = game_ui.get("_skill_forge_drift_label") as Label
	if forge_section == null or not forge_section.visible:
		_fail("Unlocked AGENT page did not expose the production Skill Forge panel.")
		return false
	if result_label == null or not result_label.text.contains("Blocked"):
		_fail("Skill Forge panel did not label the visual proof as blocked.")
		return false
	if detail_label == null or not detail_label.visible or not detail_label.text.contains("agent Bert"):
		_fail("Skill Forge panel did not identify Bert in the run context.")
		return false
	if drift_label == null or not drift_label.visible or not drift_label.text.contains("Forge Drift: hallucinating"):
		_fail("Skill Forge panel did not explain the hallucinating Drift state.")
		return false
	return true


func _assert_actor_is_visible(game_ui, camera_controller, actor) -> bool:
	var camera = camera_controller.get("camera") as Camera3D
	if camera == null:
		_fail("Forge Drift capture camera is unavailable.")
		return false
	var actor_screen_position := camera.unproject_position(actor.global_position + Vector3(0.0, 0.72, 0.0))
	var safe_rect := Rect2(Vector2(330.0, 120.0), Vector2(900.0, 500.0))
	if not safe_rect.has_point(actor_screen_position):
		_fail("Bert's Drift face is outside the unobscured capture area. screen=%s" % actor_screen_position)
		return false
	if bool(game_ui.call("is_pointer_over_ui", actor_screen_position)):
		_fail("Bert's Drift face is still behind a HUD panel. screen=%s" % actor_screen_position)
		return false
	return true


func _save_capture() -> bool:
	for attempt in range(1, MAX_CAPTURE_ATTEMPTS + 1):
		await _wait_for_stable_frames(2)
		var viewport_texture := root.get_texture()
		if viewport_texture == null:
			continue
		var image := viewport_texture.get_image()
		if image == null or image.get_size() != CAPTURE_SIZE:
			continue
		var black_ratio := _black_sample_ratio(image)
		if black_ratio > MAX_BLACK_SAMPLE_RATIO:
			print("Forge Drift capture retry %s/%s: black sample ratio %.3f." % [attempt, MAX_CAPTURE_ATTEMPTS, black_ratio])
			continue
		var error := image.save_png(OUTPUT_PATH)
		if error != OK:
			_fail("Forge Drift capture could not save %s." % OUTPUT_PATH)
			return false
		var saved := Image.load_from_file(ProjectSettings.globalize_path(OUTPUT_PATH))
		if saved == null or saved.get_size() != CAPTURE_SIZE or _black_sample_ratio(saved) > MAX_BLACK_SAMPLE_RATIO:
			_fail("Saved Forge Drift artifact failed its 1600x900 frame-integrity check.")
			return false
		return true
	_fail("Forge Drift capture never produced a complete 1600x900 frame.")
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


func _mesh_color(mesh_instance: MeshInstance3D) -> Color:
	if mesh_instance == null or not (mesh_instance.material_override is StandardMaterial3D):
		return Color.BLACK
	return (mesh_instance.material_override as StandardMaterial3D).albedo_color


func _agent_actor(agent_manager, wanted_id: String):
	for actor in agent_manager.agents:
		if str(actor.agent_id).to_lower() == wanted_id.to_lower():
			return actor
	return null


func _select_command_tab(game_ui, tab_id: String) -> void:
	var buttons_value = game_ui.get("_command_tab_buttons")
	if typeof(buttons_value) != TYPE_DICTIONARY:
		return
	var button = buttons_value.get(tab_id, null) as Button
	if button != null and not button.disabled:
		button.pressed.emit()


func _scroll_command_page_to_control(game_ui, control: Control) -> void:
	if control == null:
		return
	var dock = game_ui.get_node_or_null("UIRoot/CommandDock")
	var scroll = dock.find_child("CommandScroll", true, false) as ScrollContainer if dock != null else null
	if scroll != null:
		scroll.ensure_control_visible(control)


func _wait_for_stable_frames(frame_count: int) -> void:
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
