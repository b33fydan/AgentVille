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
	await _test_clear_patch_drafts_ready_work_order(scene, game_ui)
	if _failed:
		return
	await _test_tend_crops_stays_receipt_only(scene, game_ui)
	if _failed:
		return

	scene.queue_free()
	await process_frame
	await _test_clear_patch_order_blocked_trace()
	if _failed:
		return

	if not _failed:
		quit()


func _test_clear_patch_drafts_ready_work_order(scene: Node, game_ui) -> void:
	_select_template(game_ui, "clear_patch_starter")
	if _failed:
		return

	var before_count := _forge_order_count(scene)
	var run_button = game_ui.get("_skill_forge_run_button") as Button
	if run_button == null:
		_fail("Skill Forge run button missing before Clear Patch run.")
		return
	run_button.pressed.emit()
	await process_frame

	if _forge_order_count(scene) != before_count + 1:
		_fail("Clear Patch did not draft exactly one Forge work order. before=%s after=%s" % [before_count, _forge_order_count(scene)])
		return

	var order_id := _latest_forge_order_id(scene, "clear_patch_starter")
	if order_id == "":
		_fail("Clear Patch did not create a Forge-tagged work order.")
		return
	var order: Dictionary = scene.work_orders.get(order_id, {})
	if str(order.get("status", "")) != "ready":
		_fail("Forge work order should start ready. order=%s" % str(order))
		return
	if str(order.get("action", "")) != "clear_brush" or str(order.get("agent_action", "")) != "clear_brush":
		_fail("Forge work order did not keep the clear_brush directive. order=%s" % str(order))
		return
	if str(order.get("source", "")) != "skill_forge" or str(order.get("preference_source", "")) != "skill_forge":
		_fail("Forge work order did not keep Skill Forge source context. order=%s" % str(order))
		return
	if str(order.get("skill_name", "")) != "Clear Patch":
		_fail("Forge work order did not keep a readable skill name. order=%s" % str(order))
		return
	if str(order.get("agent_name", "")) != "Chuck":
		_fail("Forge work order did not keep the readable harness agent. order=%s" % str(order))
		return
	if str(order.get("forge_run_id", "")).strip_edges() == "":
		_fail("Forge work order did not keep its run id. order=%s" % str(order))
		return
	var target_tile: Vector2i = order.get("target_tile", Vector2i(-1, -1))
	if not scene.call("_can_target_crew_order", "clear_brush", target_tile):
		_fail("Forge work order target was not a valid clear_brush tile. order=%s" % str(order))
		return

	var rows: Dictionary = game_ui.get("_work_order_rows")
	if not rows.has(order_id):
		_fail("Forge work order did not appear in the crew order rows. rows=%s" % str(rows.keys()))
		return
	var row: Dictionary = rows.get(order_id, {})
	var preference := row.get("preference", null) as Label
	if preference == null or not preference.visible or str(preference.text) != "Forge":
		_fail("Forge work order row did not show the Forge context chip. text=%s visible=%s" % [
			str(preference.text) if preference != null else "",
			preference.visible if preference != null else false
		])
		return
	if not str(preference.tooltip_text).contains("Clear Patch"):
		_fail("Forge work order chip tooltip did not name the skill. tooltip=%s" % str(preference.tooltip_text))
		return
	if not str(preference.tooltip_text).contains("Run Ref: run %s" % str(order.get("forge_run_id", ""))) or not str(preference.tooltip_text).contains("order %s" % order_id):
		_fail("Forge work order chip tooltip did not preserve run/order identity. tooltip=%s order=%s" % [str(preference.tooltip_text), str(order)])
		return
	if not str(preference.tooltip_text).contains("Run Context: agent Chuck | target ") or not str(preference.tooltip_text).contains("| source Starter Lab"):
		_fail("Forge work order chip tooltip did not preserve readable run context. tooltip=%s" % str(preference.tooltip_text))
		return
	if not str(preference.tooltip_text).contains("Directive: work_order_directive"):
		_fail("Forge work order chip tooltip did not expose the structured directive kind. tooltip=%s" % str(preference.tooltip_text))
		return
	if not str(preference.tooltip_text).contains("Tool: clear_brush"):
		_fail("Forge work order chip tooltip did not expose the selected tool call. tooltip=%s" % str(preference.tooltip_text))
		return
	if not str(preference.tooltip_text).contains("Stage: Work Order Ready"):
		_fail("Forge work order chip tooltip did not expose the ready stage. tooltip=%s" % str(preference.tooltip_text))
		return
	if not str(preference.tooltip_text).contains("Current Run Detail: Work Order Ready -> Clear Patch"):
		_fail("Forge work order chip tooltip did not expose the ready current detail. tooltip=%s" % str(preference.tooltip_text))
		return
	if not str(preference.tooltip_text).contains("Run Route: Spec > Crew Order"):
		_fail("Forge work order chip tooltip did not expose the ready route. tooltip=%s" % str(preference.tooltip_text))
		return
	if not str(preference.tooltip_text).contains("Next Step: Send crew order"):
		_fail("Forge work order chip tooltip did not expose the ready next step. tooltip=%s" % str(preference.tooltip_text))
		return
	if _visible_next_text(game_ui) != "Next Step: Send crew order":
		_fail("Forge drafted order did not expose the send-order next step. text=%s" % _visible_next_text(game_ui))
		return
	if not _visible_detail_text(game_ui).begins_with("Run Context: agent Chuck | target ") or not _visible_detail_text(game_ui).contains("| source Starter Lab"):
		_fail("Forge drafted order did not expose readable run context. text=%s" % _visible_detail_text(game_ui))
		return
	if not _visible_receipt_text(game_ui).begins_with("Run Receipt: ") or not _visible_receipt_text(game_ui).contains("manual harness receipt confirmed clear-patch checks"):
		_fail("Forge drafted order did not expose compact receipt detail. text=%s" % _visible_receipt_text(game_ui))
		return
	if _visible_drift_text(game_ui) != "":
		_fail("Forge drafted order should keep Drift hidden for steady runs. text=%s" % _visible_drift_text(game_ui))
		return

	var field_log_entries: Array = game_ui.get("_field_log_entries")
	if not _entries_contain(field_log_entries, "Forge order drafted: Clear Patch"):
		_fail("Forge work order draft did not leave a Field Log receipt. entries=%s" % str(field_log_entries))
		return

	var events: Array = scene.get_node("GameEventLog").call("get_recent_events", 10)
	if not _work_order_event_exists(events, order_id, "forge_drafted"):
		_fail("Forge work order draft did not record a work_order event. events=%s" % str(events))
		return


