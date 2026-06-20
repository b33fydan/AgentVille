extends SceneTree

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_forge_order_completion_keeps_skill_context()
	if _failed:
		return
	await _test_harvest_crops_completion_reaches_agent_receipt()
	if _failed:
		return
	await _test_build_fence_completion_reaches_agent_receipt()
	if _failed:
		return
	await _test_forge_waiting_order_traces_busy_crew()
	if not _failed:
		quit()


func _test_forge_order_completion_keeps_skill_context() -> void:
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
		_fail("Skill Forge run button missing before work receipt smoke.")
		return
	run_button.pressed.emit()
	await process_frame

	var order_id := _latest_forge_order_id(scene, "clear_patch_starter")
	if order_id == "" or not scene.work_orders.has(order_id):
		_fail("Clear Patch did not draft a Forge work order for receipt smoke.")
		return
	var order: Dictionary = scene.work_orders[order_id]
	var target_tile: Vector2i = order.get("target_tile", Vector2i(-1, -1))
	var tile = scene.get_node("FarmWorld/GridManager").get_tile(target_tile)
	if tile == null:
		_fail("Forge work-order target tile was missing.")
		return

	var trace_label = game_ui.get("_skill_forge_trace_label") as Label
	if trace_label == null or str(trace_label.text) != "Run Trace: Spec > Directive > Work Order > Harness Receipt":
		_fail("Forge panel did not trace the drafted work order. text=%s" % (trace_label.text if trace_label else ""))
		return

	var agent_manager = scene.get_node("FarmWorld/AgentManager")
	for agent in agent_manager.agents:
		agent.move_speed = 42.0

	scene.call("_on_work_order_requested", order_id)
	await process_frame
	await process_frame

	var queued_field_log_entries: Array = game_ui.get("_field_log_entries")
	if not _entries_contain(queued_field_log_entries, "Work order queued:") or not _entries_contain(queued_field_log_entries, "[Forge: Clear Patch]"):
		_fail("Field Log did not include Forge context when the work order was queued. entries=%s" % str(queued_field_log_entries))
		return

	if trace_label == null or str(trace_label.text) != "Run Trace: Spec > Directive > Work Order > Crew Queued":
		_fail("Forge panel did not trace the queued crew work. text=%s" % (trace_label.text if trace_label else ""))
		return
	var queued_trace_tooltip := str(trace_label.tooltip_text)
	if not queued_trace_tooltip.contains("Forge order queued; awaiting agent receipt") or not queued_trace_tooltip.contains("Run Target: Clear Patch") or not queued_trace_tooltip.contains("Run Context: agent Chuck | target ") or not queued_trace_tooltip.contains("| source Starter Lab"):
		_fail("Forge queued-work trace did not preserve readable work context. tooltip=%s" % queued_trace_tooltip)
		return
	if not queued_trace_tooltip.contains("agent Chuck"):
		_fail("Forge queued-work trace did not preserve the readable harness agent. tooltip=%s order=%s" % [queued_trace_tooltip, str(order)])
		return
	if not queued_trace_tooltip.contains("Stage: Crew Queued"):
		_fail("Forge queued-work trace did not expose the crew-queued stage. tooltip=%s" % queued_trace_tooltip)
		return
	if not queued_trace_tooltip.contains("Run Ref: run %s" % str(order.get("forge_run_id", ""))) or not queued_trace_tooltip.contains("order %s" % order_id):
		_fail("Forge queued-work trace did not preserve run/order identity. tooltip=%s order=%s" % [queued_trace_tooltip, str(order)])
		return
	if not queued_trace_tooltip.contains("Passed Clear Patch"):
		_fail("Forge queued-work trace did not preserve recent receipt history. tooltip=%s" % queued_trace_tooltip)
		return
	if not queued_trace_tooltip.contains("Passed Clear Patch (Harness Receipt)"):
		_fail("Forge queued-work trace history did not name the harness receipt endpoint. tooltip=%s" % queued_trace_tooltip)
		return
	if not queued_trace_tooltip.contains("Crew Queued Clear Patch"):
		_fail("Forge queued-work trace did not remember the crew-queued stage. tooltip=%s" % queued_trace_tooltip)
		return
	if not queued_trace_tooltip.contains("Current Run Detail: Crew Queued -> Clear Patch"):
		_fail("Forge queued-work trace did not expose current run detail before history. tooltip=%s" % queued_trace_tooltip)
		return
	var queued_history_start := queued_trace_tooltip.find("Run History: Passed Clear Patch")
	var queued_history_stage_index := queued_trace_tooltip.find("Crew Queued Clear Patch", queued_history_start)
	if queued_history_start == -1 or queued_history_stage_index <= queued_history_start:
		_fail("Forge queued-work trace history was not chronological. tooltip=%s" % queued_trace_tooltip)
		return
	if not queued_trace_tooltip.contains("Next Step: Wait for agent receipt"):
		_fail("Forge queued-work trace did not expose the agent-receipt next step. tooltip=%s" % queued_trace_tooltip)
		return
	if not queued_trace_tooltip.contains("Lesson: Crew queued the work order; wait for agent receipt."):
		_fail("Forge queued-work trace did not expose the queued lesson cue. tooltip=%s" % queued_trace_tooltip)
		return
	if not queued_trace_tooltip.contains("Run Route: Spec > Crew Order > Crew Queued"):
		_fail("Forge queued-work trace did not expose the queued route. tooltip=%s" % queued_trace_tooltip)
		return
	if not queued_trace_tooltip.contains("Run Trace: Spec > Directive > Work Order > Crew Queued"):
		_fail("Forge queued-work trace did not expose the labeled run trace path. tooltip=%s" % queued_trace_tooltip)
		return
	if not queued_trace_tooltip.contains("Trace Scan: Crew order queued | Next agent receipt"):
		_fail("Forge queued-work trace did not expose the queued trace scan. tooltip=%s" % queued_trace_tooltip)
		return
	if not queued_trace_tooltip.contains("Run Receipt: Forge order queued; awaiting agent receipt: Clear Patch"):
		_fail("Forge queued-work trace did not expose labeled receipt detail. tooltip=%s" % queued_trace_tooltip)
		return
	if _result_text(game_ui) != "Crew Queued: Clear Patch":
		_fail("Forge queued-work header did not follow the crew lifecycle. text=%s" % _result_text(game_ui))
		return
	if not _result_tooltip(game_ui).contains("Stage: Crew Queued") or not _result_tooltip(game_ui).contains("Run Route: Spec > Crew Order > Crew Queued") or not _result_tooltip(game_ui).contains("Next Step: Wait for agent receipt") or not _result_tooltip(game_ui).contains("Forge order queued; awaiting agent receipt"):
		_fail("Forge queued-work header tooltip did not keep queue trace detail. tooltip=%s" % _result_tooltip(game_ui))
		return
	var queued_history_text := _visible_history_text(game_ui)
	if queued_history_text != "Run Trail: Clear Patch | Passed (Harness Receipt) > Crew Queued [current]":
		_fail("Forge queued-work visible Run Trail did not summarize the lifecycle. text=%s" % queued_history_text)
		return
	if not _history_tooltip(game_ui).contains("Current Run Detail: Crew Queued -> Clear Patch"):
		_fail("Forge queued-work history tooltip did not expose the current lifecycle detail. tooltip=%s" % _history_tooltip(game_ui))
		return
	if not _history_tooltip(game_ui).contains("Trace Scan: Crew order queued | Next agent receipt"):
		_fail("Forge queued-work history tooltip did not expose the current trace scan. tooltip=%s" % _history_tooltip(game_ui))
		return
	if not _history_tooltip(game_ui).contains("Next Step: Wait for agent receipt"):
		_fail("Forge queued-work history tooltip did not expose the current next step. tooltip=%s" % _history_tooltip(game_ui))
		return
	if not _history_tooltip(game_ui).contains("Run Receipt: Forge order queued; awaiting agent receipt: Clear Patch"):
		_fail("Forge queued-work history tooltip did not label the current receipt. tooltip=%s" % _history_tooltip(game_ui))
		return
	if not _history_tooltip(game_ui).contains("Lesson: Crew queued the work order; wait for agent receipt."):
		_fail("Forge queued-work history tooltip did not expose the current lifecycle lesson. tooltip=%s" % _history_tooltip(game_ui))
		return
	if _visible_stage_text(game_ui) != "Stage: Crew Queued | Clear Patch":
		_fail("Forge queued-work current stage did not expose the crew-queued state. text=%s" % _visible_stage_text(game_ui))
		return
	if _visible_route_text(game_ui) != "Run Route: Spec > Crew Order > Crew Queued":
		_fail("Forge queued-work did not expose the compact route line. text=%s" % _visible_route_text(game_ui))
		return
	if not _visible_ref_text(game_ui).begins_with("Run Ref: run %s" % str(order.get("forge_run_id", ""))) or not _visible_ref_text(game_ui).contains("| order %s" % order_id):
		_fail("Forge queued-work did not expose compact run/order refs. text=%s order=%s" % [_visible_ref_text(game_ui), str(order)])
		return
	if _visible_next_text(game_ui) != "Next Step: Wait for agent receipt":
		_fail("Forge queued-work next step did not point to waiting for the agent receipt. text=%s" % _visible_next_text(game_ui))
		return
	if _lesson_text(game_ui) != "Lesson Crew queued the work order; wait for agent receipt.":
		_fail("Forge queued-work did not teach the queued lifecycle state. text=%s" % _lesson_text(game_ui))
		return
	if not _visible_detail_text(game_ui).begins_with("Run Context: agent Chuck | target ") or not _visible_detail_text(game_ui).contains("| source Starter Lab"):
		_fail("Forge queued-work did not expose readable run context. text=%s" % _visible_detail_text(game_ui))
		return
	if not _visible_receipt_text(game_ui).begins_with("Run Receipt: ") or not _visible_receipt_text(game_ui).contains("Forge order queued; awaiting agent receipt"):
		_fail("Forge queued-work did not expose compact receipt detail. text=%s" % _visible_receipt_text(game_ui))
		return
	if _visible_drift_text(game_ui) != "":
		_fail("Forge queued-work should clear visible Drift. text=%s" % _visible_drift_text(game_ui))
		return
	var queued_chip_tooltip := _work_order_chip_tooltip(game_ui, order_id)
	if not queued_chip_tooltip.begins_with("Forge Work Order: Clear Patch"):
		_fail("Forge queued-work chip did not open with the work-order role. tooltip=%s" % queued_chip_tooltip)
		return
	if not queued_chip_tooltip.contains("Run Context: agent Chuck | target ") or not queued_chip_tooltip.contains("| source Starter Lab"):
		_fail("Forge work order chip did not expose queued run context. tooltip=%s" % queued_chip_tooltip)
		return
	if not queued_chip_tooltip.contains("Directive: work_order_directive"):
		_fail("Forge work order chip did not expose the queued directive kind. tooltip=%s" % queued_chip_tooltip)
		return
	if not queued_chip_tooltip.contains("Tool: clear_brush"):
		_fail("Forge work order chip did not expose the queued tool call. tooltip=%s" % queued_chip_tooltip)
		return
	if not queued_chip_tooltip.contains("Stage: Crew Queued"):
		_fail("Forge work order chip did not expose the crew-queued stage. tooltip=%s" % queued_chip_tooltip)
		return
	if not queued_chip_tooltip.contains("Current Run Detail: Crew Queued -> Clear Patch"):
		_fail("Forge work order chip did not expose the crew-queued current detail. tooltip=%s" % queued_chip_tooltip)
		return
	if not queued_chip_tooltip.contains("Trace Scan: Crew order queued | Next agent receipt"):
		_fail("Forge work order chip did not expose the crew-queued trace scan. tooltip=%s" % queued_chip_tooltip)
		return
	if not queued_chip_tooltip.contains("Run Route: Spec > Crew Order > Crew Queued"):
		_fail("Forge work order chip did not expose the crew-queued route. tooltip=%s" % queued_chip_tooltip)
		return
	if not queued_chip_tooltip.contains("Run Trace: Spec > Directive > Work Order > Crew Queued"):
		_fail("Forge work order chip did not expose the crew-queued run trace. tooltip=%s" % queued_chip_tooltip)
		return
	if not queued_chip_tooltip.contains("Next Step: Wait for agent receipt"):
		_fail("Forge work order chip did not expose the crew-queued next step. tooltip=%s" % queued_chip_tooltip)
		return
	if not queued_chip_tooltip.contains("Lesson: Crew queued the work order; wait for agent receipt."):
		_fail("Forge work order chip did not expose the crew-queued lesson cue. tooltip=%s" % queued_chip_tooltip)
		return
	if not queued_chip_tooltip.contains("Run Receipt: Forge order queued; awaiting agent receipt: Clear Patch"):
		_fail("Forge work order chip did not expose the crew-queued receipt cue. tooltip=%s" % queued_chip_tooltip)
		return

	if _active_agent_badge_text(scene) != "Forge":
		_fail("Assigned Forge work did not show a Forge reason badge. saw=%s" % _active_agent_badge_text(scene))
		return

	await create_timer(1.1).timeout
	if str(tile.decor_id) != "":
		_fail("Forge-authored clear_brush work did not clear the target.")
		return

	var completed_event: Dictionary = _completed_forge_world_action(scene, order)
	if completed_event.is_empty():
		_fail("Completed Forge work did not record a dedicated forge_run_id world action.")
		return
	if str(completed_event.get("skill_name", "")) != "Clear Patch":
		_fail("Completed Forge work did not keep the readable skill name. event=%s" % str(completed_event))
		return
	if str(completed_event.get("social_preference_source", "")) == "skill_forge":
		_fail("Forge work leaked into social-preference event context. event=%s" % str(completed_event))
		return

	var receipt := str(scene.call("_format_agent_receipt", completed_event))
	if not receipt.contains("[Forge: Clear Patch]"):
		_fail("Forge work receipt did not name the Forge skill. saw=%s" % receipt)
		return
	if receipt.contains("skill_forge") or receipt.contains("Skill Forge: Clear Patch"):
		_fail("Forge work receipt used raw or social-style Forge context. saw=%s" % receipt)
		return

	if trace_label == null or str(trace_label.text) != "Run Trace: Spec > Directive > Work Order > Agent Receipt":
		_fail("Forge panel did not trace through the agent receipt endpoint. text=%s" % (trace_label.text if trace_label else ""))
		return
	var trace_tooltip := str(trace_label.tooltip_text)
	if not trace_tooltip.contains(receipt):
		_fail("Forge trace tooltip did not preserve the readable agent receipt. tooltip=%s receipt=%s" % [trace_tooltip, receipt])
		return
	if not trace_tooltip.contains("Run Target: Clear Patch"):
		_fail("Forge agent receipt trace did not expose the labeled run target. tooltip=%s" % trace_tooltip)
		return
	if not trace_tooltip.contains("Stage: Agent Receipt"):
		_fail("Forge agent receipt trace did not expose the agent receipt stage. tooltip=%s" % trace_tooltip)
		return
	if not trace_tooltip.contains("Run Ref: run %s" % str(order.get("forge_run_id", ""))) or not trace_tooltip.contains("order %s" % order_id):
		_fail("Forge agent receipt trace did not preserve run/order identity. tooltip=%s order=%s" % [trace_tooltip, str(order)])
		return
	if not trace_tooltip.contains("Next Step: Review day summary"):
		_fail("Forge agent receipt trace did not expose the day-summary next step. tooltip=%s" % trace_tooltip)
		return
	if not trace_tooltip.contains("Lesson: Agent receipt closed the crew work order."):
		_fail("Forge agent receipt trace did not expose the agent-receipt lesson cue. tooltip=%s" % trace_tooltip)
		return
	if not trace_tooltip.contains("Run Route: Spec > Crew Order > Agent Receipt"):
		_fail("Forge agent receipt trace did not expose the agent-receipt route. tooltip=%s" % trace_tooltip)
		return
	if not trace_tooltip.contains("Run Trace: Spec > Directive > Work Order > Agent Receipt"):
		_fail("Forge agent receipt trace did not expose the labeled run trace path. tooltip=%s" % trace_tooltip)
		return
	if not trace_tooltip.contains("Trace Scan: Agent receipt logged | Next day summary"):
		_fail("Forge agent receipt trace did not expose the agent-receipt trace scan. tooltip=%s" % trace_tooltip)
		return
	if not trace_tooltip.contains("Run Receipt: %s" % receipt):
		_fail("Forge agent receipt trace did not expose labeled receipt detail. tooltip=%s receipt=%s" % [trace_tooltip, receipt])
		return
	var passed_history_index := trace_tooltip.find("Run History: Passed Clear Patch")
	var queued_history_index := trace_tooltip.find("Crew Queued Clear Patch", passed_history_index)
	var receipt_history_index := trace_tooltip.find("Agent Receipt Clear Patch", passed_history_index)
	if passed_history_index == -1 or queued_history_index <= passed_history_index or receipt_history_index <= queued_history_index:
		_fail("Forge trace tooltip did not keep chronological Forge receipt history. tooltip=%s" % trace_tooltip)
		return
	if not trace_tooltip.contains("Current Run Detail: Agent Receipt -> Clear Patch"):
		_fail("Forge trace tooltip did not expose current agent-receipt detail before history. tooltip=%s" % trace_tooltip)
		return
	if _result_text(game_ui) != "Agent Receipt: Clear Patch":
		_fail("Forge completed-work header did not show the agent receipt endpoint. text=%s" % _result_text(game_ui))
		return
	if not _result_tooltip(game_ui).contains("Stage: Agent Receipt") or not _result_tooltip(game_ui).contains("Run Route: Spec > Crew Order > Agent Receipt") or not _result_tooltip(game_ui).contains("Next Step: Review day summary") or not _result_tooltip(game_ui).contains(receipt):
		_fail("Forge completed-work header tooltip did not keep receipt trace detail. tooltip=%s" % _result_tooltip(game_ui))
		return
	if not trace_tooltip.contains("Passed Clear Patch (Harness Receipt)"):
		_fail("Forge trace tooltip did not keep the harness endpoint in recent history. tooltip=%s" % trace_tooltip)
		return
	if not trace_tooltip.contains("Crew Queued Clear Patch"):
		_fail("Forge trace tooltip did not keep the queued crew stage in recent history. tooltip=%s" % trace_tooltip)
		return
	var completed_history_text := _visible_history_text(game_ui)
	if completed_history_text != "Run Trail: Clear Patch | Passed (Harness Receipt) > Crew Queued > Agent Receipt [current]":
		_fail("Forge completed-work visible Run Trail did not summarize the lifecycle. text=%s" % completed_history_text)
		return
	if not _history_tooltip(game_ui).contains("Current Run Detail: Agent Receipt -> Clear Patch"):
		_fail("Forge completed-work history tooltip did not expose the current agent-receipt detail. tooltip=%s" % _history_tooltip(game_ui))
		return
	if not _history_tooltip(game_ui).contains("Trace Scan: Agent receipt logged | Next day summary"):
		_fail("Forge completed-work history tooltip did not expose the current trace scan. tooltip=%s" % _history_tooltip(game_ui))
		return
	if not _history_tooltip(game_ui).contains("Next Step: Review day summary"):
		_fail("Forge completed-work history tooltip did not expose the current next step. tooltip=%s" % _history_tooltip(game_ui))
		return
	if not _history_tooltip(game_ui).contains("Run Receipt: %s" % receipt):
		_fail("Forge completed-work history tooltip did not label the current receipt. tooltip=%s receipt=%s" % [_history_tooltip(game_ui), receipt])
		return
	if not _history_tooltip(game_ui).contains("Lesson: Agent receipt closed the crew work order."):
		_fail("Forge completed-work history tooltip did not expose the current agent-receipt lesson. tooltip=%s" % _history_tooltip(game_ui))
		return
	if _visible_stage_text(game_ui) != "Stage: Agent Receipt | Clear Patch":
		_fail("Forge completed-work current stage did not expose the agent receipt endpoint. text=%s" % _visible_stage_text(game_ui))
		return
	if _visible_route_text(game_ui) != "Run Route: Spec > Crew Order > Agent Receipt":
		_fail("Forge completed-work did not expose the compact route line. text=%s" % _visible_route_text(game_ui))
		return
	if not _visible_ref_text(game_ui).begins_with("Run Ref: run %s" % str(order.get("forge_run_id", ""))) or not _visible_ref_text(game_ui).contains("| order %s" % order_id):
		_fail("Forge completed-work did not expose compact run/order refs. text=%s order=%s" % [_visible_ref_text(game_ui), str(order)])
		return
	if _visible_next_text(game_ui) != "Next Step: Review day summary":
		_fail("Forge completed-work next step did not point to reviewing the day summary. text=%s" % _visible_next_text(game_ui))
		return
	if _lesson_text(game_ui) != "Lesson Agent receipt closed the crew work order.":
		_fail("Forge completed-work did not teach the agent-receipt lifecycle state. text=%s" % _lesson_text(game_ui))
		return
	var completed_agent := str(completed_event.get("agent_name", ""))
	var completed_target := "target %s,%s" % [target_tile.x, target_tile.y]
	if not _visible_detail_text(game_ui).begins_with("Run Context: agent %s | target " % completed_agent) or not _visible_detail_text(game_ui).contains("| source Starter Lab"):
		_fail("Forge completed-work did not expose readable run context. text=%s" % _visible_detail_text(game_ui))
		return
	if not _visible_receipt_text(game_ui).begins_with("Run Receipt: ") or not _visible_receipt_text(game_ui).contains("%s cleared" % completed_agent):
		_fail("Forge completed-work did not expose compact receipt detail. text=%s" % _visible_receipt_text(game_ui))
		return
	if _visible_drift_text(game_ui) != "":
		_fail("Forge completed-work should keep Drift hidden. text=%s" % _visible_drift_text(game_ui))
		return
	if not trace_tooltip.contains("Run Context: agent %s | %s" % [completed_agent, completed_target]) or not trace_tooltip.contains("| source Starter Lab"):
		_fail("Forge agent receipt trace did not preserve final agent/target/source context. tooltip=%s event=%s" % [trace_tooltip, str(completed_event)])
		return

	var summary: Dictionary = scene.get_node("GameEventLog").call("build_day_summary", scene.get_node("FarmWorld/GridManager").day)
	if not _summary_has_forge_work(summary, str(order.get("forge_run_id", "")), "Clear Patch"):
		_fail("Day summary did not keep Forge work context. summary=%s" % str(summary.get("agent_skill_forge_actions", {})))
		return
	if _summary_has_social_skill_forge(summary):
		_fail("Day summary counted Forge work as social preference work. summary=%s" % str(summary.get("agent_social_preference_actions", {})))
		return
	var formatted_summary := str(scene.call("_format_day_summary", summary))
	if not formatted_summary.contains("forge work") or not formatted_summary.contains("Clear Patch"):
		_fail("Formatted day summary did not include Forge work context. saw=%s" % formatted_summary)
		return
	if formatted_summary.contains("skill_forge"):
		_fail("Formatted day summary leaked raw Forge source. saw=%s" % formatted_summary)
		return

	scene.queue_free()
	await process_frame


