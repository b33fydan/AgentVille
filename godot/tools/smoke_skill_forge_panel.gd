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
	await _test_run_button_stays_pending(scene, game_ui)
	if _failed:
		return
	await _test_failed_world_check_keeps_repair_hint(scene, game_ui)
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
	if not buttons.has("tend_crops_starter") or not buttons.has("plant_seed_starter") or not buttons.has("clear_patch_starter") or not buttons.has("harvest_crops_starter") or not buttons.has("build_fence_starter"):
		_fail("Skill Forge panel did not expose all starter templates. buttons=%s" % str(buttons.keys()))
		return
	var tend_button = buttons.get("tend_crops_starter", null) as Button
	if tend_button == null or not str(tend_button.tooltip_text).contains("Stage: Starter Spec -> Spec Preview"):
		_fail("Tend Crops template button did not expose the starter-to-preview stage. tooltip=%s" % (str(tend_button.tooltip_text) if tend_button else ""))
		return
	if not str(tend_button.tooltip_text).contains("Run Preview: Spec > tend_crop > Crew Order"):
		_fail("Tend Crops template button did not expose its preview trace. tooltip=%s" % str(tend_button.tooltip_text))
		return
	var plant_button = buttons.get("plant_seed_starter", null) as Button
	if plant_button == null or str(plant_button.text) != "PLT\nSeed":
		_fail("Plant Seed template button did not expose its compact label. text=%s" % (str(plant_button.text) if plant_button else ""))
		return
	if not str(plant_button.tooltip_text).contains("Run Preview: Spec > plant_seed > Crew Order"):
		_fail("Plant Seed template button did not expose its crew-order preview trace. tooltip=%s" % str(plant_button.tooltip_text))
		return
	var harvest_button = buttons.get("harvest_crops_starter", null) as Button
	if harvest_button == null or str(harvest_button.text) != "HRV\nCrops":
		_fail("Harvest Crops template button did not expose its compact label. text=%s" % (str(harvest_button.text) if harvest_button else ""))
		return
	if not str(harvest_button.tooltip_text).contains("Run Preview: Spec > harvest_crop > Crew Order"):
		_fail("Harvest Crops template button did not expose its preview trace. tooltip=%s" % str(harvest_button.tooltip_text))
		return
	var build_button = buttons.get("build_fence_starter", null) as Button
	if build_button == null or str(build_button.text) != "FNC\nFence":
		_fail("Build Fence template button did not expose its compact label. text=%s" % (str(build_button.text) if build_button else ""))
		return
	if not str(build_button.tooltip_text).contains("Run Preview: Spec > build_fence > Crew Order"):
		_fail("Build Fence template button did not expose its preview trace. tooltip=%s" % str(build_button.tooltip_text))
		return

	var run_button = game_ui.get("_skill_forge_run_button") as Button
	if run_button == null:
		_fail("Skill Forge panel did not expose a run button.")
		return
	if run_button.disabled:
		_fail("Skill Forge run button should be enabled for the default valid starter template.")
		return
	if not str(run_button.tooltip_text).contains("Stage: Spec Preview -> Crew Order -> World Check"):
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
	if not _result_tooltip(game_ui).contains("Run Target: Tend Crops") or not _result_tooltip(game_ui).contains("Run Route: Spec > Crew Order"):
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
	if trace_label == null or str(trace_label.text) != "Run Trace: Spec > tend_crop > Crew Order":
		_fail("Skill Forge default preview did not expose the crew-order preview route. text=%s" % (trace_label.text if trace_label else ""))
		return
	if _visible_route_text(game_ui) != "Run Route: Spec > Crew Order":
		_fail("Skill Forge default preview did not expose the compact route line. text=%s" % _visible_route_text(game_ui))
		return
	if _visible_ref_text(game_ui) != "":
		_fail("Skill Forge default preview should keep run refs hidden. text=%s" % _visible_ref_text(game_ui))
		return
	if not preview_tooltip.contains("Run Route: Spec > Crew Order"):
		_fail("Skill Forge default preview did not expose its crew-order route. tooltip=%s" % preview_tooltip)
		return
	if not preview_tooltip.contains("Spec Tools: inspect_tile -> tend_crop") or not preview_tooltip.contains("Success Check: crop_state on selected_tile") or not preview_tooltip.contains("Run Receipt: Tend Crops run"):
		_fail("Skill Forge default preview did not expose check/receipt contract details. tooltip=%s" % preview_tooltip)
		return
	if _visible_stage_text(game_ui) != "Stage: Spec Preview | Tend Crops":
		_fail("Skill Forge default preview did not expose the current stage line. text=%s" % _visible_stage_text(game_ui))
		return
	if _visible_next_text(game_ui) != "Next Step: Run to Tend Crops order or Check":
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
	if not _stage_tooltip(game_ui).contains("Run Target: Tend Crops"):
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
	if not str(clear_button.tooltip_text).contains("Run Preview: Spec > clear_brush > Crew Order"):
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
	if not _result_tooltip(game_ui).contains("Run Target: Clear Patch") or not _result_tooltip(game_ui).contains("Run Route: Spec > Crew Order"):
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
	if trace_label == null or str(trace_label.text) != "Run Trace: Spec > clear_brush > Crew Order":
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
	if not preview_tooltip.contains("Run Trace: Spec > clear_brush > Crew Order"):
		_fail("Clear Patch preview did not expose the labeled run trace path. tooltip=%s" % preview_tooltip)
		return
	if not preview_tooltip.contains("Run Route: Spec > Crew Order"):
		_fail("Clear Patch preview did not expose its crew-order route. tooltip=%s" % preview_tooltip)
		return
	if not preview_tooltip.contains("Spec Tools: inspect_tile -> clear_brush") or not preview_tooltip.contains("Success Check: tile_state on selected_tile") or not preview_tooltip.contains("Run Receipt: Clear Patch run"):
		_fail("Clear Patch preview did not expose check/receipt contract details. tooltip=%s" % preview_tooltip)
		return
	if _visible_stage_text(game_ui) != "Stage: Spec Preview | Clear Patch":
		_fail("Clear Patch preview did not expose the current stage line. text=%s" % _visible_stage_text(game_ui))
		return
	if _visible_next_text(game_ui) != "Next Step: Run to Clear Patch order or Check":
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

	var harvest_button = buttons.get("harvest_crops_starter", null) as Button
	if harvest_button == null:
		_fail("Harvest Crops template button missing.")
		return
	if not str(harvest_button.tooltip_text).contains("Stage: Starter Spec -> Spec Preview"):
		_fail("Harvest Crops template button did not expose the starter-to-preview stage. tooltip=%s" % str(harvest_button.tooltip_text))
		return
	if not str(harvest_button.tooltip_text).contains("Run Preview: Spec > harvest_crop > Crew Order"):
		_fail("Harvest Crops template button did not expose its preview trace. tooltip=%s" % str(harvest_button.tooltip_text))
		return

	harvest_button.pressed.emit()
	active_id = str(game_ui.get("_active_skill_forge_template_id"))
	if active_id != "harvest_crops_starter":
		_fail("Selecting Harvest Crops did not update the active template. active=%s" % active_id)
		return
	if _result_text(game_ui) != "Spec Preview: Harvest Crops":
		_fail("Harvest Crops preview header did not name the selected starter. text=%s" % _result_text(game_ui))
		return
	if not _result_tooltip(game_ui).contains("Run Target: Harvest Crops") or not _result_tooltip(game_ui).contains("Run Route: Spec > Crew Order"):
		_fail("Harvest Crops preview header tooltip did not keep preview trace detail. tooltip=%s" % _result_tooltip(game_ui))
		return
	if summary_label == null or not summary_label.text.contains("Context selected_tile"):
		_fail("Harvest Crops preview did not expose selected-tile context. text=%s" % (summary_label.text if summary_label else ""))
		return
	if lesson_label == null or not lesson_label.text.contains("harvest_crop"):
		_fail("Harvest Crops preview did not expose harvest_crop tooling. text=%s" % (lesson_label.text if lesson_label else ""))
		return
	if meta_label == null or not meta_label.text.contains("inventory_delta"):
		_fail("Harvest Crops preview did not expose the inventory success check. text=%s" % (meta_label.text if meta_label else ""))
		return
	if trace_label == null or str(trace_label.text) != "Run Trace: Spec > harvest_crop > Crew Order":
		_fail("Harvest Crops preview did not expose the compact Forge trace. text=%s" % (trace_label.text if trace_label else ""))
		return
	if _visible_route_text(game_ui) != "Run Route: Spec > Crew Order":
		_fail("Harvest Crops preview did not expose the compact route line. text=%s" % _visible_route_text(game_ui))
		return
	var harvest_tooltip := str(trace_label.tooltip_text)
	if not harvest_tooltip.contains("Spec Tools: inspect_tile -> harvest_crop") or not harvest_tooltip.contains("Success Check: inventory_delta on selected_tile") or not harvest_tooltip.contains("Run Receipt: Harvest Crops run"):
		_fail("Harvest Crops preview did not expose check/receipt contract details. tooltip=%s" % harvest_tooltip)
		return
	if _visible_stage_text(game_ui) != "Stage: Spec Preview | Harvest Crops":
		_fail("Harvest Crops preview did not expose the current stage line. text=%s" % _visible_stage_text(game_ui))
		return
	if _visible_next_text(game_ui) != "Next Step: Run to Harvest Crops order or Check":
		_fail("Harvest Crops preview did not expose the next-step line. text=%s" % _visible_next_text(game_ui))
		return

	var build_button = buttons.get("build_fence_starter", null) as Button
	if build_button == null:
		_fail("Build Fence template button missing.")
		return
	if not str(build_button.tooltip_text).contains("Stage: Starter Spec -> Spec Preview"):
		_fail("Build Fence template button did not expose the starter-to-preview stage. tooltip=%s" % str(build_button.tooltip_text))
		return
	if not str(build_button.tooltip_text).contains("Run Preview: Spec > build_fence > Crew Order"):
		_fail("Build Fence template button did not expose its preview trace. tooltip=%s" % str(build_button.tooltip_text))
		return

	build_button.pressed.emit()
	active_id = str(game_ui.get("_active_skill_forge_template_id"))
	if active_id != "build_fence_starter":
		_fail("Selecting Build Fence did not update the active template. active=%s" % active_id)
		return
	if _result_text(game_ui) != "Spec Preview: Build Fence":
		_fail("Build Fence preview header did not name the selected starter. text=%s" % _result_text(game_ui))
		return
	if not _result_tooltip(game_ui).contains("Run Target: Build Fence") or not _result_tooltip(game_ui).contains("Run Route: Spec > Crew Order"):
		_fail("Build Fence preview header tooltip did not keep preview trace detail. tooltip=%s" % _result_tooltip(game_ui))
		return
	if lesson_label == null or not lesson_label.text.contains("build_fence"):
		_fail("Build Fence preview did not expose build_fence tooling. text=%s" % (lesson_label.text if lesson_label else ""))
		return
	if meta_label == null or not meta_label.text.contains("tile_state"):
		_fail("Build Fence preview did not expose the tile-state success check. text=%s" % (meta_label.text if meta_label else ""))
		return
	if trace_label == null or str(trace_label.text) != "Run Trace: Spec > build_fence > Crew Order":
		_fail("Build Fence preview did not expose the compact Forge trace. text=%s" % (trace_label.text if trace_label else ""))
		return
	if _visible_route_text(game_ui) != "Run Route: Spec > Crew Order":
		_fail("Build Fence preview did not expose the compact route line. text=%s" % _visible_route_text(game_ui))
		return
	var build_tooltip := str(trace_label.tooltip_text)
	if not build_tooltip.contains("Spec Tools: inspect_tile -> build_fence") or not build_tooltip.contains("Success Check: tile_state on selected_tile") or not build_tooltip.contains("Run Receipt: Build Fence run"):
		_fail("Build Fence preview did not expose check/receipt contract details. tooltip=%s" % build_tooltip)
		return
	if _visible_stage_text(game_ui) != "Stage: Spec Preview | Build Fence":
		_fail("Build Fence preview did not expose the current stage line. text=%s" % _visible_stage_text(game_ui))
		return
	if _visible_next_text(game_ui) != "Next Step: Run to Build Fence order or Check":
		_fail("Build Fence preview did not expose the next-step line. text=%s" % _visible_next_text(game_ui))
		return

	clear_button.pressed.emit()