func _test_tend_crops_stays_receipt_only(scene: Node, game_ui) -> void:
	_select_template(game_ui, "tend_crops_starter")
	if _failed:
		return

	var before_count := _forge_order_count(scene)
	var run_button = game_ui.get("_skill_forge_run_button") as Button
	run_button.pressed.emit()
	await process_frame

	if _forge_order_count(scene) != before_count:
		_fail("Tend Crops should stay receipt-only until a farm work order exists. before=%s after=%s" % [before_count, _forge_order_count(scene)])
		return

	var field_log_entries: Array = game_ui.get("_field_log_entries")
	if not _entries_contain(field_log_entries, "Skill Forge passed Tend Crops"):
		_fail("Tend Crops receipt-only run did not still pass. entries=%s" % str(field_log_entries))
		return

	var result_label = game_ui.get("_skill_forge_result_label") as Label
	var result_tooltip := str(result_label.tooltip_text) if result_label != null else ""
	if result_label == null or not result_tooltip.contains("Stage: Forge Receipt"):
		_fail("Tend Crops result tooltip did not expose the Forge-only receipt stage. tooltip=%s" % result_tooltip)
		return
	if not result_tooltip.contains("Run Trace: Spec > Directive > Forge Receipt"):
		_fail("Tend Crops result tooltip did not expose the Forge-only trace path. tooltip=%s" % result_tooltip)
		return
	if not result_tooltip.contains("Run Receipt: manual harness receipt confirmed crop-tending checks"):
		_fail("Tend Crops result tooltip did not expose labeled receipt detail. tooltip=%s" % result_tooltip)
		return

	var trace_label = game_ui.get("_skill_forge_trace_label") as Label
	if trace_label == null or str(trace_label.text) != "Run Trace: Spec > Directive > Forge Receipt":
		_fail("Tend Crops did not show a Forge-only receipt trace. text=%s" % (trace_label.text if trace_label else ""))
		return
	var trace_tooltip := str(trace_label.tooltip_text)
	if not trace_tooltip.contains("Run Route Note: receipt-only until this action has a crew-order path"):
		_fail("Tend Crops trace did not explain why no crew order was drafted. tooltip=%s" % trace_tooltip)
		return
	if not trace_tooltip.contains("Stage: Forge Receipt"):
		_fail("Tend Crops trace did not expose the Forge-only receipt stage. tooltip=%s" % trace_tooltip)
		return
	if not trace_tooltip.contains("Run Trace: Spec > Directive > Forge Receipt"):
		_fail("Tend Crops trace did not expose the labeled run trace path. tooltip=%s" % trace_tooltip)
		return
	if not trace_tooltip.contains("Run Receipt: manual harness receipt confirmed crop-tending checks"):
		_fail("Tend Crops trace did not expose labeled receipt detail. tooltip=%s" % trace_tooltip)
		return
	if not trace_tooltip.contains("Passed Tend Crops (Forge Receipt)") or not trace_tooltip.contains("Passed Clear Patch (Harness Receipt)"):
		_fail("Tend Crops trace history did not name Forge/harness receipt endpoints. tooltip=%s" % trace_tooltip)
		return
	if not trace_tooltip.contains("Run Context: agent Marigold | target ") or not trace_tooltip.contains("| source Starter Lab"):
		_fail("Tend Crops trace did not preserve agent/target/source context. tooltip=%s" % trace_tooltip)
		return
	if _visible_stage_text(game_ui) != "Stage: Forge Receipt | Tend Crops":
		_fail("Tend Crops did not expose the Forge-only current stage line. text=%s" % _visible_stage_text(game_ui))
		return
	if _visible_next_text(game_ui) != "Next Step: Field Log receipt":
		_fail("Tend Crops did not expose the Forge-only next step. text=%s" % _visible_next_text(game_ui))
		return
	if not _visible_detail_text(game_ui).begins_with("Run Context: agent Marigold | target ") or not _visible_detail_text(game_ui).contains("| source Starter Lab"):
		_fail("Tend Crops did not expose readable run context. text=%s" % _visible_detail_text(game_ui))
		return
	if not _visible_receipt_text(game_ui).begins_with("Run Receipt: ") or not _visible_receipt_text(game_ui).contains("manual harness receipt confirmed crop-tending checks"):
		_fail("Tend Crops did not expose compact receipt detail. text=%s" % _visible_receipt_text(game_ui))
		return
	if _visible_drift_text(game_ui) != "":
		_fail("Tend Crops should keep Drift hidden for steady runs. text=%s" % _visible_drift_text(game_ui))
		return


