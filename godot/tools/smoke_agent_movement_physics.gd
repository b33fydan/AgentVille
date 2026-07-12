extends SceneTree

const FEET_LOCAL_BOTTOM := 0.02
const STEP_DELTA := 0.05

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var grid = scene.get_node("FarmWorld/GridManager")
	var agent_manager = scene.get_node("FarmWorld/AgentManager")
	var placement_tool = scene.get_node("PlacementTool")
	var agent = agent_manager.agents[0]
	for crew_member in agent_manager.agents:
		crew_member.set_process(false)

	_test_grid_contract(grid)
	if _failed:
		return
	_test_occupied_placement(scene, agent_manager, agent, grid, placement_tool)
	if _failed:
		return
	_test_structure_avoidance(agent, grid)
	if _failed:
		return
	_test_structure_approach(agent, grid)
	if _failed:
		return
	_test_fence_build_standoff(agent, grid)
	if _failed:
		return
	_test_dynamic_replan(agent, grid)
	if _failed:
		return
	_test_grounding_speed_and_gait(agent, grid)
	if _failed:
		return

	root.remove_child(scene)
	scene.queue_free()
	await process_frame
	quit()


func _test_grid_contract(grid) -> void:
	var blocker_pos := Vector2i(2, 3)
	var blocker = grid.get_tile(blocker_pos)
	blocker.erase()
	if not blocker.place_item("barn"):
		_fail("Movement smoke could not create the route blocker.")
		return
	if grid.is_agent_walkable(blocker_pos):
		_fail("Barn tile remained walkable for agents.")
		return
	if grid.is_agent_walkable(Vector2i(-1, 4)) or grid.is_agent_walkable(Vector2i(grid.width, 4)):
		_fail("Agent walkability escaped the farm bounds.")
		return

	var route: Array = grid.find_agent_path(Vector2i(2, 4), Vector2i(2, 0))
	if route.is_empty() or route[0] != Vector2i(2, 4) or route[-1] != Vector2i(2, 0):
		_fail("Grid pathfinder did not return a complete bounded route around the barn.")
		return
	if route.has(blocker_pos):
		_fail("Grid pathfinder routed through the barn tile.")
		return
	_expect_valid_cardinal_route(grid, route, "barn detour")
	if _failed:
		return

	var edge_route: Array = grid.find_agent_path(Vector2i(0, 4), Vector2i(10, 4))
	_expect_valid_cardinal_route(grid, edge_route, "edge-to-edge route")


func _test_structure_avoidance(agent, grid) -> void:
	_place_agent(agent, Vector2i(2, 4))
	agent.move_speed = 2.0
	agent.call("_set_target_grid", Vector2i(2, 0), false)
	if not bool(agent.get("_route_reachable")):
		_fail("Agent could not route around a reachable barn.")
		return

	for _step in range(180):
		agent.call("_update_movement", STEP_DELTA)
		var sampled_tile = grid.get_tile_from_world(agent.position)
		if sampled_tile == null:
			_fail("Agent left the farm while routing around a structure.")
			return
		if bool(sampled_tile.call("blocks_agent_movement")):
			_fail("Agent entered blocked tile %s while routing around a structure." % sampled_tile.grid_pos)
			return
		if bool(agent.call("_is_at_target")):
			break
	if not bool(agent.call("_is_at_target")) or agent.current_grid_pos != Vector2i(2, 0):
		_fail("Agent did not finish the structure-safe route.")


func _test_occupied_placement(scene, agent_manager, agent, grid, placement_tool) -> void:
	var occupied_pos := Vector2i(5, 4)
	var occupied_tile = grid.get_tile(occupied_pos)
	_place_agent(agent, occupied_pos)
	placement_tool.set_selected_item("barn")
	var result: Dictionary = placement_tool.call("_apply_selected_item", occupied_tile)
	if bool(result.get("success", true)) or str(occupied_tile.structure_id) != "":
		_fail("Player placement created a structure on an occupied agent tile.")
		return
	if not str(result.get("message", "")).contains("crew member"):
		_fail("Occupied solid placement did not explain the crew boundary.")
		return
	if bool(scene.call("_can_target_crew_order", "build_fence", occupied_pos)):
		_fail("Crew fence targeting accepted a tile occupied by an agent.")
		return

	var other_agent = agent_manager.agents[1]
	var race_target := Vector2i(6, 4)
	var race_tile = grid.get_tile(race_target)
	race_tile.erase()
	_place_agent(agent, occupied_pos)
	_place_agent(other_agent, race_target)
	agent.call("_build_fence_order_at", race_target, {"id": "occupied_smoke", "label": "Occupied smoke"})
	if str(race_tile.decor_id) == "fence":
		_fail("Crew fence execution placed a fence under another agent after assignment.")
		return

	var perk_occupied_pos := Vector2i(0, 0)
	var perk_occupied_tile = grid.get_tile(perk_occupied_pos)
	perk_occupied_tile.erase()
	_place_agent(other_agent, perk_occupied_pos)
	scene.set("_fence_hands_timer", 1.0)
	scene.set("_fence_hands_charges", 1)
	if not bool(scene.call("_try_use_fence_hands")):
		_fail("Fence Hands could not find an alternate unoccupied tile.")
		return
	if str(perk_occupied_tile.decor_id) == "fence":
		_fail("Fence Hands placed a fence under an occupied agent tile.")
		return
	scene.set("_fence_hands_timer", 0.0)
	scene.set("_fence_hands_charges", 0)
	_place_agent(other_agent, Vector2i(5, 5))


