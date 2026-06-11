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
	await _test_failed_harness_receipt_keeps_repair_hint(scene, game_ui)
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
	var tend_button = buttons.get("tend_crops_starter", null) as Button
	if tend_button == null or not str(tend_button.tooltip_text).contains("Stage: Starter Spec -> Spec Preview"):
		_fail("Tend Crops template button did not expose the starter-to-preview stage. tooltip=%s" % (str(tend_button.tooltip_text) if tend_button else ""))
		return
	if not str(tend_button.tooltip_text).contains("Preview: Spec > tend_crop > Forge Receipt"):
		_fail("Tend Crops template button did not expose its preview trace. tooltip=%s" % str(tend_button.tooltip_text))
		return

	var run_button = game_ui.get("_skill_forge_run_button") as Button
	if run_button == null:
		_fail("Skill Forge panel did not expose a run button.")
		return
	if run_button.disabled:
		_fail("Skill Forge run button should be enabled for the default valid starter template.")
		return
	if not str(run_button.tooltip_text).contains("Stage: Spec Preview -> Harness Receipt"):
		_fail("Skill Forge run button did not expose its teaching stage path. tooltip=%s" % str(run_button.tooltip_text))
		return

	var review_button = game_ui.get("_skill_forge_review_button") as Button
	if review_button == null or not str(review_button.tooltip_text).contains("Stage: Spec Preview -> Spec Blocked"):
		_fail("Skill Forge Check button did not expose its teaching stage path. tooltip=%s" % (str(review_button.tooltip_text) if review_button else ""))
		return

	var fix_button = game_ui.get("_skill_forge_revision_button") as Button
	if fix_button == null or not str(fix_button.tooltip_text).contains("Stage: Spec Preview"):
		_fail("Skill Forge Fix button did not expose its locked preview stage. tooltip=%s" % (str(fix_button.tooltip_text) if fix_button else ""))
		return
	if _result_text(game_ui) != "Spec Preview: Tend Crops":
		_fail("Skill Forge default preview header did not name the active starter. text=%s" % _result_text(game_ui))
		return
	if not _result_tooltip(game_ui).contains("Preview trace for Tend Crops") or not _result_tooltip(game_ui).contains("route Forge Receipt"):
		_fail("Skill Forge default preview header tooltip did not keep preview trace detail. tooltip=%s" % _result_tooltip(game_ui))
		return

	var summary_label = game_ui.get("_skill_forge_summary_label") as Label
	if summary_label == null or not summary_label.text.contains("Trigger manual"):
		_fail("Skill Forge default preview should expose the trigger contract. text=%s" % (summary_label.text if summary_label else ""))
		return

	var lesson_label = game_ui.get("_skill_forge_lesson_label") as Label
	if lesson_label == null or not lesson_label.text.contains("tend_crop"):
		_fail("Skill Forge default preview should expose Tend Crops tools. text=%s" % (lesson_label.text if lesson_label else ""))
		return
	var trace_label = game_ui.get("_skill_forge_trace_label") as Label
	var preview_tooltip := str(trace_label.tooltip_text) if trace_label != null else ""
	if trace_label == null or not preview_tooltip.contains("Stage: Spec Preview"):
		_fail("Skill Forge default preview did not expose the spec-preview stage. tooltip=%s" % preview_tooltip)
		return
	if trace_label == null or str(trace_label.text) != "Spec > tend_crop > Forge Receipt":
		_fail("Skill Forge default preview did not expose the Forge-only preview route. text=%s" % (trace_label.text if trace_label else ""))
		return
	if _visible_route_text(game_ui) != "Run Route: Spec > Forge Receipt":
		_fail("Skill Forge default preview did not expose the compact route line. text=%s" % _visible_route_text(game_ui))
		return
	if _visible_ref_text(game_ui) != "":
		_fail("Skill Forge default preview should keep run refs hidden. text=%s" % _visible_ref_text(game_ui))
		return
	if not preview_tooltip.contains("route Forge Receipt"):
		_fail("Skill Forge default preview did not expose its Forge-only route. tooltip=%s" % preview_tooltip)
		return
	if not preview_tooltip.contains("check crop_state on selected_tile") or not preview_tooltip.contains("receipt Tend Crops run"):
		_fail("Skill Forge default preview did not expose check/receipt contract details. tooltip=%s" % preview_tooltip)
		return
	if _visible_stage_text(game_ui) != "Stage: Spec Preview | Tend Crops":
		_fail("Skill Forge default preview did not expose the current stage line. text=%s" % _visible_stage_text(game_ui))
		return
	if _visible_next_text(game_ui) != "Next Step: Run for Forge receipt or Check":
		_fail("Skill Forge default preview did not expose the next-step line. text=%s" % _visible_next_text(game_ui))
		return
	if _visible_detail_text(game_ui) != "":
		_fail("Skill Forge default preview should keep the run detail hidden until a concrete run exists. text=%s" % _visible_detail_text(game_ui))
		return
	if _visible_receipt_text(game_ui) != "":
		_fail("Skill Forge default preview should keep the receipt line hidden until a concrete receipt exists. text=%s" % _visible_receipt_text(game_ui))
		return
	if _visible_drift_text(game_ui) != "":
		_fail("Skill Forge default preview should keep Drift hidden. text=%s" % _visible_drift_text(game_ui))
		return
	if not _stage_tooltip(game_ui).contains("Preview trace for Tend Crops"):
		_fail("Skill Forge default preview stage tooltip did not keep preview detail. tooltip=%s" % _stage_tooltip(game_ui))
		return
	if _visible_history_text(game_ui) != "":
		_fail("Skill Forge history trail should stay hidden before a run. text=%s" % _visible_history_text(game_ui))
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
	if not str(clear_button.tooltip_text).contains("Stage: Starter Spec -> Spec Preview"):
		_fail("Clear Patch template button did not expose the starter-to-preview stage. tooltip=%s" % str(clear_button.tooltip_text))
		return
	if not str(clear_button.tooltip_text).contains("Preview: Spec > clear_brush > Crew Order"):
		_fail("Clear Patch template button did not expose its preview trace. tooltip=%s" % str(clear_button.tooltip_text))
		return

	clear_button.pressed.emit()
	var active_id := str(game_ui.get("_active_skill_forge_template_id"))
	if active_id != "clear_patch_starter":
		_fail("Selecting Clear Patch did not update the active template. active=%s" % active_id)
		return
	if _result_text(game_ui) != "Spec Preview: Clear Patch":
		_fail("Clear Patch preview header did not name the selected starter. text=%s" % _result_text(game_ui))
		return
	if not _result_tooltip(game_ui).contains("Preview trace for Clear Patch") or not _result_tooltip(game_ui).contains("route Crew Order"):
		_fail("Clear Patch preview header tooltip did not keep preview trace detail. tooltip=%s" % _result_tooltip(game_ui))
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
	if trace_label == null or str(trace_label.text) != "Spec > clear_brush > Crew Order":
		_fail("Clear Patch preview did not expose the compact Forge trace. text=%s" % (trace_label.text if trace_label else ""))
		return
	if _visible_route_text(game_ui) != "Run Route: Spec > Crew Order":
		_fail("Clear Patch preview did not expose the compact route line. text=%s" % _visible_route_text(game_ui))
		return
	if _visible_ref_text(game_ui) != "":
		_fail("Clear Patch preview should keep run refs hidden. text=%s" % _visible_ref_text(game_ui))
		return
	var preview_tooltip := str(trace_label.tooltip_text)
	if not preview_tooltip.contains("Stage: Spec Preview"):
		_fail("Clear Patch preview did not expose the spec-preview stage. tooltip=%s" % preview_tooltip)
		return
	if not preview_tooltip.contains("route Crew Order"):
		_fail("Clear Patch preview did not expose its crew-order route. tooltip=%s" % preview_tooltip)
		return
	if not preview_tooltip.contains("check tile_state on selected_tile") or not preview_tooltip.contains("receipt Clear Patch run"):
		_fail("Clear Patch preview did not expose check/receipt contract details. tooltip=%s" % preview_tooltip)
		return
	if _visible_stage_text(game_ui) != "Stage: Spec Preview | Clear Patch":
		_fail("Clear Patch preview did not expose the current stage line. text=%s" % _visible_stage_text(game_ui))
		return
	if _visible_next_text(game_ui) != "Next Step: Run to crew order or Check":
		_fail("Clear Patch preview did not expose the next-step line. text=%s" % _visible_next_text(game_ui))
		return
	if _visible_detail_text(game_ui) != "":
		_fail("Clear Patch preview should keep the run detail hidden until a concrete run exists. text=%s" % _visible_detail_text(game_ui))
		return
	if _visible_receipt_text(game_ui) != "":
		_fail("Clear Patch preview should keep the receipt line hidden until a concrete receipt exists. text=%s" % _visible_receipt_text(game_ui))
		return
	if _visible_drift_text(game_ui) != "":
		_fail("Clear Patch preview should keep Drift hidden. text=%s" % _visible_drift_text(game_ui))
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
	if _result_text(game_ui) != "Passed: Clear Patch":
		_fail("Skill Forge run header should stay on the harness result. text=%s" % _result_text(game_ui))
		return
	var result_tooltip := str(result_label.tooltip_text)
	if not result_tooltip.contains("Run Ref: run forge_run_") or not result_tooltip.contains("work order order_"):
		_fail("Skill Forge result tooltip did not expose compact run/order identity. tooltip=%s" % result_tooltip)
		return
	if not result_tooltip.contains("Stage: Harness Receipt"):
		_fail("Skill Forge result tooltip did not expose the harness receipt stage. tooltip=%s" % result_tooltip)
		return
	if not result_tooltip.contains("Run Route: Spec > Crew Order > Harness Receipt"):
		_fail("Skill Forge result tooltip did not expose the harness route. tooltip=%s" % result_tooltip)
		return
	if not result_tooltip.contains("Trace: Spec > Directive > Work Order > Harness Receipt"):
		_fail("Skill Forge result tooltip did not expose the full harness trace path. tooltip=%s" % result_tooltip)
		return
	if not result_tooltip.contains("Next Step: Send crew order"):
		_fail("Skill Forge result tooltip did not expose the next lifecycle step. tooltip=%s" % result_tooltip)
		return

	var trace_label = game_ui.get("_skill_forge_trace_label") as Label
	if trace_label == null or str(trace_label.text) != "Spec > Directive > Work Order > Harness Receipt":
		_fail("Skill Forge run did not show the spec-to-order trace. text=%s" % (trace_label.text if trace_label else ""))
		return
	var trace_tooltip := str(trace_label.tooltip_text)
	if not trace_tooltip.contains("Run History: Passed Clear Patch"):
		_fail("Skill Forge run history did not remember the passed harness receipt. tooltip=%s" % trace_tooltip)
		return
	if not trace_tooltip.contains("Passed Clear Patch (Harness Receipt)"):
		_fail("Skill Forge run history did not name the harness receipt endpoint. tooltip=%s" % trace_tooltip)
		return
	if not trace_tooltip.contains("Run Receipt: manual harness receipt confirmed clear-patch checks"):
		_fail("Skill Forge run trace did not expose labeled receipt detail. tooltip=%s" % trace_tooltip)
		return
	if not trace_tooltip.contains("Stage: Harness Receipt"):
		_fail("Skill Forge run trace did not expose the harness receipt stage. tooltip=%s" % trace_tooltip)
		return
	if not trace_tooltip.contains("Run Route: Spec > Crew Order > Harness Receipt"):
		_fail("Skill Forge run trace did not expose the harness route. tooltip=%s" % trace_tooltip)
		return
	if not trace_tooltip.contains("Directive: work_order_directive") or not trace_tooltip.contains("Tool: clear_brush"):
		_fail("Skill Forge run trace did not expose labeled directive/tool detail. tooltip=%s" % trace_tooltip)
		return
	if not trace_tooltip.contains("Next Step: Send crew order"):
		_fail("Skill Forge run trace did not expose the next lifecycle step. tooltip=%s" % trace_tooltip)
		return
	if not trace_tooltip.contains("Run Context: agent Chuck | target ") or not trace_tooltip.contains("| source Starter Lab"):
		_fail("Skill Forge run trace did not preserve agent/target/source context. tooltip=%s" % trace_tooltip)
		return
	if not trace_tooltip.contains("Run Ref: run forge_run_") or not trace_tooltip.contains("work order order_"):
		_fail("Skill Forge run trace did not expose compact run/order identity. tooltip=%s" % trace_tooltip)
		return
	var history_text := _visible_history_text(game_ui)
	if history_text != "Run Trail: Clear Patch: Passed (Harness Receipt)":
		_fail("Skill Forge visible Run Trail did not summarize the harness receipt. text=%s" % history_text)
		return
	var history_tooltip := _history_tooltip(game_ui)
	if history_tooltip.contains("Run Trail:") or not history_tooltip.contains("Current Run Detail: Passed Clear Patch (Harness Receipt)") or not history_tooltip.contains("manual harness receipt confirmed clear-patch checks"):
		_fail("Skill Forge history tooltip did not keep current detail and full receipt history. tooltip=%s" % history_tooltip)
		return
	if _visible_stage_text(game_ui) != "Stage: Harness Receipt | Clear Patch":
		_fail("Skill Forge run did not expose the harness receipt as the current stage. text=%s" % _visible_stage_text(game_ui))
		return
	if _visible_route_text(game_ui) != "Run Route: Spec > Crew Order > Harness Receipt":
		_fail("Skill Forge run did not expose the compact route line. text=%s" % _visible_route_text(game_ui))
		return
	if not _visible_ref_text(game_ui).begins_with("Run Ref: run forge_run_") or not _visible_ref_text(game_ui).contains("| order order_"):
		_fail("Skill Forge run did not expose compact run/order refs. text=%s" % _visible_ref_text(game_ui))
		return
	if not _stage_tooltip(game_ui).contains("Stage: Harness Receipt") or not _stage_tooltip(game_ui).contains("run forge_run_"):
		_fail("Skill Forge current-stage tooltip did not keep harness trace identity. tooltip=%s" % _stage_tooltip(game_ui))
		return
	if _visible_next_text(game_ui) != "Next Step: Send crew order":
		_fail("Skill Forge run did not expose the crew-order next step. text=%s" % _visible_next_text(game_ui))
		return
	if not _visible_detail_text(game_ui).begins_with("Run Context: agent Chuck | target ") or not _visible_detail_text(game_ui).contains("| source Starter Lab"):
		_fail("Skill Forge run did not expose readable run context. text=%s" % _visible_detail_text(game_ui))
		return
	if not _visible_receipt_text(game_ui).begins_with("Run Receipt: ") or not _visible_receipt_text(game_ui).contains("manual harness receipt confirmed clear-patch checks"):
		_fail("Skill Forge run did not expose compact receipt detail. text=%s" % _visible_receipt_text(game_ui))
		return
	if _visible_drift_text(game_ui) != "":
		_fail("Skill Forge steady run should keep Drift hidden. text=%s" % _visible_drift_text(game_ui))
		return

	var events: Array = scene.get_node("GameEventLog").call("get_recent_events", 6)
	if not _event_exists(events, "skill_forge_run", "started"):
		_fail("Skill Forge UI run did not record a started event. events=%s" % str(events))
		return
	if not _event_exists(events, "skill_forge_run", "passed"):
		_fail("Skill Forge UI run did not record a passed event. events=%s" % str(events))
		return

	var buttons: Dictionary = game_ui.get("_skill_forge_template_buttons")
	var tend_button = buttons.get("tend_crops_starter", null) as Button
	if tend_button == null:
		_fail("Tend Crops template button missing after run.")
		return
	tend_button.pressed.emit()

	if str(trace_label.text) != "Spec > tend_crop > Forge Receipt":
		_fail("Switching templates did not restore Tend Crops preview trace. text=%s" % str(trace_label.text))
		return
	var preview_tooltip := str(trace_label.tooltip_text)
	if not preview_tooltip.contains("Preview trace for Tend Crops") or not preview_tooltip.contains("Run History: Passed Clear Patch"):
		_fail("Forge preview tooltip did not keep recent run history after template switch. tooltip=%s" % preview_tooltip)
		return
	if not preview_tooltip.contains("Passed Clear Patch (Harness Receipt)"):
		_fail("Forge preview tooltip did not keep the harness endpoint in recent run history. tooltip=%s" % preview_tooltip)
		return
	if not preview_tooltip.contains("Stage: Spec Preview"):
		_fail("Forge preview tooltip did not restore the spec-preview stage after template switch. tooltip=%s" % preview_tooltip)
		return
	if _visible_history_text(game_ui) != "Run Trail: Clear Patch: Passed (Harness Receipt)":
		_fail("Forge visible Run Trail did not survive template switch. text=%s" % _visible_history_text(game_ui))
		return
	if _result_text(game_ui) != "Spec Preview: Tend Crops":
		_fail("Forge preview switch should restore the active starter header. text=%s" % _result_text(game_ui))
		return
	if not _result_tooltip(game_ui).contains("route Forge Receipt") or not _result_tooltip(game_ui).contains("Run History: Passed Clear Patch"):
		_fail("Forge preview switch header tooltip did not keep preview and history detail. tooltip=%s" % _result_tooltip(game_ui))
		return
	if _visible_stage_text(game_ui) != "Stage: Spec Preview | Tend Crops":
		_fail("Forge current-stage line did not restore the Tend Crops preview. text=%s" % _visible_stage_text(game_ui))
		return
	if _visible_route_text(game_ui) != "Run Route: Spec > Forge Receipt":
		_fail("Forge preview switch did not restore the compact route line. text=%s" % _visible_route_text(game_ui))
		return
	if _visible_ref_text(game_ui) != "":
		_fail("Forge preview switch should hide concrete run refs. text=%s" % _visible_ref_text(game_ui))
		return
	if _visible_next_text(game_ui) != "Next Step: Run for Forge receipt or Check":
		_fail("Forge next-step line did not restore the Tend Crops preview action. text=%s" % _visible_next_text(game_ui))
		return
	if _visible_detail_text(game_ui) != "":
		_fail("Forge preview should hide run detail after template switch. text=%s" % _visible_detail_text(game_ui))
		return
	if _visible_receipt_text(game_ui) != "":
		_fail("Forge preview should hide receipt detail after template switch. text=%s" % _visible_receipt_text(game_ui))
		return
	if _visible_drift_text(game_ui) != "":
		_fail("Forge preview should hide Drift after template switch. text=%s" % _visible_drift_text(game_ui))
		return


