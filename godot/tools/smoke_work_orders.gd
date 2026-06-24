extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var grid = scene.get_node("FarmWorld/GridManager")
	var placement_tool = scene.get_node("PlacementTool")
	var agent_manager = scene.get_node("FarmWorld/AgentManager")
	for agent in agent_manager.agents:
		agent.move_speed = 24.0

	var blocked_tile = grid.get_tile(Vector2i(0, 0))
	placement_tool.call("set_tool", "place")
	placement_tool.call("set_selected_item", "fence")
	placement_tool.call("_apply_to_tile", blocked_tile)
	await process_frame

	if str(blocked_tile.decor_id) == "fence":
		_fail("Fence placement succeeded without a Fence Kit.")
		return

	scene.call("_add_resources", {
		"fiber": 2,
		"grain": 1
	})
	scene.call("_on_craft_requested", "fence_kit")
	await process_frame

	if int(scene.crafted_items.get("fence_kit", 0)) != 1:
		_fail("Smoke setup did not craft a Fence Kit.")
		return

	var player_tile = grid.get_tile(Vector2i(0, 0))
	placement_tool.call("_apply_to_tile", player_tile)
	await process_frame

	if str(player_tile.decor_id) != "fence":
		_fail("Player fence placement did not place a fence.")
		return
	if int(scene.crafted_items.get("fence_kit", 0)) != 0:
		_fail("Player fence placement did not consume one Fence Kit.")
		return

	scene.call("_add_resources", {
		"fiber": 2,
		"grain": 1
	})
	scene.call("_on_crew_order_targeted", "build_fence", Vector2i(4, 5))
	scene.call("_on_crew_order_targeted", "build_fence", Vector2i(6, 2))
	if not grid.get_tile(Vector2i(4, 5)).get_node("OrderMarker").visible:
		_fail("Marked fence order did not show an in-world marker.")
		return
	if not grid.get_tile(Vector2i(6, 2)).get_node("OrderMarker").visible:
		_fail("Second marked fence order did not show an in-world marker.")
		return
	await create_timer(2.9).timeout

	var crafted_order_id := str(scene.work_order_ids[0])
	var gathered_order_id := str(scene.work_order_ids[1])
	var crafted_order: Dictionary = scene.work_orders[crafted_order_id]
	var crafted_order_tile = grid.get_tile(crafted_order["target_tile"])
	if str(crafted_order_tile.decor_id) != "fence":
		_fail("Crew did not craft-and-build the marked fence order.")
		return
	if int(scene.crafted_items.get("fence_kit", 0)) != 0:
		_fail("Marked fence order left an extra Fence Kit.")
		return
	if str(crafted_order.get("status", "")) != "done":
		_fail("Marked fence order was not marked done.")
		return
	if crafted_order_tile.get_node("OrderMarker").visible:
		_fail("Completed fence order marker stayed visible.")
		return
	scene.call("_on_work_order_cancel_requested", crafted_order_id)
	await process_frame
	if scene.work_orders.has(crafted_order_id):
		_fail("Completed fence order was not cleared from the order list.")
		return

	var gathered_order: Dictionary = scene.work_orders[gathered_order_id]
	var gathered_order_tile = grid.get_tile(gathered_order["target_tile"])
	if str(gathered_order_tile.decor_id) != "fence":
		_fail("Crew did not gather-craft-build the marked fence order. status=%s kits=%s fiber=%s grain=%s decor=%s" % [
			str(gathered_order.get("status", "")),
			int(scene.crafted_items.get("fence_kit", 0)),
			int(scene.resources.get("fiber", 0)),
			int(scene.resources.get("grain", 0)),
			str(gathered_order_tile.decor_id)
		])
		return
	if str(gathered_order.get("status", "")) != "done":
		_fail("Gathered fence order was not marked done.")
		return

	var blocked_order_target := Vector2i(0, 3)
	var blocked_order_id := str(scene.call("_create_user_work_order", "build_fence", blocked_order_target))
	var blocked_order_tile = grid.get_tile(blocked_order_target)
	blocked_order_tile.place_item("barn")
	scene.call("_refresh_work_orders")
	scene.call("_on_work_order_cancel_requested", blocked_order_id)
	await process_frame
	if scene.work_orders.has(blocked_order_id):
		_fail("Dropped blocked order stayed in the order list.")
		return
	if blocked_order_tile.get_node("OrderMarker").visible:
		_fail("Dropped blocked order marker stayed visible.")
		return

	var clear_target := Vector2i(0, 1)
	var clear_tile = grid.get_tile(clear_target)
	clear_tile.place_item("tall_grass")
	scene.call("_on_crew_order_targeted", "clear_brush", clear_target)
	if not clear_tile.get_node("OrderMarker").visible:
		_fail("Clear order did not show an in-world marker.")
		return
	await create_timer(0.9).timeout

	var clear_order_id := str(scene.work_order_ids.back())
	var clear_order: Dictionary = scene.work_orders[clear_order_id]
	if str(clear_tile.decor_id) != "":
		_fail("Crew clear order did not remove brush.")
		return
	if str(clear_order.get("status", "")) != "done":
		_fail("Crew clear order was not marked done.")
		return
	if clear_tile.get_node("OrderMarker").visible:
		_fail("Completed clear order marker stayed visible.")
		return

	var harvest_target := Vector2i(1, 6)
	var harvest_tile = grid.get_tile(harvest_target)
	harvest_tile.erase()
	harvest_tile.till()
	harvest_tile.plant_corn()
	harvest_tile.crop.setup("corn", 3)
	scene.call("_on_crew_order_targeted", "harvest_crop", harvest_target)
	if not harvest_tile.get_node("OrderMarker").visible:
		_fail("Harvest order did not show an in-world marker.")
		return
	await create_timer(0.9).timeout

	var harvest_order_id := str(scene.work_order_ids.back())
	var harvest_order: Dictionary = scene.work_orders[harvest_order_id]
	if harvest_tile.crop != null:
		_fail("Crew harvest order did not harvest the ready crop.")
		return
	if str(harvest_order.get("status", "")) != "done":
		_fail("Crew harvest order was not marked done.")
		return
	if harvest_tile.get_node("OrderMarker").visible:
		_fail("Completed harvest order marker stayed visible.")
		return

	var plant_target := Vector2i(1, 0)
	var plant_tile = grid.get_tile(plant_target)
	plant_tile.erase()
	scene.call("_on_crew_order_targeted", "plant_seed", plant_target)
	if not plant_tile.get_node("OrderMarker").visible:
		_fail("Plant order did not show an in-world marker.")
		return
	await create_timer(0.9).timeout

	var plant_order_id := str(scene.work_order_ids.back())
	var plant_order: Dictionary = scene.work_orders[plant_order_id]
	if plant_tile.crop == null:
		_fail("Crew plant order did not plant a crop.")
		return
	if not plant_tile.is_tilled:
		_fail("Crew plant order did not leave tilled soil.")
		return
	if str(plant_order.get("status", "")) != "done":
		_fail("Crew plant order was not marked done.")
		return
	if plant_tile.get_node("OrderMarker").visible:
		_fail("Completed plant order marker stayed visible.")
		return

	await create_timer(0.6).timeout
	quit()


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
