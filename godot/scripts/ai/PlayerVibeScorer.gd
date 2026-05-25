class_name PlayerVibeScorer
extends RefCounted


func score_summary(summary: Dictionary) -> Dictionary:
	var total := int(summary.get("total_player_actions", 0))
	var failed := int(summary.get("failed_player_actions", 0))
	var successful := int(summary.get("successful_player_actions", 0))
	var harvest_value := int(summary.get("harvest_value", 0))
	var agent_harvest_value := int(summary.get("agent_harvest_value", 0))
	var craft_count := int(summary.get("craft_count", 0))
	var resources_gained: Dictionary = summary.get("resources_gained", {})
	var reasons: Array[String] = []
	var score := 50
	var label := "quiet"

	if total == 0:
		reasons.append("no player farm work logged")
		return _result("neglectful", 18, reasons)

	var fail_ratio := float(failed) / float(maxi(total, 1))
	score += successful * 5
	score -= failed * 9

	if harvest_value > 0:
		score += mini(20, harvest_value / 3)
		reasons.append("%s coins harvested" % harvest_value)
	if agent_harvest_value > 0:
		score += mini(10, agent_harvest_value / 4)
		reasons.append("crew added %s coins" % agent_harvest_value)
	if not resources_gained.is_empty():
		score += 8
		reasons.append("resources gathered")
	if craft_count > 0:
		score += craft_count * 4
		reasons.append("%s crafting actions" % craft_count)
	if failed > 0:
		reasons.append("%s missed actions" % failed)

	score = clampi(score, 0, 100)

	if failed >= 3 or fail_ratio >= 0.42:
		label = "chaotic"
	elif harvest_value >= 18 or (successful >= 4 and not resources_gained.is_empty()) or craft_count >= 2:
		label = "productive"
	elif successful >= 4 and failed == 0:
		label = "careful"
	elif failed == 0 and total <= 2:
		label = "light-touch"
	elif successful > failed:
		label = "mixed"
	else:
		label = "messy"

	if reasons.is_empty():
		reasons.append("mostly %s" % str(summary.get("top_action", "work")))

	return _result(label, score, reasons)


func _result(label: String, score: int, reasons: Array[String]) -> Dictionary:
	return {
		"label": label,
		"score": score,
		"reasons": reasons,
		"tone": _tone_for(label)
	}


func _tone_for(label: String) -> String:
	match label:
		"productive":
			return "earned respect"
		"careful":
			return "quiet competence"
		"chaotic":
			return "visible concern"
		"messy":
			return "thin patience"
		"neglectful":
			return "neglected"
		"light-touch":
			return "barely warmed up"
	return "mixed"
