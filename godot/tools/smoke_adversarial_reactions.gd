extends SceneTree

const AgentReactionModelScript := preload("res://scripts/ai/AgentReactionModel.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_reaction_model()

	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var agent_manager = scene.get_node("FarmWorld/AgentManager")
	var game_ui = scene.get_node("GameUI")
	var comments: Array[String] = []
	var crew_updates: Array[int] = []
	agent_manager.connect("agent_comment", func(message: String) -> void:
		comments.append(message)
	)
	agent_manager.connect("crew_updated", func(_snapshots: Array) -> void:
		crew_updates.append(1)
	)

	for index in range(9):
		scene.call("_on_player_action_logged", {
			"actor": "player",
			"tool": "place",
			"action": "place",
			"grid_pos": Vector2i(index % 3, index / 3),
			"item_id": "fence",
			"success": false,
			"message": "Cannot place that here.",
			"value": 0,
			"resources": {},
			"crafted_cost": {}
		})
		await process_frame

	var snapshots: Array = agent_manager.call("get_agent_snapshots")
	var annoyed_count := 0
	var strongest_irritation := 0.0
	for snapshot in snapshots:
		var expression := str(snapshot.get("expression", "neutral"))
		var irritation := float(snapshot.get("irritation", 0.0))
		strongest_irritation = maxf(strongest_irritation, irritation)
		if expression in ["annoyed", "angry"]:
			annoyed_count += 1

	if annoyed_count < 1:
		_fail("Repeated failed player actions did not annoy any NPC.")
		return
	if strongest_irritation < 20.0:
		_fail("Repeated failed player actions did not raise irritation enough.")
		return
	if comments.is_empty():
		_fail("Adversarial reactions did not emit any NPC comment.")
		return
	if crew_updates.is_empty():
		_fail("Adversarial reactions did not emit crew update snapshots.")
		return

	game_ui.set_agent_snapshots(snapshots)
	var crew_rows: Dictionary = game_ui.get("_crew_rows")
	var ui_showed_reaction := false
	var ui_texts: Array[String] = []
	for agent_id in crew_rows.keys():
		var row: Dictionary = crew_rows[agent_id]
		var action_text := str((row["action"] as Label).text)
		ui_texts.append("%s=%s" % [str(agent_id), action_text])
		if "Annoyed" in action_text or "Judging" in action_text or "Side-eye" in action_text:
			ui_showed_reaction = true
	if not ui_showed_reaction:
		var snapshot_bits: Array[String] = []
		for snapshot in snapshots:
			snapshot_bits.append("%s:%s/%s" % [str(snapshot.get("id", "")), str(snapshot.get("expression", "")), float(snapshot.get("irritation", 0.0))])
		_fail("Crew UI did not surface adversarial expression state. rows=%s snapshots=%s" % [", ".join(ui_texts), ", ".join(snapshot_bits)])
		return

	quit()


func _test_reaction_model() -> void:
	var model = AgentReactionModelScript.new()
	var state := {
		"trait": "grizzled",
		"irritation": 0.0
	}
	var success_event := {
		"type": "player_action",
		"action": "harvest",
		"success": true
	}
	var success_reaction: Dictionary = model.score_event(state, success_event, true)
	if str(success_reaction.get("expression", "")) not in ["pleased", "neutral"]:
		_fail("Successful player action did not produce a positive or neutral reaction.")
		return

	var failed_event := {
		"type": "player_action",
		"action": "place",
		"success": false
	}
	var total_irritation := 0.0
	var last_reaction := {}
	for _index in range(3):
		state["irritation"] = total_irritation
		last_reaction = model.score_event(state, failed_event, true)
		total_irritation += float(last_reaction.get("irritation_delta", 0.0))

	if total_irritation < 18.0:
		_fail("Failed player actions did not accumulate irritation.")
		return
	if str(last_reaction.get("expression", "")) not in ["side_eye", "annoyed", "angry"]:
		_fail("Failed player actions did not produce an adversarial expression.")
		return


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
