extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_idle_daily_plan_badge_is_visible_in_world()
	await _test_social_work_badge_overrides_plan()
	await _test_mission_work_badge_overrides_social_context()
	await _test_authored_mission_order_shows_mission_badge()
	quit()


func _test_idle_daily_plan_badge_is_visible_in_world() -> void:
	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var marigold = _agent_actor(scene, "marigold")
	if marigold == null:
		_fail("Could not find Marigold for idle plan badge check.")
		return

	var badge = marigold.get_node_or_null("VoxelRig/ReasonBadge")
	if badge == null:
		_fail("NPC visual rig did not create an in-world reason badge.")
		return
	if not badge.visible or str(badge.text) != "Plan":
		_fail("Idle daily plan badge was not visible as Plan. saw=%s visible=%s" % [str(badge.text), str(badge.visible)])
		return

	scene.queue_free()
	await process_frame


func _test_social_work_badge_overrides_plan() -> void:
	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var bert = _agent_actor(scene, "bert")
	if bert == null:
		_fail("Could not find Bert for social work badge check.")
		return

	bert.call("start_directive", "clear_brush", Vector2i(1, 1), "memory work", {
		"social_preference_source": "memory",
		"social_preference_label": "Seed Bundle"
	})
	await process_frame

	var badge = bert.get_node_or_null("VoxelRig/ReasonBadge")
	if badge == null or not badge.visible or str(badge.text) != "Memory":
		_fail("Active social work did not show the Memory reason badge.")
		return

	scene.queue_free()
	await process_frame


func _test_mission_work_badge_overrides_social_context() -> void:
	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var chuck = _agent_actor(scene, "chuck")
	if chuck == null:
		_fail("Could not find Chuck for mission badge check.")
		return

	chuck.call("start_directive", "clear_brush", Vector2i(1, 1), "mission work", {
		"mission_id": "mission_test",
		"mission_label": "Growth Run",
		"social_preference_source": "memory",
		"social_preference_label": "Seed Bundle"
	})
	await process_frame

	var badge = chuck.get_node_or_null("VoxelRig/ReasonBadge")
	if badge == null or not badge.visible or str(badge.text) != "Mission":
		_fail("Active mission work did not show the Mission reason badge.")
		return

	scene.queue_free()
	await process_frame


func _test_authored_mission_order_shows_mission_badge() -> void:
	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var grid = scene.get_node("FarmWorld/GridManager")
	var clear_target := Vector2i(1, 1)
	var harvest_target := Vector2i(2, 1)
	var clear_tile = grid.get_tile(clear_target)
	var harvest_tile = grid.get_tile(harvest_target)
	if clear_tile == null or harvest_tile == null:
		_fail("Mission badge setup could not find target tiles.")
		return
	clear_tile.erase()
	clear_tile.place_item("tall_grass")
	harvest_tile.erase()
	harvest_tile.till()
	harvest_tile.plant_wheat()
	harvest_tile.crop.setup("wheat", 3)

	var mission_id := str(scene.call("_create_crew_mission", {
		"label": "Marigold Growth Run",
		"steps": [
			{
				"kind": "clear_brush",
				"required_action": "clear_brush",
				"amount": 1,
				"label": "Clear Growth Patch",
				"target_tile": clear_target
			},
			{
				"kind": "harvest_crop",
				"required_action": "harvest_crop",
				"amount": 1,
				"label": "Harvest Growth Crop",
				"target_tile": harvest_target
			}
		]
	}, {
		"agent_id": "marigold",
		"agent_name": "Marigold"
	}))
	if mission_id == "":
		_fail("Mission badge setup did not create a mission.")
		return

	var first_demand := _latest_open_mission_demand(scene, mission_id)
	if first_demand.is_empty():
		_fail("Mission badge setup did not create its first demand.")
		return

	scene.call("_on_advance_day_requested")
	await process_frame

	var demand: Dictionary = scene.crafting_demands.get(str(first_demand.get("id", "")), {})
	var order_id := str(demand.get("authored_order_id", ""))
	if order_id == "" or not scene.work_orders.has(order_id):
		_fail("Aged mission demand did not create an authored order.")
		return

	scene.call("_on_work_order_requested", order_id)
	await process_frame

	if _active_agent_badge_text(scene) != "Mission":
		_fail("Assigned mission order did not show a Mission badge over the active NPC.")
		return

	scene.queue_free()
	await process_frame


func _agent_actor(scene: Node, agent_id: String):
	var agent_manager = scene.get_node("FarmWorld/AgentManager")
	for agent in agent_manager.agents:
		if str(agent.get("agent_id")) == agent_id:
			return agent
	return null


func _latest_open_mission_demand(scene: Node, mission_id: String) -> Dictionary:
	var demand_ids: Array = scene.get("crafting_demand_ids")
	var demands: Dictionary = scene.get("crafting_demands")
	for index in range(demand_ids.size() - 1, -1, -1):
		var demand_id := str(demand_ids[index])
		var demand: Dictionary = demands.get(demand_id, {})
		if str(demand.get("status", "")) == "open" and str(demand.get("mission_id", "")) == mission_id:
			return demand
	return {}


func _active_agent_badge_text(scene: Node) -> String:
	var agent_manager = scene.get_node("FarmWorld/AgentManager")
	for agent in agent_manager.agents:
		if str(agent.state.get("current_action", "idle")) == "idle":
			continue
		var badge = agent.get_node_or_null("VoxelRig/ReasonBadge")
		if badge != null and badge.visible:
			return str(badge.text)
	return ""


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
