extends SceneTree

const GameUIScript := preload("res://scripts/ui/GameUI.gd")
const SoundManagerScript := preload("res://scripts/audio/SoundManager.gd")
const WORKBENCH_STAMPS := ["compile_success", "run_dispatch", "receipt_pass", "lesson_complete"]

var _failed := false


func _initialize() -> void:
	root.content_scale_size = Vector2i(1600, 900)
	root.size = Vector2i(1600, 900)
	call_deferred("_run")


func _run() -> void:
	_assert_distinct_sound_stamps()
	if _failed:
		return
	await _assert_visible_workbench_feedback()
	if not _failed:
		quit()


func _assert_distinct_sound_stamps() -> void:
	var sound_manager = SoundManagerScript.new()
	root.add_child(sound_manager)
	var profile_keys: Dictionary = {}
	var waveform_hashes: Dictionary = {}
	var generic_profile: Dictionary = sound_manager.get_placeholder_profile("tool_select")
	for stamp_name in WORKBENCH_STAMPS:
		if not sound_manager.asset_paths.has(stamp_name):
			_fail("SoundManager is missing the %s asset seam." % stamp_name)
			return
		var profile: Dictionary = sound_manager.get_placeholder_profile(stamp_name)
		if profile.is_empty() or not profile.has("freq") or not profile.has("duration") or not profile.has("wave"):
			_fail("Workbench sound %s has no complete placeholder profile." % stamp_name)
			return
		if profile == generic_profile:
			_fail("Workbench sound %s aliases the generic tool-select profile." % stamp_name)
			return
		var profile_key := "%s|%s|%s" % [profile.get("freq"), profile.get("duration"), profile.get("wave")]
		if profile_keys.has(profile_key):
			_fail("Workbench sound %s reuses another Workbench sound profile." % stamp_name)
			return
		profile_keys[profile_key] = stamp_name

		var first_stream = sound_manager.call("_make_placeholder_stream", stamp_name) as AudioStreamWAV
		var second_stream = sound_manager.call("_make_placeholder_stream", stamp_name) as AudioStreamWAV
		if first_stream == null or first_stream.data.is_empty() or first_stream.data != second_stream.data:
			_fail("Workbench sound %s is missing or nondeterministic." % stamp_name)
			return
		var waveform_hash := hash(first_stream.data)
		if waveform_hashes.has(waveform_hash):
			_fail("Workbench sound %s produced the same waveform as another feedback stamp." % stamp_name)
			return
		waveform_hashes[waveform_hash] = stamp_name
		sound_manager.play_stamp(stamp_name)
		if sound_manager.get_node_or_null("SFX_%s" % stamp_name) == null:
			_fail("Playing %s did not create its named audio player." % stamp_name)
			return
	sound_manager.queue_free()


func _assert_visible_workbench_feedback() -> void:
	var game_ui = GameUIScript.new()
	root.add_child(game_ui)
	await process_frame
	await process_frame

	var compile_button := game_ui.get("_workbench_compile_button") as Button
	var runtime_label := game_ui.get("_workbench_runtime_label") as Label
	var compiler_output := game_ui.get("_compiler_output") as RichTextLabel
	var lesson_goal := game_ui.get("_workbench_lesson_goal_label") as Label
	if compile_button == null or runtime_label == null or compiler_output == null or lesson_goal == null:
		_fail("Workbench feedback targets were not constructed.")
		return

	game_ui.pulse_workbench_compile()
	_assert_feedback_target(compile_button, "compile", "Compile button")
	if _failed:
		return

	var order_id := "feedback-run"
	game_ui.set_work_orders([{
		"id": order_id,
		"label": "Feedback run",
		"action": "clear_brush",
		"status": "ready",
		"can_progress": true
	}])
	var work_order_rows: Dictionary = game_ui.get("_work_order_rows")
	var row: Dictionary = work_order_rows.get(order_id, {})
	var send_button := row.get("button", null) as Button
	if send_button == null or send_button.text != "Send":
		_fail("Feedback smoke could not construct the real Send control.")
		return
	game_ui.pulse_workbench_run(order_id)
	_assert_feedback_target(send_button, "run", "Send button")
	if _failed:
		return

	game_ui.pulse_workbench_receipt_passed()
	_assert_feedback_target(compiler_output, "receipt_passed", "Passed receipt")
	if _failed:
		return

	game_ui.pulse_lesson_complete()
	_assert_feedback_target(lesson_goal, "lesson_complete", "Lesson goal")
	if _failed:
		return

	var snapshot: Dictionary = game_ui.get_workbench_feedback_snapshot()
	var counts: Dictionary = snapshot.get("counts", {})
	if str(snapshot.get("state", "")) != "lesson_complete":
		_fail("Workbench feedback did not retain the latest visible state.")
		return
	for feedback_state in ["compile", "run", "receipt_passed", "lesson_complete"]:
		if int(counts.get(feedback_state, 0)) != 1:
			_fail("Workbench feedback did not record exactly one %s pulse." % feedback_state)
			return

	game_ui.queue_free()
	await process_frame


func _assert_feedback_target(control: Control, expected_state: String, label: String) -> void:
	if str(control.get_meta("agentville_feedback", "")) != expected_state:
		_fail("%s did not expose the %s feedback state." % [label, expected_state])
		return
	if control.scale.x <= 1.0 or control.modulate == Color.WHITE:
		_fail("%s did not enter a visible pulse state immediately." % label)


func _fail(message: String) -> void:
	if _failed:
		return
	_failed = true
	push_error(message)
	quit(1)
