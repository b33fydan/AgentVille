extends SceneTree

const GameEventLogScript := preload("res://scripts/ai/GameEventLog.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var log := Node.new()
	log.set_script(GameEventLogScript)
	root.add_child(log)

	for index in range(4):
		log.call("record_event", "player_action", {
			"day": 1,
			"action": "place",
			"success": false,
			"value": 0,
			"resources": {}
		})

	var chaotic_summary: Dictionary = log.call("build_day_summary", 1)
	var chaotic_vibe: Dictionary = chaotic_summary.get("vibe", {})
	if str(chaotic_vibe.get("label", "")) != "chaotic":
		_fail("Failed action streak did not score as chaotic.")
		return
	if int(chaotic_vibe.get("score", 100)) >= 50:
		_fail("Chaotic day score was not low enough.")
		return

	var productive_log := Node.new()
	productive_log.set_script(GameEventLogScript)
	root.add_child(productive_log)
	for index in range(4):
		productive_log.call("record_event", "player_action", {
			"day": 2,
			"action": "harvest",
			"success": true,
			"value": 8,
			"resources": {"grain": 1}
		})
	productive_log.call("record_event", "craft_action", {
		"day": 2,
		"recipe_id": "fence_kit"
	})

	var productive_summary: Dictionary = productive_log.call("build_day_summary", 2)
	var productive_vibe: Dictionary = productive_summary.get("vibe", {})
	if str(productive_vibe.get("label", "")) != "productive":
		_fail("Harvest/craft day did not score as productive.")
		return
	if int(productive_summary.get("craft_count", 0)) != 1:
		_fail("Craft action was not counted in day summary.")
		return

	var favor_log := Node.new()
	favor_log.set_script(GameEventLogScript)
	root.add_child(favor_log)
	favor_log.call("record_event", "player_action", {
		"day": 3,
		"action": "deliver_supply",
		"success": true,
		"value": 0,
		"resources": {}
	})
	favor_log.call("record_event", "adversarial_session", {
		"day": 3,
		"agent_id": "marigold",
		"agent_name": "Marigold",
		"outcome": "resolved",
		"social_credit_used": true,
		"social_credit_label": "Helped today: Seed Bundle"
	})
	var favor_summary: Dictionary = favor_log.call("build_day_summary", 3)
	var favor_vibe: Dictionary = favor_summary.get("vibe", {})
	if not _reasons_contain(favor_vibe.get("reasons", []), "called Marigold's favor"):
		_fail("Called Parley favor was not included in vibe reasons.")
		return

	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var formatted := str(scene.call("_format_day_summary", productive_summary))
	if not "productive vibe" in formatted:
		_fail("Formatted day summary did not include vibe label.")
		return

	var agent_manager = scene.get_node("FarmWorld/AgentManager")
	var verdict := str(agent_manager.call("_summary_comment", chaotic_summary))
	if not "Chaotic day" in verdict:
		_fail("NPC summary verdict did not use the vibe label.")
		return

	quit()


func _fail(message: String) -> void:
	push_error(message)
	quit(1)


func _reasons_contain(reasons, needle: String) -> bool:
	if typeof(reasons) != TYPE_ARRAY:
		return false
	for reason in reasons:
		if str(reason).contains(needle):
			return true
	return false
