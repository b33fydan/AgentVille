extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_reason_badge_has_readable_plate()
	await _test_reason_badge_pops_when_motive_changes()
	quit()


func _test_reason_badge_has_readable_plate() -> void:
	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var marigold = _agent_actor(scene, "marigold")
	if marigold == null:
		_fail("Could not find Marigold for reason-badge polish check.")
		return

	var badge = marigold.get_node_or_null("VoxelRig/ReasonBadge")
	var plate = marigold.get_node_or_null("VoxelRig/ReasonBadgePlate")
	if badge == null or plate == null:
		_fail("Reason badge did not include both text and backing plate nodes.")
		return
	if not badge.visible or not plate.visible:
		_fail("Reason badge plate/text were not visible for the idle plan.")
		return
	if int(badge.outline_size) < 4:
		_fail("Reason badge text outline is too thin for in-world readability.")
		return

	scene.queue_free()
	await process_frame


func _test_reason_badge_pops_when_motive_changes() -> void:
	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var bert = _agent_actor(scene, "bert")
	if bert == null:
		_fail("Could not find Bert for reason-badge pop check.")
		return

	bert.call("start_directive", "clear_brush", Vector2i(1, 1), "memory work", {
		"social_preference_source": "memory",
		"social_preference_label": "Seed Bundle"
	})
	await process_frame

	var badge = bert.get_node_or_null("VoxelRig/ReasonBadge")
	var plate = bert.get_node_or_null("VoxelRig/ReasonBadgePlate")
	if badge == null or plate == null:
		_fail("Reason badge pop check could not find badge nodes.")
		return
	if str(badge.text) != "Memory":
		_fail("Reason badge did not switch to Memory before pop check.")
		return
	if float(badge.scale.x) <= 1.0 and float(plate.scale.x) <= 1.0:
		_fail("Reason badge did not pop when the active motive changed.")
		return

	scene.queue_free()
	await process_frame


func _agent_actor(scene: Node, agent_id: String):
	var agent_manager = scene.get_node("FarmWorld/AgentManager")
	for agent in agent_manager.agents:
		if str(agent.get("agent_id")) == agent_id:
			return agent
	return null


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