func _test_run_button_stays_pending(scene: Node, game_ui) -> void:
	var run_button = game_ui.get("_skill_forge_run_button") as Button
	if run_button == null:
		_fail("Skill Forge run button missing before run.")
		return
	run_button.pressed.emit()
	await process_frame
	var honest_entries: Array = game_ui.get("_field_log_entries")
	if not _entries_contain(honest_entries, "Skill Forge started Clear Patch") or not _entries_contain(honest_entries, "Forge order drafted: Clear Patch"):
		_fail("Skill Forge Run did not draft an honest pending crew order. entries=%s" % str(honest_entries))
		return
	if _entries_contain(honest_entries, "Skill Forge passed Clear Patch"):
		_fail("Skill Forge Run fabricated a pass before world verification. entries=%s" % str(honest_entries))
		return
	if _result_text(game_ui) != "Started: Clear Patch":
		_fail("Pending Forge run did not remain Started. text=%s" % _result_text(game_ui))
		return
	if _visible_stage_text(game_ui) != "Stage: Work Order | Clear Patch" or _visible_next_text(game_ui) != "Next Step: Send crew order":
		_fail("Pending Forge run did not expose the Work Order -> Send lifecycle. stage=%s next=%s" % [_visible_stage_text(game_ui), _visible_next_text(game_ui)])
		return
	if _visible_route_text(game_ui) != "Run Route: Spec > Crew Order" or not _visible_receipt_text(game_ui).contains("verification pending"):
		_fail("Pending Forge run did not expose its truthful route/receipt. route=%s receipt=%s" % [_visible_route_text(game_ui), _visible_receipt_text(game_ui)])
		return
	var pending_events: Array = scene.get_node("GameEventLog").call("get_recent_events", 6)
	if not _event_exists(pending_events, "skill_forge_run", "started") or _event_exists(pending_events, "skill_forge_run", "passed"):
		_fail("Pending Forge run event history was not start-only. events=%s" % str(pending_events))
		return
	return

