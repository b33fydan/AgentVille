extends SceneTree

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_clear_patch_completion_reaches_world_check()
	if _failed:
		return
	await _test_harvest_crops_completion_reaches_world_check()
	if _failed:
		return
	await _test_plant_seed_completion_reaches_world_check()
	if _failed:
		return
	await _test_tend_crops_completion_reaches_world_check()
	if _failed:
		return
	await _test_build_fence_completion_reaches_world_check()
	if _failed:
		return
	await _test_forge_waiting_order_traces_busy_crew()
	if not _failed:
		quit()


func _test_clear_patch_completion_reaches_world_check() -> void:
	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	root.size = Vector2i(1600, 900)
	await process_frame
	await process_frame

	var game_ui = scene.get_node("GameUI")
	_select_template(game_ui, "clear_patch_starter")
	if _failed:
		return

	var run_button = game_ui.get("_skill_forge_run_button") as Button
	if run_button == null:
		_fail("Skill Forge run button missing before Clear Patch world-check smoke.")
		return
	run_button.pressed.emit()
	await process_frame

	var order_id := _latest_forge_order_id(scene, "clear_patch_starter")
	if order_id == "" or not scene.work_orders.has(order_id):
		_fail("Clear Patch did not draft a Forge work order for world-check smoke.")
		return
	var order: Dictionary = scene.work_orders[order_id]
	var target_tile: Vector2i = order.get("target_tile", Vector2i(-1, -1))
	var tile = scene.get_node("FarmWorld/GridManager").get_tile(target_tile)
	if tile == null:
		_fail("Forge work-order target tile was missing.")
		return
	if not await _assert_world_check_completion(scene, game_ui, order_id, "Clear Patch", "Expected no decor"):
		return
	scene.queue_free()
	await process_frame
	return


func _test_harvest_crops_completion_reaches_world_check() -> void:
	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	root.size = Vector2i(1600, 900)
	await process_frame
	await process_frame

	var game_ui = scene.get_node("GameUI")
	_select_template(game_ui, "harvest_crops_starter")
	if _failed:
		return

	var run_button = game_ui.get("_skill_forge_run_button") as Button
	if run_button == null:
		_fail("Skill Forge run button missing before Harvest Crops world-check smoke.")
		return
	run_button.pressed.emit()
	await process_frame

	var order_id := _latest_forge_order_id(scene, "harvest_crops_starter")
	if order_id == "" or not scene.work_orders.has(order_id):
		_fail("Harvest Crops did not draft a Forge work order for world-check smoke.")
		return
	var order: Dictionary = scene.work_orders[order_id]
	var target_tile: Vector2i = order.get("target_tile", Vector2i(-1, -1))
	var tile = scene.get_node("FarmWorld/GridManager").get_tile(target_tile)
	if tile == null or tile.crop == null or not tile.crop.is_ready():
		_fail("Harvest Crops did not target a ready crop. order=%s" % str(order))
		return
	if not await _assert_world_check_completion(scene, game_ui, order_id, "Harvest Crops", "observed +1 grain"):
		return
	scene.queue_free()
	await process_frame
	return


func _test_build_fence_completion_reaches_world_check() -> void:
	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	root.size = Vector2i(1600, 900)
	await process_frame
	await process_frame

	var game_ui = scene.get_node("GameUI")
	_select_template(game_ui, "build_fence_starter")
	if _failed:
		return

	var run_button = game_ui.get("_skill_forge_run_button") as Button
	if run_button == null:
		_fail("Skill Forge run button missing before Build Fence world-check smoke.")
		return
	run_button.pressed.emit()
	await process_frame

	var order_id := _latest_forge_order_id(scene, "build_fence_starter")
	if order_id == "" or not scene.work_orders.has(order_id):
		_fail("Build Fence did not draft a Forge work order for world-check smoke.")
		return
	var order: Dictionary = scene.work_orders[order_id]
	var target_tile: Vector2i = order.get("target_tile", Vector2i(-1, -1))
	var tile = scene.get_node("FarmWorld/GridManager").get_tile(target_tile)
	if tile == null or not tile.can_apply_item("fence"):
		_fail("Build Fence did not target an open fence tile. order=%s" % str(order))
		return

	scene.call("_add_resources", {
		"fiber": 2,
		"grain": 1
	})
	if not await _assert_world_check_completion(scene, game_ui, order_id, "Build Fence", "observed decor fence"):
		return
	scene.queue_free()
	await process_frame
	return


