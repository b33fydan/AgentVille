extends SceneTree

const PlayerVibeScorerScript := preload("res://scripts/ai/PlayerVibeScorer.gd")

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_consequence_sources_use_player_facing_receipt_language()
	if not _failed:
		quit()


func _test_consequence_sources_use_player_facing_receipt_language() -> void:
	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	_assert_agent_receipt_source(scene, "completed_mission", "Marigold Growth Run", "Momentum")
	_assert_agent_receipt_source(scene, "ignored_ask", "Rush Kit", "Pressure")
	_assert_agent_receipt_source(scene, "completed_order", "Build Fence", "Follow-up")
	_assert_agent_receipt_source(scene, "held_truce", "Fence Kit", "Held")
	_assert_agent_receipt_source(scene, "repeated_help", "Seed Bundle", "Streak")
	if _failed:
		return

	var summary := _summary_with_social_source("completed_mission", "Marigold Growth Run")
	var summary_text := str(scene.call("_format_day_summary", summary))
	if not summary_text.contains("Momentum") or summary_text.contains("Completed_mission"):
		_fail("Day summary did not use readable consequence source text. saw=%s" % summary_text)
		return

	var scorer = PlayerVibeScorerScript.new()
	var vibe: Dictionary = scorer.call("score_summary", summary)
	var reasons: Array = vibe.get("reasons", [])
	if reasons.is_empty() or not str(reasons[0]).contains("Momentum") or str(reasons[0]).contains("Completed_mission"):
		_fail("Vibe reason did not use readable consequence source text. saw=%s" % str(reasons))
		return

	var agent_manager = scene.get_node("FarmWorld/AgentManager")
	var comment := str(agent_manager.call("_summary_comment", summary))
	if not comment.contains("Momentum") or comment.contains("Completed_mission"):
		_fail("NPC summary comment did not use readable consequence source text. saw=%s" % comment)
		return

	scene.queue_free()
	await process_frame


func _assert_agent_receipt_source(scene: Node, source: String, label: String, readable_source: String) -> void:
	if _failed:
		return
	var receipt := str(scene.call("_format_agent_receipt", {
		"agent_name": "Marigold",
		"action": "clear_brush",
		"grid_pos": Vector2i(1, 1),
		"success": true,
		"subject": "tall grass",
		"resources": {"fiber": 1},
		"social_preference_source": source,
		"social_preference_label": label
	}))
	if not receipt.contains("[%s: %s]" % [readable_source, label]):
		_fail("Agent receipt did not use %s for %s. saw=%s" % [readable_source, source, receipt])
		return
	if receipt.contains(source.capitalize()):
		_fail("Agent receipt leaked raw consequence source %s. saw=%s" % [source, receipt])


func _summary_with_social_source(source: String, label: String) -> Dictionary:
	return {
		"day": 7,
		"total_player_actions": 0,
		"failed_player_actions": 0,
		"successful_player_actions": 0,
		"agent_social_preference_actions": {
			"marigold": {
				"name": "Marigold",
				"actions": 1,
				"last_source": source,
				"last_label": label
			}
		},
		"vibe": {
			"label": "careful",
			"score": 53,
			"reasons": []
		}
	}


func _fail(message: String) -> void:
	_failed = true
	push_error(message)
	quit(1)
