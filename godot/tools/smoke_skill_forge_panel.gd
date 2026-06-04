extends SceneTree

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	root.size = Vector2i(1600, 900)
	await process_frame
	await process_frame

	var game_ui = scene.get_node("GameUI")
	_test_panel_loads_template_previews(game_ui)
	if _failed:
		return
	_test_template_selection_updates_preview(game_ui)
	if _failed:
		return
	await _test_run_button_records_receipts(scene, game_ui)
	if _failed:
		return

	scene.queue_free()
	if not _failed:
		quit()


func _test_panel_loads_template_previews(game_ui) -> void:
	var buttons_value = game_ui.get("_skill_forge_template_buttons")
	if typeof(buttons_value) != TYPE_DICTIONARY:
		_fail("Skill Forge panel did not expose template buttons.")
		return
	var buttons: Dictionary = buttons_value
	if not buttons.has("tend_crops_starter") or not buttons.has("clear_patch_starter"):
		_fail("Skill Forge panel did not expose both starter templates. buttons=%s" % str(buttons.keys()))
		return

	var run_button = game_ui.get("_skill_forge_run_button") as Button
	if run_button == null:
		_fail("Skill Forge panel did not expose a run button.")
		return
	if run_button.disabled:
		_fail("Skill Forge run button should be enabled for the default valid starter template.")
		return

	var summary_label = game_ui.get("_skill_forge_summary_label") as Label
	if summary_label == null or not summary_label.text.contains("Trigger manual"):
		_fail("Skill Forge default preview should expose the trigger contract. text=%s" % (summary_label.text if summary_label else ""))
		return

	var lesson_label = game_ui.get("_skill_forge_lesson_label") as Label
	if lesson_label == null or not lesson_label.text.contains("tend_crop"):
		_fail("Skill Forge default preview should expose Tend Crops tools. text=%s" % (lesson_label.text if lesson_label else ""))
		return

	if not game_ui.is_pointer_over_ui(run_button.get_global_rect().get_center()):
		_fail("Skill Forge run button was not registered as part of the UI hit region.")
		return


func _test_template_selection_updates_preview(game_ui) -> void:
	var buttons_value = game_ui.get("_skill_forge_template_buttons")
	if typeof(buttons_value) != TYPE_DICTIONARY:
		_fail("Skill Forge panel did not expose template buttons for selection.")
		return
	var buttons: Dictionary = buttons_value
	var clear_button = buttons.get("clear_patch_starter", null) as Button
	if clear_button == null:
		_fail("Clear Patch template button missing.")
		return

	clear_button.pressed.emit()
	var active_id := str(game_ui.get("_active_skill_forge_template_id"))
	if active_id != "clear_patch_starter":
		_fail("Selecting Clear Patch did not update the active template. active=%s" % active_id)
		return

	var summary_label = game_ui.get("_skill_forge_summary_label") as Label
	if summary_label == null or not summary_label.text.contains("Context selected_tile"):
		_fail("Clear Patch preview did not expose selected-tile context. text=%s" % (summary_label.text if summary_label else ""))
		return

	var lesson_label = game_ui.get("_skill_forge_lesson_label") as Label
	if lesson_label == null or not lesson_label.text.contains("clear_brush"):
		_fail("Clear Patch preview did not expose clear_brush tooling. text=%s" % (lesson_label.text if lesson_label else ""))
		return

	var meta_label = game_ui.get("_skill_forge_meta_label") as Label
	if meta_label == null or not meta_label.text.contains("tile_state"):
		_fail("Clear Patch preview did not expose the success check. text=%s" % (meta_label.text if meta_label else ""))
		return

	var trace_label = game_ui.get("_skill_forge_trace_label") as Label
	if trace_label == null or str(trace_label.text) != "Spec > clear_brush":
		_fail("Clear Patch preview did not expose the compact Forge trace. text=%s" % (trace_label.text if trace_label else ""))
		return


func _test_run_button_records_receipts(scene: Node, game_ui) -> void:
	var run_button = game_ui.get("_skill_forge_run_button") as Button
	if run_button == null:
		_fail("Skill Forge run button missing before run.")
		return
	run_button.pressed.emit()
	await process_frame

	var field_log_entries: Array = game_ui.get("_field_log_entries")
	if not _entries_contain(field_log_entries, "Skill Forge started Clear Patch"):
		_fail("Skill Forge UI run did not add a start Field Log receipt. entries=%s" % str(field_log_entries))
		return
	if not _entries_contain(field_log_entries, "Skill Forge passed Clear Patch"):
		_fail("Skill Forge UI run did not add a completion Field Log receipt. entries=%s" % str(field_log_entries))
		return

	var result_label = game_ui.get("_skill_forge_result_label") as Label
	if result_label == null or not result_label.text.contains("Passed"):
		_fail("Skill Forge result label did not show the completed run status. text=%s" % (result_label.text if result_label else ""))
		return

	var trace_label = game_ui.get("_skill_forge_trace_label") as Label
	if trace_label == null or str(trace_label.text) != "Spec > Directive > Work Order > Harness Receipt":
		_fail("Skill Forge run did not show the spec-to-order trace. text=%s" % (trace_label.text if trace_label else ""))
		return

	var events: Array = scene.get_node("GameEventLog").call("get_recent_events", 6)
	if not _event_exists(events, "skill_forge_run", "started"):
		_fail("Skill Forge UI run did not record a started event. events=%s" % str(events))
		return
	if not _event_exists(events, "skill_forge_run", "passed"):
		_fail("Skill Forge UI run did not record a passed event. events=%s" % str(events))
		return


func _entries_contain(entries: Array, needle: String) -> bool:
	for entry in entries:
		if str(entry).contains(needle):
			return true
	return false


func _event_exists(events: Array, event_type: String, status: String) -> bool:
	for event in events:
		if str(event.get("type", "")) != event_type:
			continue
		if str(event.get("status", "")) == status:
			return true
	return false


func _fail(message: String) -> void:
	_failed = true
	push_error(message)
	quit(1)