func _test_clear_patch_order_blocked_trace() -> void:
	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	root.size = Vector2i(1600, 900)
	await process_frame
	await process_frame

	var game_ui = scene.get_node("GameUI")
	_select_template(game_ui, "clear_patch_starter")
	if _failed:
		return

	var request: Dictionary = scene.call("_skill_forge_request_for_template", "clear_patch_starter")
	var target_tile: Vector2i = request.get("target_tile", Vector2i(-1, -1))
	if target_tile == Vector2i(-1, -1) or not scene.call("_can_target_crew_order", "clear_brush", target_tile):
		_fail("Clear Patch smoke could not find an initial clear_brush target. request=%s" % str(request))
		return

	var tile = scene.get_node("FarmWorld/GridManager").get_tile(target_tile)
	if tile == null:
		_fail("Clear Patch order-blocked smoke target tile was missing.")
		return
	tile.set_terrain("grass")
	if scene.call("_can_target_crew_order", "clear_brush", target_tile):
		_fail("Clear Patch target stayed valid after being cleared. target=%s tile=%s" % [str(target_tile), str(tile)])
		return

	var templates = scene.get("_skill_forge_templates")
	var harness = scene.get("_skill_forge_run_harness")
	if templates == null or harness == null:
		_fail("Skill Forge internals were missing for order-blocked smoke.")
		return

	var spec: Dictionary = templates.get_template_spec("clear_patch_starter")
	var start_result: Dictionary = harness.start_manual_run(spec, request)
	scene.call("_apply_skill_forge_result", start_result)
	await process_frame

	if _forge_order_count(scene) != 0:
		_fail("Order-blocked Clear Patch should not draft a Forge work order. count=%s" % _forge_order_count(scene))
		return

	var field_log_entries: Array = game_ui.get("_field_log_entries")
	if not _entries_contain(field_log_entries, "Forge order blocked: target changed for Clear Patch."):
		_fail("Order-blocked Clear Patch did not leave a Field Log reason. entries=%s" % str(field_log_entries))
		return

	var trace_label = game_ui.get("_skill_forge_trace_label") as Label
	if trace_label == null or str(trace_label.text) != "Run Trace: Spec > Directive > Order Blocked":
		_fail("Order-blocked Clear Patch did not show the blocked trace. text=%s" % (trace_label.text if trace_label else ""))
		return
	var trace_tooltip := str(trace_label.tooltip_text)
	if not trace_tooltip.contains("Order Blocked: target changed") or not trace_tooltip.contains("clear_brush") or not trace_tooltip.contains("Clear Patch"):
		_fail("Order-blocked trace did not explain the blocked directive. tooltip=%s" % trace_tooltip)
		return
	if not trace_tooltip.contains("Run History: Order Blocked Clear Patch"):
		_fail("Order-blocked trace history did not name the blocked-order endpoint. tooltip=%s" % trace_tooltip)
		return
	if not trace_tooltip.contains("Stage: Order Blocked"):
		_fail("Order-blocked trace did not expose the order-blocked stage. tooltip=%s" % trace_tooltip)
		return
	if not trace_tooltip.contains("Run Route: Spec > Order Blocked"):
		_fail("Order-blocked trace did not expose the blocked route. tooltip=%s" % trace_tooltip)
		return
	if not trace_tooltip.contains("Run Trace: Spec > Directive > Order Blocked"):
		_fail("Order-blocked trace did not expose the labeled run trace path. tooltip=%s" % trace_tooltip)
		return
	if not trace_tooltip.contains("Directive: work_order_directive") or not trace_tooltip.contains("Tool: clear_brush"):
		_fail("Order-blocked trace did not expose labeled directive/tool detail. tooltip=%s" % trace_tooltip)
		return
	if not trace_tooltip.contains("Next Step: Pick valid target"):
		_fail("Order-blocked trace did not expose the target-repair next step. tooltip=%s" % trace_tooltip)
		return
	if not trace_tooltip.contains("Run Context: agent Chuck | target ") or not trace_tooltip.contains("| source Starter Lab"):
		_fail("Order-blocked trace did not expose labeled run context. tooltip=%s" % trace_tooltip)
		return

	var result_label = game_ui.get("_skill_forge_result_label") as Label
	if result_label == null or not str(result_label.text).contains("Order Blocked"):
		_fail("Order-blocked Clear Patch did not update the result label. text=%s" % (result_label.text if result_label else ""))
		return
	var result_tooltip := str(result_label.tooltip_text)
	if not result_tooltip.contains("Order Blocked: target changed") or not result_tooltip.contains("Clear Patch"):
		_fail("Order-blocked result tooltip did not keep the blocked-order detail. tooltip=%s" % result_tooltip)
		return
	if not result_tooltip.contains("Stage: Order Blocked"):
		_fail("Order-blocked result tooltip did not expose the order-blocked stage. tooltip=%s" % result_tooltip)
		return
	if not result_tooltip.contains("Run Route: Spec > Order Blocked"):
		_fail("Order-blocked result tooltip did not expose the blocked route. tooltip=%s" % result_tooltip)
		return
	if not result_tooltip.contains("Run Trace: Spec > Directive > Order Blocked"):
		_fail("Order-blocked result tooltip did not expose the blocked-order trace path. tooltip=%s" % result_tooltip)
		return
	if not result_tooltip.contains("Next Step: Pick valid target"):
		_fail("Order-blocked result tooltip did not expose the target-repair next step. tooltip=%s" % result_tooltip)
		return
	if not result_tooltip.contains("Run History: Order Blocked Clear Patch"):
		_fail("Order-blocked result tooltip did not keep the blocked-order history endpoint. tooltip=%s" % result_tooltip)
		return
	if not result_tooltip.contains("Run Ref: run forge_run_"):
		_fail("Order-blocked result tooltip did not expose compact run identity. tooltip=%s" % result_tooltip)
		return
	if _visible_stage_text(game_ui) != "Stage: Order Blocked | Clear Patch":
		_fail("Order-blocked Clear Patch did not expose the blocked current stage line. text=%s" % _visible_stage_text(game_ui))
		return
	if _visible_next_text(game_ui) != "Next Step: Pick valid target":
		_fail("Order-blocked Clear Patch did not expose the target-repair next step. text=%s" % _visible_next_text(game_ui))
		return
	if not _visible_detail_text(game_ui).begins_with("Run Context: agent Chuck | target ") or not _visible_detail_text(game_ui).contains("| source Starter Lab"):
		_fail("Order-blocked Clear Patch did not expose readable run context. text=%s" % _visible_detail_text(game_ui))
		return
	if not _visible_receipt_text(game_ui).begins_with("Run Receipt: ") or not _visible_receipt_text(game_ui).contains("target changed"):
		_fail("Order-blocked Clear Patch did not expose compact receipt detail. text=%s" % _visible_receipt_text(game_ui))
		return
	if _visible_drift_text(game_ui) != "":
		_fail("Order-blocked Clear Patch should not show spec Drift for a target change. text=%s" % _visible_drift_text(game_ui))
		return

	scene.queue_free()
	await process_frame


