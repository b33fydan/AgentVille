extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	scene.call("_add_resources", {
		"fiber": 2,
		"grain": 1
	})
	scene.call("_on_craft_requested", "fence_kit")

	await process_frame

	if int(scene.resources.get("fiber", 0)) != 0:
		_fail("Fence Kit craft did not spend fiber.")
		return
	if int(scene.resources.get("grain", 0)) != 0:
		_fail("Fence Kit craft did not spend grain.")
		return
	if int(scene.crafted_items.get("fence_kit", 0)) != 1:
		_fail("Fence Kit craft did not add crafted inventory.")
		return

	await create_timer(0.6).timeout
	quit()


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
