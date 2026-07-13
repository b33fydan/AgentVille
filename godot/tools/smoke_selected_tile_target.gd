extends SceneTree

const CANONICAL_PROGRAM := "agent \"Marigold\" {\n  observe selected_tile\n  when crop.ready {\n    use harvest_crop(selected_tile)\n  }\n  verify inventory_delta\n  receipt \"Harvest Crops run\"\n}"


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
	var ready_tile = _find_ready_crop(grid)
	if ready_tile == null:
		_fail("Starter map did not expose a ready crop for target resolution.")
		return

	placement_tool.set_tool("select")
	placement_tool.call("_apply_to_tile", ready_tile)
	placement_tool.set_tool("pan")
	if placement_tool.get_selected_grid_pos() != ready_tile.grid_pos:
		_fail("Changing navigation tools cleared the persistent Workbench target.")
		return
	if scene.call("_skill_forge_target_for_template", "harvest_crops_starter") != ready_tile.grid_pos:
		_fail("Template target resolution did not prefer the persistent selected tile.")
		return

	scene.call("_on_workbench_compile_requested", CANONICAL_PROGRAM)
	await process_frame
	var pending: Dictionary = scene.get("_pending_skill_forge_run")
	var order: Dictionary = scene.work_orders.get(str(pending.get("order_id", "")), {})
	if order.get("target_tile", Vector2i(-1, -1)) != ready_tile.grid_pos:
		_fail("Compiled selected_tile did not become the crew order target. pending=%s order=%s" % [str(pending), str(order)])
		return
	if str(pending.get("target_source", "")) != "selected_tile":
		_fail("Compiled run did not label the resolved target as selected_tile.")
		return

	scene.call("_cancel_pending_skill_forge_run", "order never completed; selected-target smoke cleanup", true)
	placement_tool.clear_selected_tile()
	var fallback: Vector2i = scene.call("_skill_forge_target_for_template", "harvest_crops_starter")
	if fallback == Vector2i(-1, -1) or grid.get_tile(fallback) == null:
		_fail("No-selection path did not retain a valid starter fallback target.")
		return

	scene.queue_free()
	await process_frame
	quit()


func _find_ready_crop(grid):
	for tile in grid.tiles.values():
		if tile.crop != null and tile.crop.is_ready():
			return tile
	return null


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
