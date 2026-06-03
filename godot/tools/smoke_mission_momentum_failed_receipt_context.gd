extends SceneTree

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_failed_mission_momentum_receipt_keeps_origin_context()
	if not _failed:
		quit()


func _test_failed_mission_momentum_receipt_keeps_origin_context() -> void:
	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var receipt := str(scene.call("_format_agent_receipt", {
		"agent_name": "Bert",
		"action": "clear_brush",
		"grid_pos": Vector2i(8, 4),
		"success": false,
		"subject": "open ground",
		"social_preference_source": "completed_mission",
		"social_preference_label": "Chuck Cleanup Sprint",
		"social_preference_origin_source": "ignored_ask",
		"social_preference_origin_label": "Rush Kit"
	}))
	if not receipt.contains("missed clear brush"):
		_fail("Failed work receipt did not keep failure copy. saw=%s" % receipt)
		return
	if not receipt.contains("[Momentum: Chuck Cleanup Sprint]"):
		_fail("Failed work receipt did not name Mission Momentum context. saw=%s" % receipt)
		return
	if not receipt.contains("[Pressure: Rush Kit]"):
		_fail("Failed work receipt did not name readable origin context. saw=%s" % receipt)
		return
	if receipt.contains("ignored_ask"):
		_fail("Failed work receipt leaked raw origin context. saw=%s" % receipt)
		return

	scene.queue_free()
	await process_frame


func _fail(message: String) -> void:
	_failed = true
	push_error(message)
	quit(1)
