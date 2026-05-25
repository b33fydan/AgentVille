extends SceneTree

const OUTPUT_PATH := "res://artifacts/screenshots/agentville-npc-escalation-bargain.png"


func _initialize() -> void:
	root.size = Vector2i(1600, 900)
	call_deferred("_capture")


func _capture() -> void:
	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)

	await process_frame
	await process_frame

	var demand_id := str(scene.call("_create_crafting_demand", {
		"kind": "clear_brush",
		"required_action": "clear_brush",
		"amount": 1,
		"label": "Clear Brush"
	}, {
		"agent_id": "bert",
		"agent_name": "Bert"
	}))

	scene.call("_on_advance_day_requested")
	await process_frame
	scene.call("_on_advance_day_requested")
	await process_frame
	scene.call("_on_crafting_demand_target_requested", demand_id)

	await create_timer(0.18).timeout

	var image := root.get_texture().get_image()
	image.save_png(OUTPUT_PATH)
	quit()