func _select_template(game_ui, template_id: String) -> void:
	var buttons_value = game_ui.get("_skill_forge_template_buttons")
	if typeof(buttons_value) != TYPE_DICTIONARY:
		_fail("Skill Forge panel did not expose template buttons.")
		return
	var buttons: Dictionary = buttons_value
	var button = buttons.get(template_id, null) as Button
	if button == null:
		_fail("Skill Forge template button missing for %s." % template_id)
		return
	button.pressed.emit()


func _forge_order_count(scene: Node) -> int:
	var count := 0
	for order_id in scene.work_order_ids:
		var order: Dictionary = scene.work_orders.get(str(order_id), {})
		if str(order.get("source", "")) == "skill_forge":
			count += 1
	return count


func _latest_forge_order_id(scene: Node, skill_id: String) -> String:
	for index in range(scene.work_order_ids.size() - 1, -1, -1):
		var order_id := str(scene.work_order_ids[index])
		var order: Dictionary = scene.work_orders.get(order_id, {})
		if str(order.get("source", "")) == "skill_forge" and str(order.get("skill_id", "")) == skill_id:
			return order_id
	return ""


func _entries_contain(entries: Array, needle: String) -> bool:
	for entry in entries:
		if str(entry).contains(needle):
			return true
	return false


func _work_order_event_exists(events: Array, order_id: String, status: String) -> bool:
	for event in events:
		if str(event.get("type", "")) != "work_order":
			continue
		if str(event.get("order_id", "")) == order_id and str(event.get("status", "")) == status:
			return true
	return false


func _visible_stage_text(game_ui) -> String:
	var stage_label = game_ui.get("_skill_forge_stage_label") as Label
	if stage_label == null or not stage_label.visible:
		return ""
	return str(stage_label.text)


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


func _fail(message: String) -> void:
	_failed = true
	push_error(message)
	quit(1)
