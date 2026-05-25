extends SceneTree

const OUTPUT_PATH := "res://artifacts/screenshots/agentville-npc-work.png"


func _initialize() -> void:
	root.size = Vector2i(1600, 900)
	call_deferred("_capture")


func _capture() -> void:
	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)

	await process_frame
	await process_frame

	var grid = scene.get_node("FarmWorld/GridManager")
	var agent_manager = scene.get_node("FarmWorld/AgentManager")
	var agent = agent_manager.agents[0]
	agent.move_speed = 12.0

	var ready_tile = grid.get_tile(Vector2i(2, 5))
	if ready_tile.crop:
		ready_tile.crop.setup("corn", 3)

	agent.call("_start_decision", {
		"action": "harvest_crop",
		"reason": "capture ready crop",
		"score": 100.0,
		"target_tile": ready_tile.grid_pos
	})

	await create_timer(0.35).timeout

	var image := root.get_texture().get_image()
	image.save_png(OUTPUT_PATH)
	quit()
