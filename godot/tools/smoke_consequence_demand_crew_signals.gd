extends SceneTree

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_consequence_demands_surface_source_in_crew_rows()
	if not _failed:
		quit()


func _test_consequence_demands_surface_source_in_crew_rows() -> void:
	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var game_ui = scene.get_node("GameUI")
	game_ui.set_crafting_demands([
		_demand("mission_seed", "marigold", "Marigold", "Deliver Seed Bundle", "completed_mission", "Marigold Growth Run"),
		_demand("pressure_rush", "chuck", "Chuck", "Deliver Rush Kit", "ignored_ask", "Rush Kit"),
		_demand("follow_fence", "bert", "Bert", "Deliver Fence Kit", "completed_order", "Build Fence")
	])
	await process_frame

	_assert_crew_signal(scene, "marigold", "Mission", "Deliver Seed Bundle")
	_assert_crew_signal(scene, "chuck", "Pressure", "Deliver Rush Kit")
	_assert_crew_signal(scene, "bert", "Follow-up", "Deliver Fence Kit")
	if _failed:
		return

	game_ui.set_crafting_demands([
		_demand("streak_seed", "marigold", "Marigold", "Deliver Seed Bundle", "repeated_help", "Seed Bundle"),
		_demand("held_fence", "bert", "Bert", "Build Fence", "held_truce", "Fence Kit")
	])
	await process_frame

	_assert_crew_signal(scene, "marigold", "Streak", "Deliver Seed Bundle")
	_assert_crew_signal(scene, "bert", "Held", "Build Fence")
	if _failed:
		return

	scene.queue_free()
	await process_frame


func _demand(demand_id: String, agent_id: String, agent_name: String, label: String, preference_source: String, preference_label: String) -> Dictionary:
	return {
		"id": demand_id,
		"status": "open",
		"status_text": "Needs attention",
		"kind": "deliver_item",
		"required_item": "seed_bundle",
		"amount": 1,
		"label": label,
		"agent_id": agent_id,
		"agent_name": agent_name,
		"preference_source": preference_source,
		"preference_label": preference_label
	}


func _assert_crew_signal(scene: Node, agent_id: String, prefix: String, demand_label: String) -> void:
	if _failed:
		return
	var social_label := _crew_social_label(scene, agent_id)
	if social_label == null or not social_label.visible:
		_fail("%s did not expose a consequence demand crew signal." % agent_id)
		return
	var text := str(social_label.text)
	if not text.contains(prefix) or not text.contains(demand_label):
		_fail("%s crew signal did not show %s context for %s. saw=%s" % [agent_id, prefix, demand_label, text])
		return
	if text.contains("Wants"):
		_fail("%s consequence demand crew signal fell back to generic Wants. saw=%s" % [agent_id, text])


func _crew_social_label(scene: Node, agent_id: String) -> Label:
	var game_ui = scene.get_node("GameUI")
	var rows: Dictionary = game_ui.get("_crew_rows")
	if not rows.has(agent_id):
		return null
	var row: Dictionary = rows[agent_id]
	return row.get("social", null) as Label


func _fail(message: String) -> void:
	_failed = true
	push_error(message)
	quit(1)
