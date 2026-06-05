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
	_select_clear_patch(game_ui)
	if _failed:
		return
	await _test_blocked_draft_shows_revision_copy(scene, game_ui)
	if _failed:
		return
	await _test_fix_button_reruns_clean_template(scene, game_ui)
	if _failed:
		return

	scene.queue_free()
	if not _failed:
		quit()


func _select_clear_patch(game_ui) -> void:
	var buttons_value = game_ui.get("_skill_forge_template_buttons")
	if typeof(buttons_value) != TYPE_DICTIONARY:
		_fail("Skill Forge panel did not expose template buttons.")
		return
	var buttons: Dictionary = buttons_value
	var clear_button = buttons.get("clear_patch_starter", null) as Button
	if clear_button == null:
		_fail("Clear Patch template button missing.")
		return
	clear_button.pressed.emit()


func _test_blocked_draft_shows_revision_copy(scene: Node, game_ui) -> void:
	var review_button = game_ui.get("_skill_forge_review_button") as Button
	if review_button == null:
		_fail("Skill Forge revision loop did not expose a draft review button.")
		return
	review_button.pressed.emit()
	await process_frame

	var result_label = game_ui.get("_skill_forge_result_label") as Label
	if result_label == null or not result_label.text.contains("Blocked"):
		_fail("Blocked draft did not update the Forge result label. text=%s" % (result_label.text if result_label else ""))
		return

	var summary_label = game_ui.get("_skill_forge_summary_label") as Label
	if summary_label == null or not summary_label.text.contains("summon_rain"):
		_fail("Blocked draft did not show the validator issue. text=%s" % (summary_label.text if summary_label else ""))
		return

	var meta_label = game_ui.get("_skill_forge_meta_label") as Label
	if meta_label == null or not meta_label.text.contains("Replace summon_rain"):
		_fail("Blocked draft did not show a concrete revision suggestion. text=%s" % (meta_label.text if meta_label else ""))
		return

	var fix_button = game_ui.get("_skill_forge_revision_button") as Button
	if fix_button == null or fix_button.disabled:
		_fail("Blocked draft did not enable the Fix button.")
		return

	var field_log_entries: Array = game_ui.get("_field_log_entries")
	if not _entries_contain(field_log_entries, "Skill Forge blocked Clear Patch"):
		_fail("Blocked draft did not write a Field Log receipt. entries=%s" % str(field_log_entries))
		return

	var events: Array = scene.get_node("GameEventLog").call("get_recent_events", 6)
	if not _event_exists(events, "skill_forge_run", "blocked"):
		_fail("Blocked draft did not record a skill_forge_run blocked event. events=%s" % str(events))
		return
	if not _event_has_drift(events, "blocked", "hallucinating"):
		_fail("Blocked draft did not record hallucinating drift. events=%s" % str(events))
		return

	var trace_label = game_ui.get("_skill_forge_trace_label") as Label
	var blocked_tooltip := str(trace_label.tooltip_text) if trace_label != null else ""
	if trace_label == null or not blocked_tooltip.contains("History: Blocked Clear Patch"):
		_fail("Blocked draft did not land in the Forge history tooltip. tooltip=%s" % blocked_tooltip)
		return
	if not blocked_tooltip.contains("[Drift hallucinating]") or not blocked_tooltip.contains("Fix: Replace summon_rain with clear_brush"):
		_fail("Blocked draft history did not keep Drift and Fix detail. tooltip=%s" % blocked_tooltip)
		return
	if not blocked_tooltip.contains("Blocked Clear Patch (Spec Blocked)"):
		_fail("Blocked draft history did not name the spec-blocked endpoint. tooltip=%s" % blocked_tooltip)
		return


func _test_fix_button_reruns_clean_template(scene: Node, game_ui) -> void:
	var fix_button = game_ui.get("_skill_forge_revision_button") as Button
	fix_button.pressed.emit()
	await process_frame

	var result_label = game_ui.get("_skill_forge_result_label") as Label
	if result_label == null or not result_label.text.contains("Passed"):
		_fail("Fix button did not rerun the clean template to passed. text=%s" % (result_label.text if result_label else ""))
		return
	if not fix_button.disabled:
		_fail("Fix button should disable after the clean revision passes.")
		return

	var field_log_entries: Array = game_ui.get("_field_log_entries")
	if not _entries_contain(field_log_entries, "Skill Forge passed Clear Patch"):
		_fail("Clean revision did not write a passed Field Log receipt. entries=%s" % str(field_log_entries))
		return

	var events: Array = scene.get_node("GameEventLog").call("get_recent_events", 8)
	if not _event_exists(events, "skill_forge_run", "passed"):
		_fail("Clean revision did not record a passed event. events=%s" % str(events))
		return

	var trace_label = game_ui.get("_skill_forge_trace_label") as Label
	if trace_label == null:
		_fail("Clean revision did not keep the Forge trace label.")
		return
	var trace_tooltip := str(trace_label.tooltip_text)
	if not trace_tooltip.contains("History: Passed Clear Patch") or not trace_tooltip.contains("Blocked Clear Patch"):
		_fail("Clean revision history did not keep the recent pass/block receipts. tooltip=%s" % trace_tooltip)
		return
	if not trace_tooltip.contains("Passed Clear Patch (Harness Receipt)") or not trace_tooltip.contains("Blocked Clear Patch (Spec Blocked)"):
		_fail("Clean revision history did not name the harness/spec endpoints. tooltip=%s" % trace_tooltip)
		return
	if not trace_tooltip.contains("[Drift hallucinating]") or not trace_tooltip.contains("Fix: Replace summon_rain with clear_brush"):
		_fail("Clean revision history dropped blocked-run repair detail. tooltip=%s" % trace_tooltip)
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


func _event_has_drift(events: Array, status: String, drift_level: String) -> bool:
	for event in events:
		if str(event.get("type", "")) != "skill_forge_run":
			continue
		if str(event.get("status", "")) == status and str(event.get("drift_level", "")) == drift_level:
			return true
	return false


func _fail(message: String) -> void:
	_failed = true
	push_error(message)
	quit(1)
