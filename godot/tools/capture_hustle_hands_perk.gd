extends SceneTree

const OUTPUT_PATH := "res://artifacts/screenshots/agentville-hustle-hands-perk.png"


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
	target_tile.place_item("rock")

	scene.call("_create_crafting_demand", {
		"kind": "deliver_item",
		"required_item": "rush_kit",
		"amount": 1,
		"label": "Deliver Rush Kit",
		"reason": "Chuck wants speed in a box."
	}, {
		"agent_id": "chuck",
		"agent_name": "Chuck"
	})
	scene.call("_add_resources", {
		"fiber": 1,
		"stone": 1
	})
	scene.call("_on_craft_requested", "rush_kit")
	await process_frame

	var camera_controller = scene.get("camera_controller")
	if camera_controller != null and camera_controller.has_method("focus_world_position"):
		camera_controller.call("focus_world_position", target_tile.global_position, 6.8)

	await create_timer(0.24).timeout

	var image := root.get_texture().get_image()
	image.save_png(OUTPUT_PATH)
	quit()
