extends SceneTree

const OUTPUT_PATH := "res://artifacts/screenshots/agentville-crafting.png"


func _initialize() -> void:
	root.size = Vector2i(1600, 900)
	call_deferred("_capture")


func _capture() -> void:
	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)

	await process_frame
	await process_frame

	scene.call("_add_resources", {
		"fiber": 2,
		"grain": 1,
		"stone": 1
	})
	scene.call("_on_craft_requested", "fence_kit")

	await create_timer(0.25).timeout

	var image := root.get_texture().get_image()
	image.save_png(OUTPUT_PATH)
	quit()
