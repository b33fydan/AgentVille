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
	var helped_agents: Dictionary = summary.get("helped_agents", {})
	var favored_agents: Dictionary = summary.get("favored_agents", {})
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
	if not helped_agents.is_empty():
		score += mini(12, helped_agents.size() * 4 + int(summary.get("completed_agent_demands", 0)) * 2)
		reasons.append("helped %s" % _format_helped_agent_names(helped_agents))
	if not favored_agents.is_empty():
		score += mini(8, favored_agents.size() * 4 + int(summary.get("called_favors", 0)) * 2)
		reasons.append("called %s" % _format_called_favor_names(favored_agents))
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


func _format_helped_agent_names(helped_agents: Dictionary) -> String:
	var names: Array[String] = []
	for agent_id in helped_agents.keys():
		var receipt: Dictionary = helped_agents.get(agent_id, {})
		var name := str(receipt.get("name", str(agent_id).capitalize()))
		if name != "" and not names.has(name):
			names.append(name)
	names.sort()
	return _join_names(names)


func _format_called_favor_names(favored_agents: Dictionary) -> String:
	var names: Array[String] = []
	for agent_id in favored_agents.keys():
		var receipt: Dictionary = favored_agents.get(agent_id, {})
		var name := str(receipt.get("name", str(agent_id).capitalize()))
		if name == "":
			continue
		var count := int(receipt.get("called_favors", 0))
		var label := "%s's favor" % name
		if count > 1:
			label += " x%s" % count
		if not names.has(label):
			names.append(label)
	names.sort()
	return _join_names(names)


func _join_names(names: Array[String]) -> String:
	if names.is_empty():
		return "crew"
	if names.size() == 1:
		return names[0]
	if names.size() == 2:
		return "%s and %s" % [names[0], names[1]]
	var last := names[names.size() - 1]
	var head := names.slice(0, names.size() - 1)
	return "%s, and %s" % [", ".join(head), last]


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