func _test_failed_world_check_keeps_repair_hint(scene: Node, game_ui) -> void:
	scene.call("_cancel_pending_skill_forge_run", "order never completed; panel smoke moved to failure coverage", true)
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
	var honest_result_label = game_ui.get("_skill_forge_result_label") as Label
	if honest_result_label == null or str(honest_result_label.text) != "Failed: Clear Patch":
		_fail("Failed world check did not update the result label. text=%s" % (honest_result_label.text if honest_result_label else ""))
		return
	var honest_tooltip := str(honest_result_label.tooltip_text)
	if not honest_tooltip.contains("Stage: World Check") or not honest_tooltip.contains("Run Receipt: selected tile had no brush") or not honest_tooltip.contains("Fix: Pick a brush tile or revise the condition."):
		_fail("Failed world check did not preserve its stage, observation, and repair hint. tooltip=%s" % honest_tooltip)
		return
	if _visible_stage_text(game_ui) != "Stage: World Check | Clear Patch" or _visible_next_text(game_ui) != "Next Step: Revise and rerun":
		_fail("Failed world check did not expose the repair lifecycle. stage=%s next=%s" % [_visible_stage_text(game_ui), _visible_next_text(game_ui)])
		return
	if not _entries_contain(game_ui.get("_field_log_entries"), "Skill Forge failed Clear Patch"):
		_fail("Failed world check did not leave a Field Log receipt.")
		return
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


func _lesson_text(game_ui) -> String:
	var lesson_label = game_ui.get("_skill_forge_lesson_label") as Label
	return str(lesson_label.text) if lesson_label != null else ""


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