func _test_failed_harness_receipt_keeps_repair_hint(scene: Node, game_ui) -> void:
	var buttons_value = game_ui.get("_skill_forge_template_buttons")
	if typeof(buttons_value) != TYPE_DICTIONARY:
		_fail("Skill Forge panel did not expose template buttons before failed receipt smoke.")
		return
	var buttons: Dictionary = buttons_value
	var clear_button = buttons.get("clear_patch_starter", null) as Button
	if clear_button == null:
		_fail("Clear Patch template button missing before failed receipt smoke.")
		return
	clear_button.pressed.emit()

	var templates = scene.get("_skill_forge_templates")
	var harness = scene.get("_skill_forge_run_harness")
	if templates == null or harness == null:
		_fail("Skill Forge internals were missing before failed receipt smoke.")
		return

	var spec: Dictionary = templates.get_template_spec("clear_patch_starter")
	var start_result: Dictionary = harness.start_manual_run(spec, scene.call("_skill_forge_request_for_template", "clear_patch_starter"))
	scene.call("_apply_skill_forge_result", start_result)
	await process_frame

	var failed_result: Dictionary = harness.complete_run(start_result, false, {
		"result_detail": "selected tile had no brush"
	})
	scene.call("_apply_skill_forge_result", failed_result)
	await process_frame

	var result_label = game_ui.get("_skill_forge_result_label") as Label
	if result_label == null or not str(result_label.text).contains("Failed"):
		_fail("Failed Forge receipt did not update the result label. text=%s" % (result_label.text if result_label else ""))
		return
	if _result_text(game_ui) != "Failed: Clear Patch":
		_fail("Failed Forge receipt header should stay on the harness result. text=%s" % _result_text(game_ui))
		return
	var result_tooltip := str(result_label.tooltip_text)
	if not result_tooltip.contains("selected tile had no brush") or not result_tooltip.contains("Fix: Pick a brush tile or revise the condition."):
		_fail("Failed Forge result tooltip did not keep receipt detail and repair hint. tooltip=%s" % result_tooltip)
		return
	if not result_tooltip.contains("run forge_run_") or not result_tooltip.contains("work order order_"):
		_fail("Failed Forge result tooltip did not expose compact run/order identity. tooltip=%s" % result_tooltip)
		return
	if not result_tooltip.contains("Stage: Harness Receipt"):
		_fail("Failed Forge result tooltip did not expose the harness receipt stage. tooltip=%s" % result_tooltip)
		return
	if not result_tooltip.contains("Trace: Spec > Directive > Work Order > Harness Receipt"):
		_fail("Failed Forge result tooltip did not expose the full harness trace path. tooltip=%s" % result_tooltip)
		return

	var trace_label = game_ui.get("_skill_forge_trace_label") as Label
	if trace_label == null or str(trace_label.text) != "Spec > Directive > Work Order > Harness Receipt":
		_fail("Failed Forge receipt did not keep the harness trace. text=%s" % (trace_label.text if trace_label else ""))
		return
	var trace_tooltip := str(trace_label.tooltip_text)
	if not trace_tooltip.contains("Run Receipt: selected tile had no brush"):
		_fail("Failed Forge trace did not keep the harness receipt detail. tooltip=%s" % trace_tooltip)
		return
	var passed_history_index := trace_tooltip.find("Run History: Passed Clear Patch")
	var failed_history_index := trace_tooltip.find("Failed Clear Patch")
	if passed_history_index == -1 or failed_history_index <= passed_history_index or not trace_tooltip.contains("Fix: Pick a brush tile or revise the condition."):
		_fail("Failed Forge trace history did not keep chronological receipts and repair hint. tooltip=%s" % trace_tooltip)
		return
	if not trace_tooltip.contains("Failed Clear Patch (Harness Receipt)"):
		_fail("Failed Forge trace history did not name the harness receipt endpoint. tooltip=%s" % trace_tooltip)
		return
	if not trace_tooltip.contains("Stage: Harness Receipt"):
		_fail("Failed Forge trace did not expose the harness receipt stage. tooltip=%s" % trace_tooltip)
		return
	var failed_history_text := _visible_history_text(game_ui)
	if failed_history_text != "Run Trail: Clear Patch: Passed (Harness Receipt) > Failed (Harness Receipt)" or failed_history_text.contains("selected tile had no brush"):
		_fail("Failed Forge visible Run Trail was not compact. text=%s" % failed_history_text)
		return
	var failed_history_tooltip := _history_tooltip(game_ui)
	if not failed_history_tooltip.contains("Current Run Detail: Failed Clear Patch (Harness Receipt)") or not failed_history_tooltip.contains("selected tile had no brush") or not failed_history_tooltip.contains("Fix: Pick a brush tile or revise the condition."):
		_fail("Failed Forge history tooltip did not keep current repair detail. tooltip=%s" % failed_history_tooltip)
		return
	if _visible_stage_text(game_ui) != "Stage: Harness Receipt | Clear Patch":
		_fail("Failed Forge receipt did not keep the harness receipt as the current stage. text=%s" % _visible_stage_text(game_ui))
		return
	if _visible_route_text(game_ui) != "Run Route: Spec > Crew Order > Harness Receipt":
		_fail("Failed Forge receipt did not expose the compact route line. text=%s" % _visible_route_text(game_ui))
		return
	if not _visible_ref_text(game_ui).begins_with("Run Ref: run forge_run_") or not _visible_ref_text(game_ui).contains("| order order_"):
		_fail("Failed Forge receipt did not expose compact run/order refs. text=%s" % _visible_ref_text(game_ui))
		return
	if not _stage_tooltip(game_ui).contains("selected tile had no brush"):
		_fail("Failed Forge current-stage tooltip did not keep receipt detail. tooltip=%s" % _stage_tooltip(game_ui))
		return
	if _visible_next_text(game_ui) != "Next Step: Revise and rerun":
		_fail("Failed Forge receipt did not expose the repair next step. text=%s" % _visible_next_text(game_ui))
		return
	if not _visible_detail_text(game_ui).begins_with("Run Context: agent Chuck | target ") or not _visible_detail_text(game_ui).contains("| source Starter Lab"):
		_fail("Failed Forge receipt did not expose readable run context. text=%s" % _visible_detail_text(game_ui))
		return
	if not _visible_receipt_text(game_ui).begins_with("Run Receipt: ") or not _visible_receipt_text(game_ui).contains("selected tile had no brush"):
		_fail("Failed Forge receipt did not expose compact receipt detail. text=%s" % _visible_receipt_text(game_ui))
		return
	if _visible_drift_text(game_ui) != "":
		_fail("Failed steady Forge receipt should keep Drift hidden. text=%s" % _visible_drift_text(game_ui))
		return

	var field_log_entries: Array = game_ui.get("_field_log_entries")
	if not _entries_contain(field_log_entries, "Skill Forge failed Clear Patch") or not _entries_contain(field_log_entries, "Pick a brush tile or revise the condition."):
		_fail("Failed Forge receipt did not leave readable Field Log copy. entries=%s" % str(field_log_entries))
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


