extends SceneTree

const AdversarialSessionManagerScript := preload("res://scripts/ai/AdversarialSessionManager.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var baseline_manager = AdversarialSessionManagerScript.new()
	var baseline: Dictionary = baseline_manager.start_session({
		"id": "marigold",
		"name": "Marigold",
		"trait": "hopeful",
		"irritation": 42.0,
		"helped_today": 0,
		"recent_help_label": ""
	}, {
		"day": 1,
		"recent_failures": 3,
		"top_failed_action": "place"
	})

	var helped_manager = AdversarialSessionManagerScript.new()
	var helped: Dictionary = helped_manager.start_session({
		"id": "marigold",
		"name": "Marigold",
		"trait": "hopeful",
		"irritation": 42.0,
		"helped_today": 1,
		"recent_help_label": "Seed Bundle"
	}, {
		"day": 1,
		"recent_failures": 3,
		"top_failed_action": "place"
	})

	if float(helped.get("patience_meter", 0.0)) < float(baseline.get("patience_meter", 0.0)) + 7.0:
		_fail("Same-day help did not soften the next Parley patience meter.")
		return
	if float(helped.get("social_credit_bonus", 0.0)) <= 0.0:
		_fail("Same-day help did not expose a social credit bonus.")
		return
	if not str(helped.get("social_credit_label", "")).contains("Seed Bundle"):
		_fail("Same-day help did not name the favor that softened Parley.")
		return
	if not str(helped.get("npc_line", "")).contains("Seed Bundle"):
		_fail("Parley opening line did not surface the remembered favor.")
		return

	quit()


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
