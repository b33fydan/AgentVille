extends SceneTree

const OUTPUT_PATH := "res://artifacts/screenshots/agentville-spring-hands-perk.png"


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
	target_tile.till()

	scene.call("_create_crafting_demand", {
		"kind": "deliver_item",
		"required_item": "seed_bundle",
		"amount": 1,
		"label": "Deliver Seed Bundle",
		"reason": "Marigold wants seed stock with visible farm payoff."
	}, {
		"agent_id": "marigold",
		"agent_name": "Marigold"
	})
	scene.call("_add_resources", {
		"grain": 2
	})
	scene.call("_on_craft_requested", "seed_bundle")
	await process_frame

	var camera_controller = scene.get("camera_controller")
	if camera_controller != null and camera_controller.has_method("focus_world_position"):
		camera_controller.call("focus_world_position", target_tile.global_position, 6.8)

	await create_timer(0.24).timeout

	var image := root.get_texture().get_image()
	image.save_png(OUTPUT_PATH)
	quit()
