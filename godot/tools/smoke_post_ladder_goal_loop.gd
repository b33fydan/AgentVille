extends SceneTree

const GRADUATE_AGENT_ID := "bert"

var _failed := false


func _initialize() -> void:
	root.content_scale_size = Vector2i(1600, 900)
	root.size = Vector2i(1600, 900)
	call_deferred("_run")


func _run() -> void:
	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	if not scene.has_method("_ensure_post_ladder_goal_loop"):
		_fail("Game did not expose the deterministic post-ladder goal-loop seam.")
		return

	var progress = scene.get("_player_progress")
	var lesson_library = scene.get("_skill_lesson_library")
	var game_ui = scene.get_node_or_null("GameUI")
	var agent_manager = scene.get_node_or_null("FarmWorld/AgentManager")
	if progress == null or lesson_library == null or game_ui == null or agent_manager == null:
		_fail("Post-ladder smoke could not reach progress, curriculum, and UI systems.")
		return
	_prepare_agents(agent_manager)

	# A returning graduate reloads curriculum progress into a fresh farm world. The
	# goal-loop seed must therefore supply an affordable first step without relying
	# on resources that were not persisted with the lessons.
	var lesson_ids: Array = lesson_library.call("get_lesson_ids")
	if lesson_ids.is_empty():
		_fail("Curriculum did not expose lessons for the graduate setup.")
		return
	for index in range(lesson_ids.size()):
		var lesson_id := str(lesson_ids[index])
		var next_lesson_id := str(lesson_ids[index + 1]) if index + 1 < lesson_ids.size() else ""
		if not bool(progress.call("complete_lesson", lesson_id, next_lesson_id)):
			_fail("Could not complete lesson %s for the graduate setup." % lesson_id)
			return
	progress.call("set_current_lesson", "")
	scene.set("_active_lesson_id", "")
	scene.set("resources", {"fiber": 0, "grain": 0, "stone": 0})
	scene.call("_apply_player_progress", false)
	await process_frame

	if not bool(scene.get("_post_ladder_goal_seeded")):
		_fail("Completing the ladder did not seed a free-play goal loop.")
		return
	var mission_id := _latest_active_mission_id(scene)
	if mission_id == "":
		_fail("Post-ladder goal loop did not create an active existing-system mission.")
		return
	var mission: Dictionary = scene.crew_missions.get(mission_id, {})
	var demand_id := str(mission.get("current_demand_id", ""))
	var demand: Dictionary = scene.crafting_demands.get(demand_id, {})
	if demand_id == "" or demand.is_empty() or str(demand.get("status", "")) != "open":
		_fail("Post-ladder mission did not expose an open first demand. mission=%s demand=%s" % [str(mission), str(demand)])
		return
	if str(demand.get("mission_id", "")) != mission_id:
		_fail("Post-ladder demand lost its parent mission identity. mission=%s demand=%s" % [mission_id, str(demand)])
		return
	if str(demand.get("required_item", "")) == "":
		_fail("Post-ladder first demand did not exercise the lesson-to-free-play resource balance.")
		return
	if int(scene.resources.get("fiber", 0)) != 2 or int(scene.resources.get("grain", 0)) != 1:
		_fail("Returning-graduate stake did not match the Fence Kit recipe exactly. resources=%s" % str(scene.resources))
		return
	var missing_resources: Dictionary = scene.call("_missing_resources_for_demand", demand)
	if not missing_resources.is_empty() or not bool(scene.call("_can_craft_required_item_for_demand", demand)):
		_fail("Returning-graduate stake cannot afford the seeded demand. resources=%s demand=%s missing=%s" % [
			str(scene.resources),
			str(demand),
			str(missing_resources)
		])
		return
	if not _assert_visible_free_play_goal(game_ui, mission, demand):
		return

	# Keep a real Forge run pending while the social and day systems move around it.
	scene.call("_run_skill_forge_template", "clear_patch_starter", "Graduate Forge order drafted.")
	await process_frame
	var pending_before: Dictionary = scene.get("_pending_skill_forge_run").duplicate(true)
	if pending_before.is_empty():
		_fail("Free play did not draft an active Forge run after the ladder.")
		return
	var forge_run_id := str(pending_before.get("run_id", ""))
	var forge_order_id := str(pending_before.get("order_id", ""))
	if forge_run_id == "" or forge_order_id == "" or not scene.work_orders.has(forge_order_id):
		_fail("Post-ladder Forge run did not preserve correlated run/order identity. pending=%s" % str(pending_before))
		return
	var forge_order_before: Dictionary = scene.work_orders.get(forge_order_id, {}).duplicate(true)
	if str(forge_order_before.get("source", "")) != "skill_forge" or str(forge_order_before.get("status", "")) != "ready":
		_fail("Post-ladder Forge order was not a ready Forge work order. order=%s" % str(forge_order_before))
		return

	var grievance_reason := "Bert wants a graduate-loop check-in before tomorrow."
	scene.call("_queue_adversarial_grievance", GRADUATE_AGENT_ID, grievance_reason, {
		"grievance_text": "The first graduate goal should survive the rest of the farm loop.",
		"npc_goal": "confirm one practical next step",
		"source": "post_ladder_goal_loop_smoke"
	})
	if str(scene.get("_queued_grievance_agent_id")) != GRADUATE_AGENT_ID:
		_fail("Post-ladder Parley grievance did not queue alongside the Forge run.")
		return

	var day_before := int(scene.grid_manager.day)
	scene.call("_on_advance_day_requested")
	await process_frame
	if int(scene.grid_manager.day) != day_before + 1:
		_fail("Post-ladder day advance did not move exactly one day.")
		return
	if not _assert_interleaved_state(scene, mission_id, demand_id, forge_run_id, forge_order_id):
		return
	if str(scene.get("_queued_grievance_agent_id")) != GRADUATE_AGENT_ID:
		_fail("Queued Parley grievance was lost during the interleaved day advance.")
		return

	# Opening the queued Parley should consume only the prompt, not the farm goals.
	scene.call("_on_adversarial_encounter_requested", "")
	await process_frame
	var adversarial_session = scene.get("_adversarial_session")
	if adversarial_session == null or not bool(adversarial_session.call("has_active_session")):
		_fail("Queued post-ladder grievance did not open an active Parley session.")
		return
	var session: Dictionary = adversarial_session.call("get_session_snapshot")
	if str(session.get("agent_id", "")) != GRADUATE_AGENT_ID:
		_fail("Post-ladder Parley opened under the wrong crew member. session=%s" % str(session))
		return
	if str(scene.get("_queued_grievance_agent_id")) != "":
		_fail("Opening the post-ladder Parley did not consume its queued prompt.")
		return
	if not _assert_interleaved_state(scene, mission_id, demand_id, forge_run_id, forge_order_id):
		return

	# Deliver the seeded Fence Kit through the same handler as the live demand
	# command. Recipes spend farm resources only, so this step must not touch money.
	var money_before_delivery := int(scene.money)
	scene.call("_on_crafting_demand_requested", demand_id)
	await process_frame
	if str(scene.crafting_demands.get(demand_id, {}).get("status", "")) != "done":
		_fail("The affordable Fence Kit command did not complete the first mission demand.")
		return
	if int(scene.money) != money_before_delivery:
		_fail("Resource-only Fence Kit crafting changed money. before=%s after=%s" % [money_before_delivery, int(scene.money)])
		return
	if int(scene.resources.get("fiber", -1)) != 0 or int(scene.resources.get("grain", -1)) != 0:
		_fail("Fence Kit delivery did not spend exactly 2 Fiber + 1 Grain. resources=%s" % str(scene.resources))
		return
	if int(scene.crafted_items.get("fence_kit", -1)) != 0 or int(scene.reserved_crafted_items.get("fence_kit", -1)) != 0:
		_fail("Fence Kit delivery left a crafted or reserved kit behind. crafted=%s reserved=%s" % [
			str(scene.crafted_items),
			str(scene.reserved_crafted_items)
		])
		return

	mission = scene.crew_missions.get(mission_id, {})
	var brush_demand_id := str(mission.get("current_demand_id", ""))
	var brush_demand: Dictionary = scene.crafting_demands.get(brush_demand_id, {})
	if str(mission.get("status", "")) != "active" or int(mission.get("completed_steps", 0)) != 1 or int(mission.get("current_step_index", -1)) != 1:
		_fail("Fence Kit delivery did not advance Graduate Field Loop to step 2. mission=%s" % str(mission))
		return
	if brush_demand_id == "" or brush_demand_id == demand_id or str(brush_demand.get("status", "")) != "open":
		_fail("Graduate Field Loop did not expose a new open brush demand. mission=%s demand=%s" % [str(mission), str(brush_demand)])
		return
	if str(brush_demand.get("mission_id", "")) != mission_id or str(brush_demand.get("kind", "")) != "clear_brush" or str(brush_demand.get("required_action", "")) != "clear_brush":
		_fail("Graduate Field Loop step 2 lost its mission/action identity. demand=%s" % str(brush_demand))
		return
	var brush_target = brush_demand.get("target_tile", Vector2i(-1, -1))
	if typeof(brush_target) != TYPE_VECTOR2I or brush_target == Vector2i(-1, -1):
		_fail("Graduate Field Loop brush demand did not receive a real farm target. demand=%s" % str(brush_demand))
		return
	if pending_before.get("target_tile", Vector2i(-1, -1)) != brush_target:
		_fail("The interleaved Forge draft and mission brush step did not converge on the same selected-tile target. forge=%s demand=%s" % [
			str(pending_before.get("target_tile", Vector2i(-1, -1))),
			str(brush_target)
		])
		return

	# Send the already-drafted Forge order through the real crew pathway. Its
	# AgentActor world action should mutate the tile, complete the demand, and close
	# the mission without a smoke-only completion shortcut.
	scene.call("_on_work_order_requested", forge_order_id)
	if not await _await_mission_and_forge_completion(scene, mission_id, brush_demand_id, forge_run_id, forge_order_id, brush_target):
		return
	if int(scene.money) != money_before_delivery:
		_fail("The resource-only brush mission changed money. before=%s after=%s" % [money_before_delivery, int(scene.money)])
		return
	if int(scene.resources.get("fiber", 0)) != 2 or int(scene.resources.get("grain", 0)) != 1:
		_fail("Completed graduate loop did not preserve the real brush receipt and mission reward. resources=%s" % str(scene.resources))
		return

	# A completed mission must be a waypoint, not a terminal state. Select another
	# real brush tile and draft a new Forge run through the live template seam.
	var continuation_tile = _find_brush_tile(scene.grid_manager, brush_target)
	if continuation_tile == null:
		_fail("Graduate loop completion left no brush target for continued Forge play.")
		return
	if not bool(scene.get("_farm_sandbox_unlocked")):
		_fail("Graduate loop completion relocked the farm sandbox.")
		return
	scene.placement_tool.call("select_tile_without_action", continuation_tile)
	scene.call("_run_skill_forge_template", "clear_patch_starter", "Graduate continuation drafted.")
	await process_frame
	var continuation: Dictionary = scene.get("_pending_skill_forge_run").duplicate(true)
	var continuation_order_id := str(continuation.get("order_id", ""))
	if continuation.is_empty() or continuation_order_id == "" or continuation_order_id == forge_order_id:
		_fail("The completed graduate loop could not draft a fresh Forge run. pending=%s" % str(continuation))
		return
	if continuation.get("target_tile", Vector2i(-1, -1)) != continuation_tile.grid_pos:
		_fail("Fresh post-mission Forge run lost the newly selected farm target. pending=%s" % str(continuation))
		return
	var continuation_order: Dictionary = scene.work_orders.get(continuation_order_id, {})
	if str(continuation_order.get("status", "")) != "ready" or str(continuation_order.get("source", "")) != "skill_forge":
		_fail("Fresh post-mission Forge run did not leave a sendable order. order=%s" % str(continuation_order))
		return

	scene.queue_free()
	await process_frame
	await process_frame
	await process_frame
	if not _failed:
		quit()


