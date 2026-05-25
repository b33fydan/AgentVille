extends SceneTree

const OUTPUT_PATH := "res://artifacts/screenshots/agentville-adversarial-session.png"


func _initialize() -> void:
	root.size = Vector2i(1600, 900)
	call_deferred("_capture")


func _capture() -> void:
	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)

	await process_frame
	await process_frame

	for index in range(3):
		scene.call("_on_player_action_logged", {
			"actor": "player",
			"tool": "place",
			"action": "place",
			"grid_pos": Vector2i(index, 0),
			"item_id": "fence",
			"success": false,
			"message": "Cannot place that here.",
			"value": 0,
			"resources": {},
			"crafted_cost": {}
		})
		await process_frame

	scene.call("_on_adversarial_encounter_requested", "")
	await create_timer(0.22).timeout

	var image := root.get_texture().get_image()
	image.save_png(OUTPUT_PATH)
	quit()
