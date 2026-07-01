extends SceneTree

const OUTPUT_PATH := "res://artifacts/screenshots/agentville-megavox-starter-map.png"


func _initialize() -> void:
	root.size = Vector2i(1600, 900)
	call_deferred("_capture")


func _capture() -> void:
	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)

	await process_frame
	await process_frame

	var game_ui = scene.get_node_or_null("GameUI")
	if game_ui != null:
		game_ui.visible = false

	var camera_controller = scene.get_node_or_null("CameraController")
	if camera_controller != null:
		camera_controller.call("center_on_farm")
		if camera_controller.camera != null:
			camera_controller.camera.size = 9.2
			camera_controller.call("_apply_transform")

	await create_timer(0.45).timeout

	var viewport_texture := root.get_texture()
	if viewport_texture == null:
		_fail("Could not capture MEGAVOX starter map: viewport texture is unavailable.")
		return

	var image := viewport_texture.get_image()
	if image == null:
		_fail("Could not capture MEGAVOX starter map: viewport image is unavailable.")
		return

	var error := image.save_png(OUTPUT_PATH)
	if error != OK:
		_fail("Could not save MEGAVOX starter map capture to %s." % OUTPUT_PATH)
		return

	quit()


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