func _test_structure_approach(agent, grid) -> void:
	var structure_pos := Vector2i(2, 3)
	_place_agent(agent, Vector2i(5, 4))
	agent.call("_set_target_grid", structure_pos, true)
	if not _drive_to_target(agent, grid, 180):
		return
	if agent.current_grid_pos == structure_pos:
		_fail("Agent stopped inside the structure interaction tile.")
		return
	if _cardinal_distance(agent.current_grid_pos, structure_pos) != 1:
		_fail("Agent did not stop on a cardinal tile beside the structure.")


func _test_fence_build_standoff(agent, grid) -> void:
	var stand_pos := Vector2i(5, 4)
	var fence_pos := Vector2i(6, 4)
	var fence_tile = grid.get_tile(fence_pos)
	fence_tile.erase()
	_place_agent(agent, stand_pos)
	agent.call("_start_decision", {
		"action": "build_fence_order",
		"reason": "movement physics fence standoff",
		"score": 100.0,
		"target_tile": fence_pos,
		"work_order": {"id": "movement_smoke", "label": "Movement smoke"}
	})
	agent.call("_update_active_decision", 0.01)
	if str(fence_tile.decor_id) != "fence":
		_fail("Fence work action did not execute from its approach tile.")
		return
	if agent.current_grid_pos != stand_pos or grid.get_tile_from_world(agent.position).grid_pos != stand_pos:
		_fail("Fence work action enclosed the agent inside the new fence.")
		return
	if not grid.is_agent_walkable(stand_pos):
		_fail("Fence work standoff left the agent on a blocked tile.")
		return
	agent.call("_complete_active_decision")
	fence_tile.erase()


func _test_dynamic_replan(agent, grid) -> void:
	_place_agent(agent, Vector2i(5, 4))
	agent.state["expression"] = "neutral"
	agent.move_speed = 1.0
	agent.call("_set_target_grid", Vector2i(5, 0), false)
	var route: Array = agent.get("_movement_path")
	if route.is_empty():
		_fail("Dynamic replan setup did not produce a route.")
		return
	agent.call("_update_movement", 0.2)
	var position_before_block: Vector3 = agent.position
	route = agent.get("_movement_path")
	var blocked_waypoint: Vector2i = route[0]
	var blocked_tile = grid.get_tile(blocked_waypoint)
	blocked_tile.erase()
	if not blocked_tile.place_item("rock"):
		_fail("Dynamic replan setup could not block the next waypoint.")
		return
	agent.call("_update_movement", STEP_DELTA)
	if _planar_distance(position_before_block, agent.position) > agent.move_speed * STEP_DELTA + 0.002:
		_fail("Dynamic replan snapped the agent backward instead of preserving current motion.")
		return
	var replanned_route: Array = agent.get("_movement_path")
	if not bool(agent.get("_route_reachable")) or replanned_route.has(blocked_waypoint):
		_fail("Agent did not replan when its next waypoint became blocked.")
		return
	if grid.get_tile_from_world(agent.position).grid_pos != agent.current_grid_pos:
		_fail("Dynamic replan did not return the agent to a safe current tile.")
	blocked_tile.erase()