func _assert_visible_free_play_goal(game_ui, mission: Dictionary, demand: Dictionary) -> bool:
	var goal_panel = game_ui.get("_onboarding_goal_panel") as Control
	var goal_label = game_ui.get("_onboarding_goal_label") as Label
	if goal_panel == null or goal_label == null or not goal_panel.visible or not goal_label.visible:
		_fail("Graduate free-play goal was only transient; the persistent onboarding goal panel was not visible.")
		return false
	var goal_text: String = str(goal_label.text).to_upper()
	var mission_label: String = str(mission.get("label", "")).to_upper()
	var demand_label: String = str(demand.get("label", "")).to_upper()
	if not goal_text.contains("FREE PLAY"):
		_fail("Persistent graduate goal did not identify free play. text=%s" % goal_label.text)
		return false
	if mission_label != "" and not goal_text.contains(mission_label) and demand_label != "" and not goal_text.contains(demand_label):
		_fail("Persistent graduate goal named neither the mission nor its first demand. text=%s" % goal_label.text)
		return false
	return true


func _assert_interleaved_state(scene: Node, mission_id: String, demand_id: String, forge_run_id: String, forge_order_id: String) -> bool:
	var mission: Dictionary = scene.crew_missions.get(mission_id, {})
	if str(mission.get("status", "")) != "active" or str(mission.get("current_demand_id", "")) != demand_id:
		_fail("Mission identity or active step was corrupted by an interleaved system. mission=%s" % str(mission))
		return false
	var demand: Dictionary = scene.crafting_demands.get(demand_id, {})
	if str(demand.get("status", "")) != "open" or str(demand.get("mission_id", "")) != mission_id:
		_fail("Open mission demand was lost or corrupted by an interleaved system. demand=%s" % str(demand))
		return false
	var pending: Dictionary = scene.get("_pending_skill_forge_run")
	if str(pending.get("run_id", "")) != forge_run_id or str(pending.get("order_id", "")) != forge_order_id:
		_fail("Pending Forge correlation was lost during mission/Parley/day interleaving. pending=%s" % str(pending))
		return false
	if not scene.work_orders.has(forge_order_id):
		_fail("Pending Forge work order disappeared during mission/Parley/day interleaving.")
		return false
	var order: Dictionary = scene.work_orders.get(forge_order_id, {})
	if str(order.get("forge_run_id", "")) != forge_run_id or str(order.get("source", "")) != "skill_forge":
		_fail("Forge work order context was corrupted by mission/Parley/day interleaving. order=%s" % str(order))
		return false
	return true


