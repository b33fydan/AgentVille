extends SceneTree

const SkillForgeTemplateLibraryScript := preload("res://scripts/systems/SkillForgeTemplateLibrary.gd")

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_template_preview_exposes_structured_contract()
	if _failed:
		return
	await _test_panel_renders_structured_contract()
	if _failed:
		return

	if not _failed:
		quit()


func _test_template_preview_exposes_structured_contract() -> void:
	var library = SkillForgeTemplateLibraryScript.new()
	var preview: Dictionary = library.get_template_preview("clear_patch_starter")

	if str(preview.get("trigger_type", "")) != "manual":
		_fail("Clear Patch preview did not expose manual trigger. preview=%s" % str(preview))
		return
	if str(preview.get("context_label", "")) != "selected_tile":
		_fail("Clear Patch preview did not expose selected tile context. preview=%s" % str(preview))
		return
	if str(preview.get("tools_label", "")) != "inspect_tile -> clear_brush":
		_fail("Clear Patch preview did not expose ordered tool calls. preview=%s" % str(preview))
		return
	if not str(preview.get("step_label", "")).contains("inspect"):
		_fail("Clear Patch preview did not expose step ids. preview=%s" % str(preview))
		return
	if str(preview.get("check_label", "")) != "tile_state on selected_tile":
		_fail("Clear Patch preview did not expose readable success check. preview=%s" % str(preview))
		return
	if str(preview.get("receipt_label", "")) != "Clear Patch run":
		_fail("Clear Patch preview did not expose receipt label. preview=%s" % str(preview))
		return


func _test_panel_renders_structured_contract() -> void:
	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	root.size = Vector2i(1600, 900)
	await process_frame
	await process_frame

	var game_ui = scene.get_node("GameUI")
	var buttons_value = game_ui.get("_skill_forge_template_buttons")
	if typeof(buttons_value) != TYPE_DICTIONARY:
		_fail("Skill Forge panel did not expose template buttons.")
		return
	var buttons: Dictionary = buttons_value
	var clear_button = buttons.get("clear_patch_starter", null) as Button
	if clear_button == null:
		_fail("Clear Patch template button missing.")
		return
	if not str(clear_button.tooltip_text).contains("Stage: Starter Spec -> Spec Preview"):
		_fail("Clear Patch template tooltip did not expose the starter-to-preview stage. tooltip=%s" % str(clear_button.tooltip_text))
		return
	if not str(clear_button.tooltip_text).contains("Preview: Spec > clear_brush"):
		_fail("Clear Patch template tooltip did not expose the compact preview trace. tooltip=%s" % str(clear_button.tooltip_text))
		return
	clear_button.pressed.emit()

	var summary_label = game_ui.get("_skill_forge_summary_label") as Label
	if summary_label == null or not summary_label.text.contains("Trigger manual"):
		_fail("Panel summary did not show trigger/context spec fields. text=%s" % (summary_label.text if summary_label else ""))
		return
	if not summary_label.text.contains("Context selected_tile"):
		_fail("Panel summary did not show selected tile context. text=%s" % summary_label.text)
		return

	var lesson_label = game_ui.get("_skill_forge_lesson_label") as Label
	if lesson_label == null or not lesson_label.visible:
		_fail("Panel did not expose the structured tool/step detail label.")
		return
	if not lesson_label.text.contains("Tools inspect_tile -> clear_brush"):
		_fail("Panel detail did not show ordered tools. text=%s" % lesson_label.text)
		return
	if not lesson_label.text.contains("Steps inspect -> clear"):
		_fail("Panel detail did not show step ids. text=%s" % lesson_label.text)
		return

	var meta_label = game_ui.get("_skill_forge_meta_label") as Label
	if meta_label == null or not meta_label.text.contains("Check tile_state on selected_tile"):
		_fail("Panel meta did not show the success check. text=%s" % (meta_label.text if meta_label else ""))
		return
	if not meta_label.text.contains("Receipt Clear Patch run"):
		_fail("Panel meta did not show the receipt label. text=%s" % meta_label.text)
		return
	var trace_label = game_ui.get("_skill_forge_trace_label") as Label
	var trace_tooltip := str(trace_label.tooltip_text) if trace_label != null else ""
	if trace_label == null or not trace_tooltip.contains("Stage: Spec Preview"):
		_fail("Panel preview trace did not expose the spec-preview stage. tooltip=%s" % trace_tooltip)
		return

	scene.queue_free()


func _fail(message: String) -> void:
	_failed = true
	push_error(message)
	quit(1)