func _test_grounding_speed_and_gait(agent, grid) -> void:
	var start := Vector2i(5, 4)
	var target := Vector2i(5, 3)
	_place_agent(agent, start)
	var expected_surface: float = float(grid.agent_walk_surface_y(start))
	var feet_y: float = agent.position.y + FEET_LOCAL_BOTTOM
	if absf(feet_y - expected_surface) > 0.002:
		_fail("Agent feet are not seated on the packed tile surface. feet=%.4f surface=%.4f" % [feet_y, expected_surface])
		return

	var raised_target := Vector2i(4, 4)
	var raised_tile = grid.get_tile(raised_target)
	raised_tile.set_terrain("soil")
	agent.move_speed = 1.0
	agent.state["expression"] = "neutral"
	agent.call("_set_target_grid", raised_target, false)
	var saw_raised_surface := false
	for _step in range(30):
		agent.call("_update_movement", STEP_DELTA)
		var supporting_tile = grid.get_tile_from_world(agent.position)
		var supporting_surface: float = float(supporting_tile.call("agent_walk_surface_y"))
		feet_y = agent.position.y + FEET_LOCAL_BOTTOM
		if absf(feet_y - supporting_surface) > 0.002:
			_fail("Agent lost foot contact while crossing mixed tile heights. feet=%.4f surface=%.4f" % [feet_y, supporting_surface])
			return
		if supporting_tile.grid_pos == raised_target:
			saw_raised_surface = true
		if bool(agent.call("_is_at_target")):
			break
	if not saw_raised_surface or not bool(agent.call("_is_at_target")):
		_fail("Mixed-height grounding route did not reach the raised soil tile.")
		return
	raised_tile.set_terrain("dirt_path")

	agent.move_speed = 1.0
	agent.state["expression"] = "neutral"
	_place_agent(agent, start)
	agent.call("_set_target_grid", target, false)
	var neutral_start: Vector3 = agent.position
	agent.call("_update_movement", 0.2)
	var neutral_distance: float = _planar_distance(neutral_start, agent.position)
	if absf(neutral_distance - 0.2) > 0.002:
		_fail("Neutral movement did not follow the configured normal pace. distance=%.4f" % neutral_distance)
		return
	agent.call("_update_visual_motion", 0.1)
	var leg_a: MeshInstance3D = agent.get("_leg_a")
	var leg_b: MeshInstance3D = agent.get("_leg_b")
	var arm_a: MeshInstance3D = agent.get("_arm_a")
	var arm_b: MeshInstance3D = agent.get("_arm_b")
	if absf(leg_a.rotation.x) < 0.01 or leg_a.rotation.x * leg_b.rotation.x >= 0.0:
		_fail("Prototype gait did not swing the legs in opposition.")
		return
	if arm_a.rotation.x * arm_b.rotation.x >= 0.0 or arm_a.rotation.x * leg_a.rotation.x >= 0.0:
		_fail("Prototype gait did not counter-swing the arms and legs.")
		return

	_place_agent(agent, start)
	agent.call("apply_adversarial_result", {
		"outcome": "lost_patience",
		"agent_mood_delta": 0.0,
		"agent_irritation_delta": 20.0
	})
	if str(agent.state.get("expression", "")) != "angry":
		_fail("Lost-patience result did not put the agent in the real angry state.")
		return
	agent.call("_set_target_grid", target, false)
	var angry_start: Vector3 = agent.position
	agent.call("_update_movement", 0.2)
	var angry_distance: float = _planar_distance(angry_start, agent.position)
	if absf(angry_distance / neutral_distance - 1.5) > 0.002:
		_fail("Angry movement was not exactly 50 percent faster. neutral=%.4f angry=%.4f" % [neutral_distance, angry_distance])
		return
	if absf(float(agent.call("_current_work_speed_multiplier")) - 1.0) > 0.001:
		_fail("Angry movement boost leaked into work duration.")
		return

	agent.set("_movement_active", false)
	for _step in range(20):
		agent.call("_update_visual_motion", STEP_DELTA)
	if absf(leg_a.rotation.x) > 0.002 or absf(leg_b.rotation.x) > 0.002 or absf(arm_a.rotation.x) > 0.002 or absf(arm_b.rotation.x) > 0.002:
		_fail("Prototype gait did not settle back to a grounded idle pose.")
		return
	var visual_root: Node3D = agent.get("_visual_root")
	if absf(visual_root.position.y) > 0.0001:
		_fail("Idle voxel rig retained an upward bob and appeared to float.")


func _place_agent(agent, grid_pos: Vector2i) -> void:
	agent.position = agent.call("_world_for", grid_pos)
	agent.current_grid_pos = grid_pos
	agent.target_grid_pos = grid_pos
	agent.set("_target_position", agent.position)
	agent.set("_movement_path", [])
	agent.set("_route_reachable", true)
	agent.set("_movement_active", false)


func _drive_to_target(agent, grid, max_steps: int) -> bool:
	for _step in range(max_steps):
		agent.call("_update_movement", STEP_DELTA)
		var sampled_tile = grid.get_tile_from_world(agent.position)
		if sampled_tile == null or bool(sampled_tile.call("blocks_agent_movement")):
			_fail("Agent entered invalid ground while driving to its approach target.")
			return false
		if bool(agent.call("_is_at_target")):
			return true
	_fail("Agent did not reach its approach target within the smoke budget.")
	return false


func _expect_valid_cardinal_route(grid, route: Array, context: String) -> void:
	if route.is_empty():
		_fail("%s was empty." % context.capitalize())
		return
	for index in range(route.size()):
		var grid_pos: Vector2i = route[index]
		if not grid.is_in_bounds(grid_pos) or not grid.is_agent_walkable(grid_pos):
			_fail("%s included invalid tile %s." % [context.capitalize(), grid_pos])
			return
		if index > 0 and _cardinal_distance(route[index - 1], grid_pos) != 1:
			_fail("%s cut diagonally between %s and %s." % [context.capitalize(), route[index - 1], grid_pos])
			return


func _cardinal_distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


func _planar_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _fail(message: String) -> void:
	if _failed:
		return
	_failed = true
	push_error(message)
	quit(1)
