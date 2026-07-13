extends SceneTree

const CANONICAL_PROGRAM := "agent \"Marigold\" {\n  observe selected_tile\n  when crop.ready {\n    use harvest_crop(selected_tile)\n  }\n  verify inventory_delta\n  receipt \"Harvest Crops run\"\n}"
const CLEAR_PROGRAM := "agent \"Chuck\" {\n  observe selected_tile\n  when inspect.has_brush {\n    use clear_brush(selected_tile)\n  }\n  verify tile_state\n  receipt \"Clear Patch run\"\n}"
const ALWAYS_HARVEST_PROGRAM := "agent \"Marigold\" {\n  observe selected_tile\n  when always {\n    use harvest_crop(selected_tile)\n  }\n  verify inventory_delta\n  receipt \"Always Harvest run\"\n}"


func _initialize() -> void:
	root.size = Vector2i(1600, 900)
	call_deferred("_run")


func _run() -> void:
	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var grid = scene.get_node("FarmWorld/GridManager")
	var placement_tool = scene.get_node("PlacementTool")
	var game_ui = scene.get_node("GameUI")
	var ready_tile = _find_ready_crop(grid)
	if ready_tile == null:
		_fail("Starter map did not expose a ready crop for the canonical Workbench run.")
		return
	var brush_tile = _find_brush_tile(grid)
	if brush_tile == null:
		_fail("Starter map did not expose brush for pending-run lifecycle checks.")
		return

	# A newer valid compile must retire the older pending run and its order.
	placement_tool.set_tool("select")
	placement_tool.call("_apply_to_tile", brush_tile)
	var editor = game_ui.get("_code_editor") as CodeEdit
	var compile_button = game_ui.get("_workbench_compile_button") as Button
	var runtime_label = game_ui.get("_workbench_runtime_label") as Label
	if editor == null or compile_button == null or runtime_label == null:
		_fail("Integrated Workbench controls were unavailable.")
		return
	editor.text = CLEAR_PROGRAM
	compile_button.pressed.emit()
	var replaced_pending: Dictionary = scene.get("_pending_skill_forge_run").duplicate(true)
	var replaced_order_id := str(replaced_pending.get("order_id", ""))
	if replaced_order_id == "":
		_fail("Clear program did not establish the pending run used by replacement coverage.")
		return
	if runtime_label.text != "PENDING  ·  WORLD CHECK":
		_fail("Compile button did not leave the Workbench in its real pending state. status=%s" % runtime_label.text)
		return
	placement_tool.call("_apply_to_tile", ready_tile)
	scene.call("_on_workbench_compile_requested", CANONICAL_PROGRAM)
	var retry_pending: Dictionary = scene.get("_pending_skill_forge_run")
	if retry_pending.is_empty() or str(retry_pending.get("order_id", "")) == replaced_order_id or scene.work_orders.has(replaced_order_id):
		_fail("New compile did not atomically replace the older pending run and order.")
		return
	if not _entries_contain(game_ui.get("_field_log_entries"), "order never completed; replaced by a newer compile"):
		_fail("Replacement did not leave an honest order-never-completed receipt.")
		return
	var replacement_run_id := str(retry_pending.get("run_id", ""))
	scene.call("_finish_pending_skill_forge_run", {
		"forge_run_id": str(replaced_pending.get("run_id", "")),
		"work_order_id": replaced_order_id,
		"action": "clear_brush",
		"grid_pos": brush_tile.grid_pos,
		"success": true
	})
	if str(scene.get("_pending_skill_forge_run").get("run_id", "")) != replacement_run_id:
		_fail("Late completion from the replaced run affected the active verifier.")
		return

	# Ordinary failed attempts requeue and remain pending; explicit cancel is terminal.
	var retry_order_id := str(retry_pending.get("order_id", ""))
	scene.call("_on_agent_world_action", {
		"agent_id": "marigold",
		"agent_name": "Marigold",
		"action": "harvest_crop",
		"grid_pos": ready_tile.grid_pos,
		"success": false,
		"message": "Marigold could not complete the harvest.",
		"resources": {},
		"crafted_cost": {},
		"stamps": [],
		"work_order_id": retry_order_id,
		"forge_run_id": str(retry_pending.get("run_id", "")),
		"skill_name": "Harvest Crops"
	})
	if scene.get("_pending_skill_forge_run").is_empty() or str(scene.work_orders.get(retry_order_id, {}).get("status", "")) != "ready":
		_fail("Failed crew attempt did not requeue while keeping verification pending.")
		return
	scene.call("_on_work_order_cancel_requested", retry_order_id)
	if not scene.get("_pending_skill_forge_run").is_empty() or scene.work_orders.has(retry_order_id):
		_fail("Cancelling the correlated order did not close the pending run and remove the order.")
		return

	placement_tool.set_tool("select")
	placement_tool.call("_apply_to_tile", ready_tile)
	scene.call("_on_workbench_compile_requested", CANONICAL_PROGRAM)
	await process_frame

	var pending: Dictionary = scene.get("_pending_skill_forge_run")
	if pending.is_empty():
		_fail("Canonical program did not create a pending world-verified run.")
		return
	var order_id := str(pending.get("order_id", ""))
	var run_id := str(pending.get("run_id", ""))
	var order: Dictionary = scene.work_orders.get(order_id, {})
	if order.is_empty() or str(order.get("status", "")) != "ready":
		_fail("Canonical program did not draft a ready crew order. order=%s" % str(order))
		return
	if str(order.get("agent_id", "")) != "marigold" or order.get("target_tile", Vector2i(-1, -1)) != ready_tile.grid_pos:
		_fail("Canonical program lost Marigold or the selected tile. order=%s" % str(order))
		return
	if str(order.get("guard_condition", "")) != "crop.ready" or str(order.get("guard_action", "")) != "harvest_crop":
		_fail("Canonical order lost its executable crop.ready guard. order=%s" % str(order))
		return
	if _entries_contain(game_ui.get("_field_log_entries"), "Skill Forge passed Harvest Crops"):
		_fail("Workbench fabricated a pass before the crew changed the world.")
		return

	var grain_before := int(scene.resources.get("grain", 0))
	var harvest_value := int(ready_tile.harvest())
	if harvest_value <= 0:
		_fail("Ready crop could not be harvested while arranging the completion event.")
		return
	scene.call("_on_agent_world_action", {
		"actor": "agent",
		"agent_id": "marigold",
		"agent_name": "Marigold",
		"action": "harvest_crop",
		"grid_pos": ready_tile.grid_pos,
		"success": true,
		"message": "Marigold harvested the selected crop.",
		"value": harvest_value,
		"subject": "corn",
		"resources": {"grain": 1},
		"crafted_cost": {},
		"stamps": [],
		"work_order_id": order_id,
		"forge_run_id": run_id,
		"skill_id": "marigold_harvest_crops",
		"skill_name": "Harvest Crops"
	})
	await process_frame

	if not scene.get("_pending_skill_forge_run").is_empty():
		_fail("Successful crew completion did not close the pending Forge run.")
		return
	if str(scene.work_orders.get(order_id, {}).get("status", "")) != "done":
		_fail("Successful crew completion did not mark the correlated order done.")
		return
	if int(scene.resources.get("grain", 0)) != grain_before + 1:
		_fail("Harvest receipt did not produce the inventory delta used by verification.")
		return
	if not _entries_contain(game_ui.get("_field_log_entries"), "Skill Forge passed Harvest Crops"):
		_fail("Honest post-world-state check did not record a passing receipt.")
		return
	var compiler_output = game_ui.get("_compiler_output") as RichTextLabel
	if compiler_output == null or not compiler_output.text.contains("PASSED") or not compiler_output.text.contains("observed +1 grain"):
		_fail("Workbench trace did not show the verified inventory observation. trace=%s" % (compiler_output.text if compiler_output else ""))
		return

	var empty_tile = _find_empty_tile(grid, ready_tile.grid_pos)
	if empty_tile == null:
		_fail("Starter map did not expose an empty tile for guard blocking.")
		return
	placement_tool.set_tool("select")
	placement_tool.call("_apply_to_tile", empty_tile)
	var order_count_before: int = scene.work_order_ids.size()
	scene.call("_on_workbench_compile_requested", CANONICAL_PROGRAM)
	await process_frame
	if not scene.get("_pending_skill_forge_run").is_empty():
		_fail("crop.ready on an empty tile incorrectly left a pending run.")
		return
	if scene.work_order_ids.size() != order_count_before:
		_fail("crop.ready on an empty tile incorrectly drafted crew work.")
		return
	if compiler_output == null or not compiler_output.text.contains("BLOCKED") or not compiler_output.text.contains("Guard crop.ready blocked at tile") or not compiler_output.text.contains("observed an empty tile"):
		_fail("Blocked Workbench trace did not name the guard, tile, and observation. trace=%s" % (compiler_output.text if compiler_output else ""))
		return
	if runtime_label.text != "BLOCKED  ·  GUARD":
		_fail("Guard-blocked compile left a stale runtime status. status=%s" % runtime_label.text)
		return

	# A valid always guard can still fail order feasibility; that must reach the trace.
	scene.call("_on_workbench_compile_requested", ALWAYS_HARVEST_PROGRAM)
	if not scene.get("_pending_skill_forge_run").is_empty() or compiler_output == null or not compiler_output.text.contains("ORDER BLOCKED"):
		_fail("Validated but infeasible order did not reach the Workbench trace.")
		return
	if runtime_label.text != "FAILED  ·  ORDER BLOCKED":
		_fail("Infeasible order left the Workbench stuck compiling. status=%s" % runtime_label.text)
		return

	# A drafted order that sits for two day advances must fail instead of hanging forever.
	placement_tool.call("_apply_to_tile", brush_tile)
	scene.call("_on_workbench_compile_requested", CLEAR_PROGRAM)
	var timeout_order_id := str(scene.get("_pending_skill_forge_run").get("order_id", ""))
	if timeout_order_id == "":
		_fail("Clear program did not establish the pending run used by timeout coverage.")
		return
	scene.call("_on_advance_day_requested")
	if scene.get("_pending_skill_forge_run").is_empty():
		_fail("Pending run timed out after only one day advance.")
		return
	scene.call("_on_advance_day_requested")
	if not scene.get("_pending_skill_forge_run").is_empty() or scene.work_orders.has(timeout_order_id):
		_fail("Pending run did not fail and clean up after two day advances.")
		return
	if compiler_output == null or not compiler_output.text.contains("order never completed after two day advances"):
		_fail("Timeout failure did not reach the Workbench teaching trace.")
		return

	# Invalid target drift before Send must close with a blocked receipt.
	placement_tool.call("_apply_to_tile", brush_tile)
	scene.call("_on_workbench_compile_requested", CLEAR_PROGRAM)
	var presend_order_id := str(scene.get("_pending_skill_forge_run").get("order_id", ""))
	brush_tile.cut_with_sickle()
	scene.call("_on_work_order_requested", presend_order_id)
	if not scene.get("_pending_skill_forge_run").is_empty() or scene.work_orders.has(presend_order_id):
		_fail("Target drift before Send did not close the correlated pending run.")
		return
	if compiler_output == null or not compiler_output.text.contains("Guard inspect.has_brush blocked at tile"):
		_fail("Pre-Send target drift did not produce the blocked guard receipt.")
		return

	# The named agent also rechecks the guard on arrival, catching drift after Send.
	var runtime_brush_tile = _find_brush_tile(grid)
	if runtime_brush_tile == null:
		_fail("Starter map did not expose a second brush tile for arrival-guard coverage.")
		return
	placement_tool.call("_apply_to_tile", runtime_brush_tile)
	scene.call("_on_workbench_compile_requested", CLEAR_PROGRAM)
	var guarded_pending: Dictionary = scene.get("_pending_skill_forge_run")
	var guarded_order_id := str(guarded_pending.get("order_id", ""))
	var guarded_run_id := str(guarded_pending.get("run_id", ""))
	for actor in scene.get("_agent_manager").agents:
		actor.call("_complete_active_decision")
		actor.set("_decision_timer", 999.0)
		actor.move_speed = 60.0
	scene.call("_on_work_order_requested", guarded_order_id)
	var chuck_claimed_run := false
	for actor in scene.get("_agent_manager").agents:
		var active: Dictionary = actor.get("_active_decision")
		if str(active.get("forge_run_id", "")) != guarded_run_id:
			continue
		chuck_claimed_run = str(actor.agent_id) == "chuck"
	if not chuck_claimed_run:
		_fail("Typed agent Chuck did not receive the correlated Workbench order.")
		return
	runtime_brush_tile.cut_with_sickle()
	for _frame in range(240):
		if scene.get("_pending_skill_forge_run").is_empty():
			break
		await process_frame
	if not scene.get("_pending_skill_forge_run").is_empty() or scene.work_orders.has(guarded_order_id):
		_fail("Arrival-time guard did not block and clean up after the target changed.")
		return
	if compiler_output == null or not compiler_output.text.contains("Guard inspect.has_brush blocked at tile"):
		_fail("Arrival-time guard failure did not reach the Workbench trace.")
		return

	scene.queue_free()
	await process_frame
	quit()


func _find_ready_crop(grid):
	for tile in grid.tiles.values():
		if tile.crop != null and tile.crop.is_ready():
			return tile
	return null


func _find_empty_tile(grid, excluded: Vector2i):
	for tile in grid.tiles.values():
		if tile.grid_pos == excluded:
			continue
		if tile.crop == null and str(tile.decor_id) == "" and str(tile.structure_id) == "":
			return tile
	return null


func _find_brush_tile(grid):
	for tile in grid.tiles.values():
		if str(tile.decor_id) in ["tall_grass", "flower_patch"]:
			return tile
	return null


func _entries_contain(entries, needle: String) -> bool:
	if typeof(entries) != TYPE_ARRAY:
		return false
	for entry in entries:
		if str(entry).contains(needle):
			return true
	return false


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
