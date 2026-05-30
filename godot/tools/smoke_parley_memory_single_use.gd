extends SceneTree

const AdversarialSessionManagerScript := preload("res://scripts/ai/AdversarialSessionManager.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var manager = AdversarialSessionManagerScript.new()
	var session: Dictionary = manager.start_session({
		"id": "marigold",
		"name": "Marigold",
		"trait": "hopeful",
		"irritation": 36.0,
		"helped_today": 0,
		"recent_help_label": "",
		"remembered_help_label": "Seed Bundle",
		"memory_discussed_today": 1,
		"recent_discussed_memory_label": "Seed Bundle"
	}, {
		"day": 2,
		"recent_failures": 3,
		"top_failed_action": "place"
	})

	if str(session.get("remembered_help_label", "")) != "":
		_fail("Already-discussed memory was reused as fresh Parley memory context.")
		return
	if str(session.get("npc_line", "")).contains("Seed Bundle"):
		_fail("Already-discussed memory was still mentioned in the Parley opening line.")
		return
	if _choices_have(session.get("choices", []), "call_favor"):
		_fail("Already-discussed memory exposed a spendable favor choice.")
		return
	if float(session.get("social_credit_bonus", -1.0)) != 0.0:
		_fail("Already-discussed memory changed the patience meter.")
		return

	quit()


func _choices_have(choices: Array, choice_id: String) -> bool:
	for choice in choices:
		if typeof(choice) == TYPE_DICTIONARY and str(choice.get("id", "")) == choice_id:
			return true
	return false


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