func _result_text(game_ui) -> String:
	var result_label = game_ui.get("_skill_forge_result_label") as Label
	return str(result_label.text) if result_label != null else ""


func _result_tooltip(game_ui) -> String:
	var result_label = game_ui.get("_skill_forge_result_label") as Label
	return str(result_label.tooltip_text) if result_label != null else ""


func _visible_stage_text(game_ui) -> String:
	var stage_label = game_ui.get("_skill_forge_stage_label") as Label
	if stage_label == null or not stage_label.visible:
		return ""
	return str(stage_label.text)


func _visible_route_text(game_ui) -> String:
	var route_label = game_ui.get("_skill_forge_route_label") as Label
	if route_label == null or not route_label.visible:
		return ""
	return str(route_label.text)


func _visible_ref_text(game_ui) -> String:
	var ref_label = game_ui.get("_skill_forge_ref_label") as Label
	if ref_label == null or not ref_label.visible:
		return ""
	return str(ref_label.text)


func _stage_tooltip(game_ui) -> String:
	var stage_label = game_ui.get("_skill_forge_stage_label") as Label
	return str(stage_label.tooltip_text) if stage_label != null else ""


func _visible_next_text(game_ui) -> String:
	var next_label = game_ui.get("_skill_forge_next_label") as Label
	if next_label == null or not next_label.visible:
		return ""
	return str(next_label.text)


func _visible_detail_text(game_ui) -> String:
	var detail_label = game_ui.get("_skill_forge_detail_label") as Label
	if detail_label == null or not detail_label.visible:
		return ""
	return str(detail_label.text)


func _visible_receipt_text(game_ui) -> String:
	var receipt_label = game_ui.get("_skill_forge_receipt_label") as Label
	if receipt_label == null or not receipt_label.visible:
		return ""
	return str(receipt_label.text)


func _visible_drift_text(game_ui) -> String:
	var drift_label = game_ui.get("_skill_forge_drift_label") as Label
	if drift_label == null or not drift_label.visible:
		return ""
	return str(drift_label.text)


func _visible_history_text(game_ui) -> String:
	var history_label = game_ui.get("_skill_forge_history_label") as Label
	if history_label == null or not history_label.visible:
		return ""
	return str(history_label.text)


func _history_tooltip(game_ui) -> String:
	var history_label = game_ui.get("_skill_forge_history_label") as Label
	return str(history_label.tooltip_text) if history_label != null else ""


func _fail(message: String) -> void:
	_failed = true
	push_error(message)
	quit(1)