func _test_plant_seed_completion_reaches_world_check() -> void:
	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	root.size = Vector2i(1600, 900)
	await process_frame
	await process_frame

	var game_ui = scene.get_node("GameUI")
	_select_template(game_ui, "plant_seed_starter")
	if _failed:
		return

	var run_button = game_ui.get("_skill_forge_run_button") as Button
	if run_button == null:
		_fail("Skill Forge run button missing before Plant Seed world-check smoke.")
		return
	run_button.pressed.emit()
	await process_frame

	var order_id := _latest_forge_order_id(scene, "plant_seed_starter")
	if order_id == "" or not scene.work_orders.has(order_id):
		_fail("Plant Seed did not draft a Forge work order for world-check smoke.")
		return
	var order: Dictionary = scene.work_orders[order_id]
	var target_tile: Vector2i = order.get("target_tile", Vector2i(-1, -1))
	var tile = scene.get_node("FarmWorld/GridManager").get_tile(target_tile)
	if tile == null or not scene.call("_can_target_crew_order", "plant_seed", target_tile):
		_fail("Plant Seed did not target an open planting tile. order=%s" % str(order))
		return
	if not await _assert_world_check_completion(scene, game_ui, order_id, "Plant Seed", "Expected a newly planted crop"):
		return
	scene.queue_free()
	await process_frame
	return


func _test_tend_crops_completion_reaches_world_check() -> void:
	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	root.size = Vector2i(1600, 900)
	await process_frame
	await process_frame

	var game_ui = scene.get_node("GameUI")
	_select_template(game_ui, "tend_crops_starter")
	if _failed:
		return

	var run_button = game_ui.get("_skill_forge_run_button") as Button
	if run_button == null:
		_fail("Skill Forge run button missing before Tend Crops world-check smoke.")
		return
	run_button.pressed.emit()
	await process_frame

	var order_id := _latest_forge_order_id(scene, "tend_crops_starter")
	if order_id == "" or not scene.work_orders.has(order_id):
		_fail("Tend Crops did not draft a Forge work order for world-check smoke.")
		return
	var order: Dictionary = scene.work_orders[order_id]
	var target_tile: Vector2i = order.get("target_tile", Vector2i(-1, -1))
	var tile = scene.get_node("FarmWorld/GridManager").get_tile(target_tile)
	if tile == null or tile.crop == null or tile.crop.is_ready():
		_fail("Tend Crops did not target a growing crop. order=%s" % str(order))
		return
	var starting_stage := int(tile.crop.stage)
	if not await _assert_world_check_completion(scene, game_ui, order_id, "Tend Crops", "growth stage to increase"):
		return
	if tile.crop == null or int(tile.crop.stage) <= starting_stage:
		_fail("Tend Crops world check passed without a real growth-stage increase.")
		return
	scene.queue_free()
	await process_frame
	return


func _test_forge_waiting_order_traces_busy_crew() -> void:
	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	root.size = Vector2i(1600, 900)
	await process_frame
	await process_frame

	var game_ui = scene.get_node("GameUI")
	_select_template(game_ui, "clear_patch_starter")
	if _failed:
		return

	var run_button = game_ui.get("_skill_forge_run_button") as Button
	if run_button == null:
		_fail("Skill Forge run button missing before waiting trace smoke.")
		return
	run_button.pressed.emit()
	await process_frame

	var order_id := _latest_forge_order_id(scene, "clear_patch_starter")
	if order_id == "" or not scene.work_orders.has(order_id):
		_fail("Clear Patch did not draft a Forge work order for waiting trace smoke.")
		return

	var agent_manager = scene.get_node("FarmWorld/AgentManager")
	agent_manager.agents.clear()
	scene.call("_on_work_order_requested", order_id)
	await process_frame

	var order: Dictionary = scene.work_orders.get(order_id, {})
	if str(order.get("status", "")) != "waiting" or str(order.get("status_text", "")) != "Waiting crew":
		_fail("Forge work order did not enter waiting state with busy crew. order=%s" % str(order))
		return
	var honest_waiting_trace = game_ui.get("_skill_forge_trace_label") as Label
	if honest_waiting_trace == null or str(honest_waiting_trace.text) != "Run Trace: Spec > Directive > Work Order > Crew Waiting":
		_fail("Waiting Forge run did not expose Crew Waiting. text=%s" % (honest_waiting_trace.text if honest_waiting_trace else ""))
		return
	var honest_waiting_tooltip := str(honest_waiting_trace.tooltip_text)
	if _result_text(game_ui) != "Crew Waiting: Clear Patch" or not honest_waiting_tooltip.contains("Run Context: agent Chuck") or not honest_waiting_tooltip.contains("source Starter Lab"):
		_fail("Waiting Forge run lost its lifecycle header or authored context. tooltip=%s" % honest_waiting_tooltip)
		return
	if _visible_next_text(game_ui) != "Next Step: Wait for free crew" or not _work_order_chip_tooltip(game_ui, order_id).contains("Stage: Crew Waiting"):
		_fail("Waiting Forge run lost its actionable next step or work-order chip stage.")
		return
	if _entries_contain(game_ui.get("_field_log_entries"), "Skill Forge passed Clear Patch") or scene.get("_pending_skill_forge_run").is_empty():
		_fail("Waiting Forge run fabricated completion or lost its pending verifier.")
		return
	scene.queue_free()
	await process_frame
	return


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


