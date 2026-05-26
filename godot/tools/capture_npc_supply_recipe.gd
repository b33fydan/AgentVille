extends SceneTree

const OUTPUT_PATH := "res://artifacts/screenshots/agentville-npc-supply-recipe.png"


func _initialize() -> void:
	root.size = Vector2i(1600, 900)
	call_deferred("_capture")


func _capture() -> void:
	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)

	await process_frame
	await process_frame

	scene.call("_queue_adversarial_grievance", "marigold", "Marigold wants a gentler recovery supply.", {
		"demand_hint": "deliver_agent_supply",
		"grievance_text": "The farm needs seed stock before the next grand repair speech.",
		"npc_goal": "turn the apology into a Seed Bundle"
	})
	scene.call("_on_adversarial_encounter_requested", "")
	await process_frame
	scene.call("_on_adversarial_response_selected", "own_mistake")
	await process_frame
	scene.call("_on_adversarial_response_selected", "own_mistake")
	await process_frame
	scene.call("_add_resources", {
		"grain": 2
	})

	await create_timer(0.24).timeout

	var image := root.get_texture().get_image()
	image.save_png(OUTPUT_PATH)
	quit()
