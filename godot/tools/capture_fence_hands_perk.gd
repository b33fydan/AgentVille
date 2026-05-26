extends SceneTree

const OUTPUT_PATH := "res://artifacts/screenshots/agentville-fence-hands-perk.png"


func _initialize() -> void:
	root.size = Vector2i(1600, 900)
	call_deferred("_capture")


func _capture() -> void:
	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)

	await process_frame
	await process_frame

	var grid = scene.get_node("FarmWorld/GridManager")
	var target_tile = grid.get_tile(Vector2i(0, 0))

	scene.call("_create_crafting_demand", {
		"kind": "deliver_item",
		"required_item": "fence_kit",
		"amount": 1,
		"label": "Deliver Fence Kit",
		"reason": "Bert wants the kit to become actual fence."
	}, {
		"agent_id": "bert",
		"agent_name": "Bert"
	})
	scene.call("_add_resources", {
		"fiber": 2,
		"grain": 1
	})
	scene.call("_on_craft_requested", "fence_kit")
	await process_frame

	var camera_controller = scene.get("camera_controller")
	if camera_controller != null and camera_controller.has_method("focus_world_position"):
		camera_controller.call("focus_world_position", target_tile.global_position, 6.8)

	await create_timer(0.24).timeout

	var image := root.get_texture().get_image()
	image.save_png(OUTPUT_PATH)
	quit()
