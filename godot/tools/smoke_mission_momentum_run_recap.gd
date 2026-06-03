extends SceneTree

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_mission_momentum_day_summary_has_run_recap()
	if not _failed:
		quit()


func _test_mission_momentum_day_summary_has_run_recap() -> void:
	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var summary := {
		"day": 7,
		"total_player_actions": 1,
		"failed_player_actions": 0,
		"successful_player_actions": 1,
		"top_action": "clear_brush",
		"agent_social_preference_actions": {
			"bert": {
				"name": "Bert",
				"actions": 1,
				"last_source": "completed_mission",
				"last_label": "Chuck Cleanup Sprint",
				"last_origin_source": "ignored_ask",
				"last_origin_label": "Rush Kit"
			}
		},
		"vibe": {
			"label": "careful",
			"score": 55,
			"reasons": []
		}
	}

	var formatted := str(scene.call("_format_day_summary", summary))
	if not formatted.contains("run recap"):
		_fail("Mission Momentum day summary did not include a run recap. saw=%s" % formatted)
		return
	if not formatted.contains("Bert ran Chuck Cleanup Sprint"):
		_fail("Run recap did not name the crew member and run label. saw=%s" % formatted)
		return
	if not formatted.contains("Pressure: Rush Kit"):
		_fail("Run recap did not name readable origin context. saw=%s" % formatted)
		return
	if formatted.contains("ignored_ask") or formatted.contains("completed_mission"):
		_fail("Run recap leaked raw source ids. saw=%s" % formatted)
		return

	scene.queue_free()
	await process_frame


func _fail(message: String) -> void:
	_failed = true
	push_error(message)
	quit(1)
