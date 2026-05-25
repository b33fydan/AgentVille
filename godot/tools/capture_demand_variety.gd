extends SceneTree

const OUTPUT_PATH := "res://artifacts/screenshots/agentville-demand-variety.png"


func _initialize() -> void:
	root.size = Vector2i(1600, 900)
	call_deferred("_capture")


func _capture() -> void:
	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)

	await process_frame
	await process_frame

	scene.call("_queue_adversarial_grievance", "bert", "Bert wants brush cleared before the fence parade continues.", {
		"demand_hint": "clear_brush",
		"grievance_text": "The brush is winning the visual argument.",
		"npc_goal": "make the player clear one patch of brush"
	})
	scene.call("_on_adversarial_encounter_requested", "")
	await process_frame
	scene.call("_on_adversarial_response_selected", "own_mistake")
	await process_frame
	scene.call("_on_adversarial_response_selected", "own_mistake")
	await process_frame
	scene.call("_on_advance_day_requested")

	await create_timer(0.24).timeout

	var image := root.get_texture().get_image()
	image.save_png(OUTPUT_PATH)
	quit()
