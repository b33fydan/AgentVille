extends SceneTree

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_consequence_context_surfaces_while_agents_are_active()
	if not _failed:
		quit()


func _test_consequence_context_surfaces_while_agents_are_active() -> void:
	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var marigold = _agent_actor(scene, "marigold")
	var chuck = _agent_actor(scene, "chuck")
	var bert = _agent_actor(scene, "bert")
	if marigold == null or chuck == null or bert == null:
		_fail("Could not find all crew actors for consequence active-work signal check.")
		return

	marigold.call("start_directive", "clear_brush", Vector2i(1, 1), "mission momentum work", {
		"social_preference_source": "completed_mission",
		"social_preference_label": "Marigold Growth Run"
	})
	chuck.call("start_directive", "clear_brush", Vector2i(2, 1), "pressure work", {
		"social_preference_source": "ignored_ask",
		"social_preference_label": "Rush Kit"
	})
	bert.call("start_directive", "build_fence_order", Vector2i(3, 1), "follow-up work", {
		"social_preference_source": "completed_order",
		"social_preference_label": "Build Fence"
	})

	var game_ui = scene.get_node("GameUI")
	var agent_manager = scene.get_node("FarmWorld/AgentManager")
	game_ui.set_agent_snapshots(agent_manager.call("get_agent_snapshots"))
	marigold.call("_refresh_reason_badge")
	chuck.call("_refresh_reason_badge")
	bert.call("_refresh_reason_badge")
	await process_frame

	_assert_crew_signal(scene, "marigold", "Momentum work", "Marigold Growth Run")
	_assert_badge(marigold, "Momentum")
	_assert_crew_signal(scene, "chuck", "Pressure work", "Rush Kit")
	_assert_badge(chuck, "Pressure")
	_assert_crew_signal(scene, "bert", "Follow-up work", "Build Fence")
	_assert_badge(bert, "Follow")
	if _failed:
		return

	marigold.call("start_directive", "clear_brush", Vector2i(4, 1), "streak work", {
		"social_preference_source": "repeated_help",
		"social_preference_label": "Seed Bundle"
	})
	bert.call("start_directive", "build_fence_order", Vector2i(5, 1), "held truce work", {
		"social_preference_source": "held_truce",
		"social_preference_label": "Fence Kit"
	})
	game_ui.set_agent_snapshots(agent_manager.call("get_agent_snapshots"))
	marigold.call("_refresh_reason_badge")
	bert.call("_refresh_reason_badge")
	await process_frame

	_assert_crew_signal(scene, "marigold", "Streak work", "Seed Bundle")
	_assert_badge(marigold, "Streak")
	_assert_crew_signal(scene, "bert", "Held work", "Fence Kit")
	_assert_badge(bert, "Held")
	if _failed:
		return

	scene.queue_free()
	await process_frame


func _agent_actor(scene: Node, agent_id: String):
	var agent_manager = scene.get_node("FarmWorld/AgentManager")
	for agent in agent_manager.agents:
		if str(agent.get("agent_id")) == agent_id:
			return agent
	return null


func _assert_crew_signal(scene: Node, agent_id: String, prefix: String, label: String) -> void:
	if _failed:
		return
	var social_label := _crew_social_label(scene, agent_id)
	if social_label == null or not social_label.visible:
		_fail("%s did not expose active consequence work context." % agent_id)
		return
	var text := str(social_label.text)
	if not text.contains(prefix) or not text.contains(label):
		_fail("%s active consequence work signal did not show %s / %s. saw=%s" % [agent_id, prefix, label, text])
		return
	if text.contains("Memory work"):
		_fail("%s active consequence work fell back to generic Memory work. saw=%s" % [agent_id, text])


func _assert_badge(agent, expected_text: String) -> void:
	if _failed:
		return
	var badge = agent.get_node_or_null("VoxelRig/ReasonBadge")
	if badge == null or not badge.visible or str(badge.text) != expected_text:
		_fail("%s did not show the %s active consequence badge." % [str(agent.get("agent_id")), expected_text])


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
