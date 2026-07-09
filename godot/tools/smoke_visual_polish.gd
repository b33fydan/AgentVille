extends SceneTree

var _failed: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_reference_render_profile()
	if _failed:
		return
	await _test_reason_badge_has_readable_plate()
	if _failed:
		return
	await _test_reason_badge_pops_when_motive_changes()
	if not _failed:
		quit()


func _test_reference_render_profile() -> void:
	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var world_environment := scene.get_node_or_null("WorldEnvironment") as WorldEnvironment
	var sun := scene.get_node_or_null("WarmSun") as DirectionalLight3D
	var fill := scene.get_node_or_null("SoftFill") as OmniLight3D
	if world_environment == null or world_environment.environment == null:
		_fail("Reference render profile did not create a world environment.")
		return
	if sun == null or fill == null:
		_fail("Reference render profile did not create its sun and fill lights.")
		return

	var environment := world_environment.environment
	if environment.ambient_light_energy > 0.55:
		_fail("Reference render profile ambient light is bright enough to wash out voxel facets.")
		return
	if not environment.ssao_enabled or environment.ssao_intensity < 1.20:
		_fail("Reference render profile needs strong ambient occlusion for voxel depth.")
		return
	if sun.light_energy < 1.10 or sun.light_energy > 1.60:
		_fail("Reference render profile sun energy left the contrast-safe range.")
		return
	if fill.light_energy > 0.12:
		_fail("Reference render profile fill light is bright enough to flatten shadows.")
		return
	if float(environment.get("adjustment_brightness")) > 0.98:
		_fail("Reference render profile brightness is high enough to reintroduce washout.")
		return
	if float(environment.get("adjustment_contrast")) < 1.08:
		_fail("Reference render profile contrast is too low for readable voxel silhouettes.")
		return
	if bool(environment.get("fog_enabled")):
		_fail("Reference render profile re-enabled the global fog wash.")
		return
	if scene.get_node_or_null("WorldHazeWash") != null:
		_fail("Reference render profile reintroduced the full-screen haze wash.")
		return

	scene.queue_free()
	await process_frame


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
	_failed = true
	push_error(message)
	quit(1)
