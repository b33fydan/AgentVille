extends SceneTree

const OUTPUT_PATH := "res://artifacts/screenshots/agentville-current.png"


func _initialize() -> void:
	root.size = Vector2i(1600, 900)
	call_deferred("_capture")


func _capture() -> void:
	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)

	await process_frame
	await process_frame
	# Fallback-only runs construct more procedural voxel meshes than pack-backed runs.
	# Give Metal several fully presented frames before reading the root viewport.
	await create_timer(1.6).timeout
	for frame in range(8):
		await RenderingServer.frame_post_draw
		await process_frame

	var image := root.get_texture().get_image()
	if image == null:
		push_error("Screenshot capture could not read the rendered viewport texture.")
		quit(1)
		return
	image.save_png(OUTPUT_PATH)
	quit()
