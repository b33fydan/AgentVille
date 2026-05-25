extends SceneTree

const OUTPUT_PATH := "res://artifacts/screenshots/agentville-work-order.png"


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
		agent.move_speed = 12.0

	scene.call("_add_resources", {
		"fiber": 2,
		"grain": 1
	})
	scene.call("_on_work_order_tool_selected", "build_fence")
	scene.call("_on_crew_order_targeted", "build_fence", Vector2i(6, 5))
	scene.call("_on_crew_order_targeted", "build_fence", Vector2i(6, 2))
	scene.call("_on_crew_order_targeted", "clear_brush", Vector2i(0, 1))

	await create_timer(0.48).timeout

	var image := root.get_texture().get_image()
	image.save_png(OUTPUT_PATH)
	quit()
