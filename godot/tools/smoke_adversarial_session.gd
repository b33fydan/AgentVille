extends SceneTree

const AdversarialSessionManagerScript := preload("res://scripts/ai/AdversarialSessionManager.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_session_model_loss()
	_test_session_model_resolution()
	await _test_scene_integration()
	quit()


func _test_session_model_loss() -> void:
	var manager = AdversarialSessionManagerScript.new()
	var session: Dictionary = manager.start_session({
		"id": "bert",
		"name": "Bert",
		"trait": "grizzled",
		"irritation": 60.0
	}, {
		"day": 1,
		"recent_failures": 4,
		"top_failed_action": "place"
	})

	if not bool(session.get("active", false)):
		_fail("Adversarial session did not start active.")
		return
	if float(session.get("patience_meter", 100.0)) >= 55.0:
		_fail("High irritation and failures did not lower starting patience.")
		return
	if str(session.get("npc_goal", "")) == "" or str(session.get("player_goal", "")) == "":
		_fail("Session did not track NPC/player goals.")
		return
	if (session.get("choices", []) as Array).size() < 3:
		_fail("Session did not expose three local menu choices.")
		return

	var after_first: Dictionary = manager.choose_response("deflect")
	if int(after_first.get("turn_count", 0)) != 1:
		_fail("Choosing a response did not advance turn count.")
		return
	if (after_first.get("claims", []) as Array).size() != 1:
		_fail("Choosing a response did not record a claim.")
		return
	if float(after_first.get("patience_meter", 100.0)) >= float(session.get("patience_meter", 0.0)):
		_fail("Deflection did not reduce patience.")
		return

	var result: Dictionary = manager.choose_response("deflect")
	if bool(result.get("active", true)):
		_fail("Repeated deflection did not end the bounded session.")
		return
	if str(result.get("outcome", "")) != "lost_patience":
		_fail("Repeated deflection ended with the wrong outcome.")
		return
	if int(result.get("money_delta", 0)) >= 0:
		_fail("Lost patience result did not include a penalty.")
		return


func _test_session_model_resolution() -> void:
	var manager = AdversarialSessionManagerScript.new()
	var session: Dictionary = manager.start_session({
		"id": "marigold",
		"name": "Marigold",
		"trait": "hopeful",
		"irritation": 8.0
	}, {
		"day": 1,
		"recent_failures": 1,
		"top_failed_action": "till"
	})

	if not bool(session.get("active", false)):
		_fail("Resolution test session did not start.")
		return

	manager.choose_response("own_mistake")
	var result: Dictionary = manager.choose_response("own_mistake")
	if bool(result.get("active", true)):
		_fail("Repeated repair choices did not resolve the session.")
		return
	if str(result.get("outcome", "")) != "resolved":
		_fail("Repair choices did not produce a resolved outcome.")
		return
	if int(result.get("money_delta", 0)) <= 0:
		_fail("Resolved result did not include a reward.")
		return
	if float(result.get("agent_irritation_delta", 0.0)) >= 0.0:
		_fail("Resolved result did not reduce NPC irritation.")
		return


func _test_scene_integration() -> void:
	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var game_ui = scene.get_node("GameUI")
	var encounter_panel = game_ui.get("_encounter_panel")
	scene.call("_on_adversarial_encounter_requested", "")
	await process_frame

	if encounter_panel == null or not bool(encounter_panel.visible):
		_fail("Scene did not show the adversarial encounter panel.")
		return

	scene.call("_on_adversarial_response_selected", "own_mistake")
	await process_frame
	scene.call("_on_adversarial_response_selected", "own_mistake")
	await process_frame

	var log = scene.get_node("GameEventLog")
	var result_events: Array = []
	for event in log.get("events"):
		if typeof(event) == TYPE_DICTIONARY and str(event.get("type", "")) == "adversarial_session":
			result_events.append(event)

	if result_events.is_empty():
		_fail("Scene did not record an adversarial session result event.")
		return

	var last_event: Dictionary = result_events.back()
	if str(last_event.get("outcome", "")) != "resolved":
		_fail("Scene adversarial session did not resolve through menu choices.")
		return
	if int(scene.get("money")) <= 42:
		_fail("Resolved scene encounter did not apply the reward.")
		return

	var summary: Dictionary = log.call("build_day_summary", 1)
	if int(summary.get("adversarial_session_count", 0)) < 1:
		_fail("Day summary did not count adversarial sessions.")
		return

	scene.queue_free()
	await process_frame


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