func _test_harvest_crops_completion_reaches_agent_receipt() -> void:
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
		_fail("Skill Forge run button missing before Harvest Crops receipt smoke.")
		return
	run_button.pressed.emit()
	await process_frame

	var order_id := _latest_forge_order_id(scene, "harvest_crops_starter")
	if order_id == "" or not scene.work_orders.has(order_id):
		_fail("Harvest Crops did not draft a Forge work order for receipt smoke.")
		return
	var order: Dictionary = scene.work_orders[order_id]
	var target_tile: Vector2i = order.get("target_tile", Vector2i(-1, -1))
	var tile = scene.get_node("FarmWorld/GridManager").get_tile(target_tile)
	if tile == null or tile.crop == null or not tile.crop.is_ready():
		_fail("Harvest Crops did not target a ready crop. order=%s" % str(order))
		return

	var agent_manager = scene.get_node("FarmWorld/AgentManager")
	for agent in agent_manager.agents:
		agent.move_speed = 42.0

	scene.call("_on_work_order_requested", order_id)
	await process_frame
	await process_frame

	var trace_label = game_ui.get("_skill_forge_trace_label") as Label
	if trace_label == null or str(trace_label.text) != "Run Trace: Spec > Directive > Work Order > Crew Queued":
		_fail("Harvest Crops did not trace the queued crew work. text=%s" % (trace_label.text if trace_label else ""))
		return
	if _result_text(game_ui) != "Crew Queued: Harvest Crops":
		_fail("Harvest Crops queued header did not follow the crew lifecycle. text=%s" % _result_text(game_ui))
		return
	if not _visible_detail_text(game_ui).begins_with("Run Context: agent Bert | target ") or not _visible_detail_text(game_ui).contains("| source Starter Lab"):
		_fail("Harvest Crops queued state did not expose the Forge run context. text=%s" % _visible_detail_text(game_ui))
		return

	await create_timer(1.1).timeout
	if tile.crop != null:
		_fail("Harvest Crops Forge work did not harvest the ready crop.")
		return

	var completed_event: Dictionary = _completed_forge_world_action(scene, order)
	if completed_event.is_empty():
		_fail("Harvest Crops did not record a Forge-tagged harvest action.")
		return
	if str(completed_event.get("skill_name", "")) != "Harvest Crops":
		_fail("Harvest Crops completed work did not keep the readable skill name. event=%s" % str(completed_event))
		return
	if str(completed_event.get("action", "")) != "harvest_crop":
		_fail("Harvest Crops completed work did not use the harvest action. event=%s" % str(completed_event))
		return
	if int(completed_event.get("resources", {}).get("grain", 0)) < 1:
		_fail("Harvest Crops completed work did not report grain gain. event=%s" % str(completed_event))
		return

	var receipt := str(scene.call("_format_agent_receipt", completed_event))
	if not receipt.contains("[Forge: Harvest Crops]") or not receipt.contains("harvested"):
		_fail("Harvest Crops receipt did not name the Forge harvest. receipt=%s" % receipt)
		return
	if trace_label == null or str(trace_label.text) != "Run Trace: Spec > Directive > Work Order > Agent Receipt":
		_fail("Harvest Crops did not trace through the agent receipt endpoint. text=%s" % (trace_label.text if trace_label else ""))
		return
	var trace_tooltip := str(trace_label.tooltip_text)
	if not trace_tooltip.contains("Run Target: Harvest Crops") or not trace_tooltip.contains("Stage: Agent Receipt"):
		_fail("Harvest Crops receipt trace did not expose target and stage. tooltip=%s" % trace_tooltip)
		return
	if not trace_tooltip.contains("Run Receipt: %s" % receipt):
		_fail("Harvest Crops receipt trace did not expose labeled receipt detail. tooltip=%s receipt=%s" % [trace_tooltip, receipt])
		return
	if _result_text(game_ui) != "Agent Receipt: Harvest Crops":
		_fail("Harvest Crops completed-work header did not show the agent receipt endpoint. text=%s" % _result_text(game_ui))
		return
	if _visible_route_text(game_ui) != "Run Route: Spec > Crew Order > Agent Receipt":
		_fail("Harvest Crops completed-work route did not reach Agent Receipt. text=%s" % _visible_route_text(game_ui))
		return
	if not _visible_receipt_text(game_ui).begins_with("Run Receipt: ") or not _visible_receipt_text(game_ui).contains("harvested"):
		_fail("Harvest Crops completed-work did not expose compact harvest receipt detail. text=%s" % _visible_receipt_text(game_ui))
		return
	if _visible_history_text(game_ui) != "Run Trail: Harvest Crops | Passed (Harness Receipt) > Crew Queued > Agent Receipt [current]":
		_fail("Harvest Crops visible Run Trail did not summarize the lifecycle. text=%s" % _visible_history_text(game_ui))
		return

	var summary: Dictionary = scene.get_node("GameEventLog").call("build_day_summary", scene.get_node("FarmWorld/GridManager").day)
	if not _summary_has_forge_work(summary, str(order.get("forge_run_id", "")), "Harvest Crops"):
		_fail("Harvest Crops day summary did not keep Forge work context. summary=%s" % str(summary.get("agent_skill_forge_actions", {})))
		return
	var formatted_summary := str(scene.call("_format_day_summary", summary))
	if not formatted_summary.contains("forge work") or not formatted_summary.contains("Harvest Crops"):
		_fail("Harvest Crops formatted day summary did not include Forge work context. saw=%s" % formatted_summary)
		return

	scene.queue_free()
	await process_frame