func _latest_forge_order_id(scene: Node, skill_id: String) -> String:
	for index in range(scene.work_order_ids.size() - 1, -1, -1):
		var order_id := str(scene.work_order_ids[index])
		var order: Dictionary = scene.work_orders.get(order_id, {})
		if str(order.get("source", "")) == "skill_forge" and str(order.get("skill_id", "")) == skill_id:
			return order_id
	return ""


func _active_agent_badge_text(scene: Node) -> String:
	var agent_manager = scene.get_node("FarmWorld/AgentManager")
	for agent in agent_manager.agents:
		if str(agent.state.get("current_action", "idle")) == "idle":
			continue
		var badge = agent.get_node_or_null("VoxelRig/ReasonBadge")
		if badge != null and badge.visible:
			return str(badge.text)
	return ""


func _work_order_chip_tooltip(game_ui, order_id: String) -> String:
	var rows: Dictionary = game_ui.get("_work_order_rows")
	var row: Dictionary = rows.get(order_id, {})
	var preference = row.get("preference", null) as Label
	return str(preference.tooltip_text) if preference != null else ""


func _result_text(game_ui) -> String:
	var result_label = game_ui.get("_skill_forge_result_label") as Label
	return str(result_label.text) if result_label != null else ""


func _result_tooltip(game_ui) -> String:
	var result_label = game_ui.get("_skill_forge_result_label") as Label
	return str(result_label.tooltip_text) if result_label != null else ""


func _lesson_text(game_ui) -> String:
	var lesson_label = game_ui.get("_skill_forge_lesson_label") as Label
	return str(lesson_label.text) if lesson_label != null else ""


func _visible_history_text(game_ui) -> String:
	var history_label = game_ui.get("_skill_forge_history_label") as Label
	if history_label == null or not history_label.visible:
		return ""
	return str(history_label.text)


func _history_tooltip(game_ui) -> String:
	var history_label = game_ui.get("_skill_forge_history_label") as Label
	return str(history_label.tooltip_text) if history_label != null else ""


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


func _completed_forge_world_action(scene: Node, order: Dictionary) -> Dictionary:
	var forge_run_id := str(order.get("forge_run_id", ""))
	for event in scene.get_node("GameEventLog").get("events"):
		if typeof(event) != TYPE_DICTIONARY:
			continue
		if str(event.get("type", "")) != "agent_world_action":
			continue
		if not bool(event.get("success", false)):
			continue
		if str(event.get("work_order_id", "")) != str(order.get("id", "")):
			continue
		if str(event.get("forge_run_id", "")) == forge_run_id:
			return event
	return {}