func _latest_active_mission_id(scene: Node) -> String:
	for index in range(scene.crew_mission_ids.size() - 1, -1, -1):
		var mission_id := str(scene.crew_mission_ids[index])
		if str(scene.crew_missions.get(mission_id, {}).get("status", "")) == "active":
			return mission_id
	return ""


func _await_mission_and_forge_completion(
	scene: Node,
	mission_id: String,
	demand_id: String,
	forge_run_id: String,
	forge_order_id: String,
	target_tile: Vector2i
) -> bool:
	for _frame in range(600):
		var mission: Dictionary = scene.crew_missions.get(mission_id, {})
		var demand: Dictionary = scene.crafting_demands.get(demand_id, {})
		var order: Dictionary = scene.work_orders.get(forge_order_id, {})
		if str(mission.get("status", "")) == "done" \
			and str(demand.get("status", "")) == "done" \
			and str(order.get("status", "")) == "done" \
			and scene.get("_pending_skill_forge_run").is_empty():
			break
		await process_frame

	var mission: Dictionary = scene.crew_missions.get(mission_id, {})
	var demand: Dictionary = scene.crafting_demands.get(demand_id, {})
	var order: Dictionary = scene.work_orders.get(forge_order_id, {})
	if str(demand.get("status", "")) != "done":
		_fail("Real Forge world work did not complete the mission brush demand. demand=%s order=%s" % [str(demand), str(order)])
		return false
	if str(mission.get("status", "")) != "done" or int(mission.get("completed_steps", 0)) != 2 or str(mission.get("current_demand_id", "")) != "":
		_fail("Real Forge world work did not complete Graduate Field Loop. mission=%s" % str(mission))
		return false
	if str(order.get("status", "")) != "done" or not scene.get("_pending_skill_forge_run").is_empty():
		_fail("Mission completion left the correlated Forge lifecycle unfinished. order=%s pending=%s" % [str(order), str(scene.get("_pending_skill_forge_run"))])
		return false
	var tile = scene.grid_manager.get_tile(target_tile)
	if tile == null or str(tile.decor_id) != "":
		_fail("Real Forge world work did not clear the mission target tile %s." % str(target_tile))
		return false
	if not _has_successful_forge_world_action(scene, forge_run_id, forge_order_id, target_tile):
		_fail("Graduate mission completion had no correlated AgentActor world-action receipt.")
		return false
	return true


func _has_successful_forge_world_action(scene: Node, forge_run_id: String, forge_order_id: String, target_tile: Vector2i) -> bool:
	for event_value in scene.get_node("GameEventLog").get("events"):
		if typeof(event_value) != TYPE_DICTIONARY:
			continue
		var event: Dictionary = event_value
		if str(event.get("type", "")) != "agent_world_action" or not bool(event.get("success", false)):
			continue
		if str(event.get("forge_run_id", "")) != forge_run_id or str(event.get("work_order_id", "")) != forge_order_id:
			continue
		if str(event.get("action", "")) == "clear_brush" and event.get("grid_pos", Vector2i(-1, -1)) == target_tile:
			return true
	return false


func _prepare_agents(agent_manager) -> void:
	for actor in agent_manager.agents:
		actor.call("_complete_active_decision")
		actor.set("_decision_timer", 999.0)
		actor.move_speed = 60.0


func _find_brush_tile(grid, excluded_target: Vector2i):
	for tile in grid.tiles.values():
		if tile.grid_pos != excluded_target and str(tile.decor_id) in ["tall_grass", "flower_patch"]:
			return tile
	return null


func _fail(message: String) -> void:
	_failed = true
	push_error(message)
	quit(1)