func _test_build_fence_completion_reaches_agent_receipt() -> void:
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
		_fail("Skill Forge run button missing before Build Fence receipt smoke.")
		return
	run_button.pressed.emit()
	await process_frame

	var order_id := _latest_forge_order_id(scene, "build_fence_starter")
	if order_id == "" or not scene.work_orders.has(order_id):
		_fail("Build Fence did not draft a Forge work order for receipt smoke.")
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
	var agent_manager = scene.get_node("FarmWorld/AgentManager")
	for agent in agent_manager.agents:
		agent.move_speed = 42.0

	scene.call("_on_work_order_requested", order_id)
	await process_frame
	await process_frame

	var trace_label = game_ui.get("_skill_forge_trace_label") as Label
	if trace_label == null or str(trace_label.text) != "Run Trace: Spec > Directive > Work Order > Crew Queued":
		_fail("Build Fence did not trace the queued crew work. text=%s" % (trace_label.text if trace_label else ""))
		return
	if _result_text(game_ui) != "Crew Queued: Build Fence":
		_fail("Build Fence queued header did not follow the crew lifecycle. text=%s" % _result_text(game_ui))
		return
	if not _visible_detail_text(game_ui).begins_with("Run Context: agent Bert | target ") or not _visible_detail_text(game_ui).contains("| source Starter Lab"):
		_fail("Build Fence queued state did not expose the Forge run context. text=%s" % _visible_detail_text(game_ui))
		return

	await create_timer(1.4).timeout
	if str(tile.decor_id) != "fence":
		_fail("Build Fence Forge work did not place the fence. decor=%s" % str(tile.decor_id))
		return

	var completed_event: Dictionary = _completed_forge_world_action(scene, order)
	if completed_event.is_empty():
		_fail("Build Fence did not record a Forge-tagged build action.")
		return
	if str(completed_event.get("skill_name", "")) != "Build Fence":
		_fail("Build Fence completed work did not keep the readable skill name. event=%s" % str(completed_event))
		return
	if str(completed_event.get("action", "")) != "build_fence_order":
		_fail("Build Fence completed work did not use the fence-build action. event=%s" % str(completed_event))
		return
	if int(completed_event.get("crafted_cost", {}).get("fence_kit", 0)) < 1:
		_fail("Build Fence completed work did not report the Fence Kit cost. event=%s" % str(completed_event))
		return

	var receipt := str(scene.call("_format_agent_receipt", completed_event))
	if not receipt.contains("[Forge: Build Fence]") or not receipt.contains("built fence"):
		_fail("Build Fence receipt did not name the Forge fence work. receipt=%s" % receipt)
		return
	if trace_label == null or str(trace_label.text) != "Run Trace: Spec > Directive > Work Order > Agent Receipt":
		_fail("Build Fence did not trace through the agent receipt endpoint. text=%s" % (trace_label.text if trace_label else ""))
		return
	var trace_tooltip := str(trace_label.tooltip_text)
	if not trace_tooltip.contains("Run Target: Build Fence") or not trace_tooltip.contains("Stage: Agent Receipt"):
		_fail("Build Fence receipt trace did not expose target and stage. tooltip=%s" % trace_tooltip)
		return
	if not trace_tooltip.contains("Run Receipt: %s" % receipt):
		_fail("Build Fence receipt trace did not expose labeled receipt detail. tooltip=%s receipt=%s" % [trace_tooltip, receipt])
		return
	if _result_text(game_ui) != "Agent Receipt: Build Fence":
		_fail("Build Fence completed-work header did not show the agent receipt endpoint. text=%s" % _result_text(game_ui))
		return
	if _visible_route_text(game_ui) != "Run Route: Spec > Crew Order > Agent Receipt":
		_fail("Build Fence completed-work route did not reach Agent Receipt. text=%s" % _visible_route_text(game_ui))
		return
	if not _visible_receipt_text(game_ui).begins_with("Run Receipt: ") or not _visible_receipt_text(game_ui).contains("built fence"):
		_fail("Build Fence completed-work did not expose compact fence receipt detail. text=%s" % _visible_receipt_text(game_ui))
		return
	if _visible_history_text(game_ui) != "Run Trail: Build Fence | Passed (Harness Receipt) > Crew Queued > Agent Receipt [current]":
		_fail("Build Fence visible Run Trail did not summarize the lifecycle. text=%s" % _visible_history_text(game_ui))
		return

	var summary: Dictionary = scene.get_node("GameEventLog").call("build_day_summary", scene.get_node("FarmWorld/GridManager").day)
	if not _summary_has_forge_work(summary, str(order.get("forge_run_id", "")), "Build Fence"):
		_fail("Build Fence day summary did not keep Forge work context. summary=%s" % str(summary.get("agent_skill_forge_actions", {})))
		return
	var formatted_summary := str(scene.call("_format_day_summary", summary))
	if not formatted_summary.contains("forge work") or not formatted_summary.contains("Build Fence"):
		_fail("Build Fence formatted day summary did not include Forge work context. saw=%s" % formatted_summary)
		return

	scene.queue_free()
	await process_frame


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

	var trace_label = game_ui.get("_skill_forge_trace_label") as Label
	if trace_label == null or str(trace_label.text) != "Run Trace: Spec > Directive > Work Order > Crew Waiting":
		_fail("Forge panel did not trace waiting crew work. text=%s" % (trace_label.text if trace_label else ""))
		return
	var trace_tooltip := str(trace_label.tooltip_text)
	if not trace_tooltip.contains("Forge order waiting; no free crew yet") or not trace_tooltip.contains("Run Target: Clear Patch") or not trace_tooltip.contains("Run Context: agent Chuck | target ") or not trace_tooltip.contains("| source Starter Lab"):
		_fail("Forge waiting trace did not preserve readable work context. tooltip=%s" % trace_tooltip)
		return
	if not trace_tooltip.contains("agent Chuck"):
		_fail("Forge waiting trace did not preserve the readable harness agent. tooltip=%s order=%s" % [trace_tooltip, str(order)])
		return
	if not trace_tooltip.contains("Stage: Crew Waiting"):
		_fail("Forge waiting trace did not expose the crew-waiting stage. tooltip=%s" % trace_tooltip)
		return
	if not trace_tooltip.contains("Run Ref: run %s" % str(order.get("forge_run_id", ""))) or not trace_tooltip.contains("order %s" % order_id):
		_fail("Forge waiting trace did not preserve run/order identity. tooltip=%s order=%s" % [trace_tooltip, str(order)])
		return
	if not trace_tooltip.contains("Passed Clear Patch"):
		_fail("Forge waiting trace did not preserve recent receipt history. tooltip=%s" % trace_tooltip)
		return
	if not trace_tooltip.contains("Passed Clear Patch (Harness Receipt)"):
		_fail("Forge waiting trace history did not name the harness receipt endpoint. tooltip=%s" % trace_tooltip)
		return
	if not trace_tooltip.contains("Crew Waiting Clear Patch"):
		_fail("Forge waiting trace did not remember the crew-waiting stage. tooltip=%s" % trace_tooltip)
		return
	if not trace_tooltip.contains("Current Run Detail: Crew Waiting -> Clear Patch"):
		_fail("Forge waiting trace did not expose current run detail before history. tooltip=%s" % trace_tooltip)
		return
	var waiting_history_start := trace_tooltip.find("Run History: Passed Clear Patch")
	var waiting_history_stage_index := trace_tooltip.find("Crew Waiting Clear Patch", waiting_history_start)
	if waiting_history_start == -1 or waiting_history_stage_index <= waiting_history_start:
		_fail("Forge waiting trace history was not chronological. tooltip=%s" % trace_tooltip)
		return
	if not trace_tooltip.contains("Next Step: Wait for free crew"):
		_fail("Forge waiting trace did not expose the crew-availability next step. tooltip=%s" % trace_tooltip)
		return
	if not trace_tooltip.contains("Lesson: Crew is busy; wait for a free agent."):
		_fail("Forge waiting trace did not expose the waiting lesson cue. tooltip=%s" % trace_tooltip)
		return
	if not trace_tooltip.contains("Run Route: Spec > Crew Order > Crew Waiting"):
		_fail("Forge waiting trace did not expose the waiting route. tooltip=%s" % trace_tooltip)
		return
	if not trace_tooltip.contains("Run Trace: Spec > Directive > Work Order > Crew Waiting"):
		_fail("Forge waiting trace did not expose the labeled run trace path. tooltip=%s" % trace_tooltip)
		return
	if not trace_tooltip.contains("Trace Scan: Crew busy | Next free crew"):
		_fail("Forge waiting trace did not expose the waiting trace scan. tooltip=%s" % trace_tooltip)
		return
	if not trace_tooltip.contains("Run Receipt: Forge order waiting; no free crew yet: Clear Patch"):
		_fail("Forge waiting trace did not expose labeled receipt detail. tooltip=%s" % trace_tooltip)
		return
	if _result_text(game_ui) != "Crew Waiting: Clear Patch":
		_fail("Forge waiting-work header did not follow the waiting lifecycle. text=%s" % _result_text(game_ui))
		return
	if not _result_tooltip(game_ui).contains("Stage: Crew Waiting") or not _result_tooltip(game_ui).contains("Run Route: Spec > Crew Order > Crew Waiting") or not _result_tooltip(game_ui).contains("Next Step: Wait for free crew") or not _result_tooltip(game_ui).contains("Forge order waiting; no free crew yet"):
		_fail("Forge waiting-work header tooltip did not keep waiting trace detail. tooltip=%s" % _result_tooltip(game_ui))
		return
	var waiting_history_text := _visible_history_text(game_ui)
	if waiting_history_text != "Run Trail: Clear Patch | Passed (Harness Receipt) > Crew Waiting [current]":
		_fail("Forge waiting visible Run Trail did not summarize the lifecycle. text=%s" % waiting_history_text)
		return
	if not _history_tooltip(game_ui).contains("Current Run Detail: Crew Waiting -> Clear Patch"):
		_fail("Forge waiting history tooltip did not expose the current lifecycle detail. tooltip=%s" % _history_tooltip(game_ui))
		return
	if not _history_tooltip(game_ui).contains("Trace Scan: Crew busy | Next free crew"):
		_fail("Forge waiting history tooltip did not expose the current trace scan. tooltip=%s" % _history_tooltip(game_ui))
		return
	if not _history_tooltip(game_ui).contains("Next Step: Wait for free crew"):
		_fail("Forge waiting history tooltip did not expose the current next step. tooltip=%s" % _history_tooltip(game_ui))
		return
	if not _history_tooltip(game_ui).contains("Run Receipt: Forge order waiting; no free crew yet: Clear Patch"):
		_fail("Forge waiting history tooltip did not label the current receipt. tooltip=%s" % _history_tooltip(game_ui))
		return
	if not _history_tooltip(game_ui).contains("Lesson: Crew is busy; wait for a free agent."):
		_fail("Forge waiting history tooltip did not expose the current waiting lesson. tooltip=%s" % _history_tooltip(game_ui))
		return
	if _visible_stage_text(game_ui) != "Stage: Crew Waiting | Clear Patch":
		_fail("Forge waiting current stage did not expose the crew-waiting state. text=%s" % _visible_stage_text(game_ui))
		return
	if _visible_route_text(game_ui) != "Run Route: Spec > Crew Order > Crew Waiting":
		_fail("Forge waiting work did not expose the compact route line. text=%s" % _visible_route_text(game_ui))
		return
	if not _visible_ref_text(game_ui).begins_with("Run Ref: run %s" % str(order.get("forge_run_id", ""))) or not _visible_ref_text(game_ui).contains("| order %s" % order_id):
		_fail("Forge waiting work did not expose compact run/order refs. text=%s order=%s" % [_visible_ref_text(game_ui), str(order)])
		return
	if _visible_next_text(game_ui) != "Next Step: Wait for free crew":
		_fail("Forge waiting next step did not point to crew availability. text=%s" % _visible_next_text(game_ui))
		return
	if _lesson_text(game_ui) != "Lesson Crew is busy; wait for a free agent.":
		_fail("Forge waiting work did not teach the waiting lifecycle state. text=%s" % _lesson_text(game_ui))
		return
	if not _visible_detail_text(game_ui).begins_with("Run Context: agent Chuck | target ") or not _visible_detail_text(game_ui).contains("| source Starter Lab"):
		_fail("Forge waiting work did not expose readable run context. text=%s" % _visible_detail_text(game_ui))
		return
	if not _visible_receipt_text(game_ui).begins_with("Run Receipt: ") or not _visible_receipt_text(game_ui).contains("Forge order waiting; no free crew yet"):
		_fail("Forge waiting work did not expose compact receipt detail. text=%s" % _visible_receipt_text(game_ui))
		return
	if _visible_drift_text(game_ui) != "":
		_fail("Forge waiting work should keep Drift hidden. text=%s" % _visible_drift_text(game_ui))
		return
	var waiting_chip_tooltip := _work_order_chip_tooltip(game_ui, order_id)
	if not waiting_chip_tooltip.begins_with("Forge Work Order: Clear Patch"):
		_fail("Forge waiting-work chip did not open with the work-order role. tooltip=%s" % waiting_chip_tooltip)
		return
	if not waiting_chip_tooltip.contains("Run Context: agent Chuck | target ") or not waiting_chip_tooltip.contains("| source Starter Lab"):
		_fail("Forge work order chip did not expose waiting run context. tooltip=%s" % waiting_chip_tooltip)
		return
	if not waiting_chip_tooltip.contains("Directive: work_order_directive"):
		_fail("Forge work order chip did not expose the waiting directive kind. tooltip=%s" % waiting_chip_tooltip)
		return
	if not waiting_chip_tooltip.contains("Tool: clear_brush"):
		_fail("Forge work order chip did not expose the waiting tool call. tooltip=%s" % waiting_chip_tooltip)
		return
	if not waiting_chip_tooltip.contains("Stage: Crew Waiting"):
		_fail("Forge work order chip did not expose the crew-waiting stage. tooltip=%s" % waiting_chip_tooltip)
		return
	if not waiting_chip_tooltip.contains("Current Run Detail: Crew Waiting -> Clear Patch"):
		_fail("Forge work order chip did not expose the crew-waiting current detail. tooltip=%s" % waiting_chip_tooltip)
		return
	if not waiting_chip_tooltip.contains("Trace Scan: Crew busy | Next free crew"):
		_fail("Forge work order chip did not expose the crew-waiting trace scan. tooltip=%s" % waiting_chip_tooltip)
		return
	if not waiting_chip_tooltip.contains("Run Route: Spec > Crew Order > Crew Waiting"):
		_fail("Forge work order chip did not expose the crew-waiting route. tooltip=%s" % waiting_chip_tooltip)
		return
	if not waiting_chip_tooltip.contains("Run Trace: Spec > Directive > Work Order > Crew Waiting"):
		_fail("Forge work order chip did not expose the crew-waiting run trace. tooltip=%s" % waiting_chip_tooltip)
		return
	if not waiting_chip_tooltip.contains("Next Step: Wait for free crew"):
		_fail("Forge work order chip did not expose the crew-waiting next step. tooltip=%s" % waiting_chip_tooltip)
		return
	if not waiting_chip_tooltip.contains("Lesson: Crew is busy; wait for a free agent."):
		_fail("Forge work order chip did not expose the crew-waiting lesson cue. tooltip=%s" % waiting_chip_tooltip)
		return
	if not waiting_chip_tooltip.contains("Run Receipt: Forge order waiting; no free crew yet: Clear Patch"):
		_fail("Forge work order chip did not expose the crew-waiting receipt cue. tooltip=%s" % waiting_chip_tooltip)
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