func _assert_world_check_completion(scene: Node, game_ui, order_id: String, skill_name: String, detail_fragment: String) -> bool:
	var starting_order: Dictionary = scene.work_orders.get(order_id, {}).duplicate(true)
	var agent_manager = scene.get_node("FarmWorld/AgentManager")
	for agent in agent_manager.agents:
		agent.move_speed = 60.0
	scene.call("_on_work_order_requested", order_id)
	for _frame in range(240):
		if scene.get("_pending_skill_forge_run").is_empty():
			break
		await process_frame
	if not scene.get("_pending_skill_forge_run").is_empty():
		_fail("%s did not reach a terminal world check." % skill_name)
		return false
	if str(scene.work_orders.get(order_id, {}).get("status", "")) != "done":
		_fail("%s world check did not correlate to a done order." % skill_name)
		return false
	if _result_text(game_ui) != "Passed: %s" % skill_name:
		_fail("%s did not expose a passing verified result. text=%s" % [skill_name, _result_text(game_ui)])
		return false
	var trace_label = game_ui.get("_skill_forge_trace_label") as Label
	if trace_label == null or str(trace_label.text) != "Run Trace: Spec > Directive > Work Order > World Check":
		_fail("%s did not end at the World Check trace. text=%s" % [skill_name, trace_label.text if trace_label else ""])
		return false
	if _visible_stage_text(game_ui) != "Stage: World Check | %s" % skill_name:
		_fail("%s did not expose the World Check stage. text=%s" % [skill_name, _visible_stage_text(game_ui)])
		return false
	if not _visible_receipt_text(game_ui).contains(detail_fragment):
		_fail("%s did not expose its observed-versus-expected result. receipt=%s" % [skill_name, _visible_receipt_text(game_ui)])
		return false
	if not _entries_contain(game_ui.get("_field_log_entries"), "Skill Forge passed %s" % skill_name):
		_fail("%s did not write a passing world-check receipt." % skill_name)
		return false
	var completed_event := _completed_forge_world_action(scene, starting_order)
	if completed_event.is_empty() or str(completed_event.get("skill_name", "")) != skill_name:
		_fail("%s world check lost its correlated Forge action event." % skill_name)
		return false
	if str(completed_event.get("agent_id", "")) != str(starting_order.get("agent_id", "")):
		_fail("%s executed on the wrong named agent. event=%s order=%s" % [skill_name, str(completed_event), str(starting_order)])
		return false
	if str(completed_event.get("social_preference_source", "")) == "skill_forge":
		_fail("%s leaked Forge work into social-preference context." % skill_name)
		return false
	var agent_receipt := str(scene.call("_format_agent_receipt", completed_event))
	if not agent_receipt.contains("[Forge: %s]" % skill_name):
		_fail("%s agent receipt lost readable Forge context. receipt=%s" % [skill_name, agent_receipt])
		return false
	var result_tooltip := _result_tooltip(game_ui)
	if not result_tooltip.contains("Stage: World Check") or not result_tooltip.contains("Run Route: Spec > Crew Order > World Check") or not _visible_detail_text(game_ui).contains("agent %s" % str(starting_order.get("agent_name", ""))):
		_fail("%s terminal tooltip lost World Check route/context. tooltip=%s" % [skill_name, result_tooltip])
		return false
	var history_text := _visible_history_text(game_ui)
	if not history_text.contains("Crew Queued") or not history_text.contains("Agent Receipt") or not history_text.contains("Passed (World Check) [current]"):
		_fail("%s visible run trail lost the honest queued/action/check sequence. text=%s" % [skill_name, history_text])
		return false
	var summary: Dictionary = scene.get_node("GameEventLog").call("build_day_summary", scene.get_node("FarmWorld/GridManager").day)
	if not _summary_has_forge_work(summary, str(starting_order.get("forge_run_id", "")), skill_name) or _summary_has_social_skill_forge(summary):
		_fail("%s day summary lost Forge work or misclassified it as social context. summary=%s" % [skill_name, str(summary)])
		return false
	return true


func _entries_contain(entries: Array, needle: String) -> bool:
	for entry in entries:
		if str(entry).contains(needle):
			return true
	return false


func _summary_has_forge_work(summary: Dictionary, forge_run_id: String, skill_name: String) -> bool:
	var forge_actions: Dictionary = summary.get("agent_skill_forge_actions", {})
	for receipt in forge_actions.values():
		if typeof(receipt) != TYPE_DICTIONARY:
			continue
		if str(receipt.get("run_id", "")) == forge_run_id and str(receipt.get("skill_name", "")) == skill_name:
			return true
	return false


func _summary_has_social_skill_forge(summary: Dictionary) -> bool:
	var social_actions: Dictionary = summary.get("agent_social_preference_actions", {})
	for receipt in social_actions.values():
		if typeof(receipt) == TYPE_DICTIONARY and str(receipt.get("last_source", "")) == "skill_forge":
			return true
	return false


func _fail(message: String) -> void:
	_failed = true
	push_error(message)
	quit(1)
