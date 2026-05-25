extends SceneTree

const OUTPUT_PATH := "res://artifacts/screenshots/agentville-adversarial-reaction.png"


func _initialize() -> void:
	root.size = Vector2i(1600, 900)
	call_deferred("_capture")


func _capture() -> void:
	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)

	await process_frame
	await process_frame

	var agent_manager = scene.get_node("FarmWorld/AgentManager")
	for agent in agent_manager.agents:
		agent.move_speed = 8.0

	for index in range(9):
		scene.call("_on_player_action_logged", {
			"actor": "player",
			"tool": "place",
			"action": "place",
			"grid_pos": Vector2i(index % 3, index / 3),
			"item_id": "fence",
			"success": false,
			"message": "Cannot place that here.",
			"value": 0,
			"resources": {},
			"crafted_cost": {}
		})
		await process_frame

	await create_timer(0.35).timeout

	var image := root.get_texture().get_image()
	image.save_png(OUTPUT_PATH)
	quit()
