extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var grid = scene.get_node("FarmWorld/GridManager")
	var agent_manager = scene.get_node("FarmWorld/AgentManager")
	var agent = agent_manager.agents[0]
	agent.move_speed = 18.0

	var start_money: int = scene.money
	var start_grain: int = int(scene.resources.get("grain", 0))
	var start_fiber: int = int(scene.resources.get("fiber", 0))
	var ready_tile = grid.get_tile(Vector2i(2, 5))
	if ready_tile.crop:
		ready_tile.crop.setup("corn", 3)
	else:
		_fail("Smoke setup expected a crop at (2,5).")
		return

	agent.call("_start_decision", {
		"action": "harvest_crop",
		"reason": "smoke test ready crop",
		"score": 100.0,
		"target_tile": ready_tile.grid_pos
	})

	await create_timer(0.9).timeout
	if ready_tile.crop != null:
		_fail("Agent did not harvest the ready crop.")
		return
	if int(scene.money) <= start_money:
		_fail("Agent harvest did not add coins.")
		return
	if int(scene.resources.get("grain", 0)) <= start_grain:
		_fail("Agent harvest did not add grain.")
		return

	var brush_tile = grid.get_tile(Vector2i(0, 1))
	if str(brush_tile.decor_id) != "tall_grass":
		brush_tile.place_item("tall_grass")

	agent.call("_start_decision", {
		"action": "clear_brush",
		"reason": "smoke test brush",
		"score": 100.0,
		"target_tile": brush_tile.grid_pos
	})

	await create_timer(0.9).timeout
	if str(brush_tile.decor_id) != "":
		_fail("Agent did not clear brush.")
		return
	if int(scene.resources.get("fiber", 0)) <= start_fiber:
		_fail("Agent brush clearing did not add fiber.")
		return

	await create_timer(0.8).timeout
	root.remove_child(scene)
	scene.queue_free()
	await process_frame
	quit()


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
