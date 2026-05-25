class_name UtilityAgentDecisionModel
extends RefCounted


func decide(agent_state: Dictionary, world: Dictionary, memory) -> Dictionary:
	var candidates: Array[Dictionary] = []
	var focus_event: Dictionary = world.get("focus_event", {})

	if not focus_event.is_empty():
		candidates.append(_reaction_candidate(agent_state, focus_event))

	if float(agent_state.get("energy", 70.0)) < 28.0:
		candidates.append(_candidate("rest", 86.0, "energy is low", world.get("home_tile", Vector2i.ZERO)))

	if int(world.get("ready_crops", 0)) > 0:
		candidates.append(_candidate("harvest_crop", 74.0, "ready crops nearby", world.get("ready_tile", world.get("home_tile", Vector2i.ZERO))))

	if int(world.get("brush_tiles", 0)) > 0:
		candidates.append(_candidate("clear_brush", 52.0 + randf() * 6.0, "brush can be cleared for build space", world.get("brush_tile", world.get("home_tile", Vector2i.ZERO))))

	if int(world.get("empty_soil", 0)) > 0:
		candidates.append(_candidate("inspect_soil", 46.0, "open tilled soil needs a plan", world.get("soil_tile", world.get("home_tile", Vector2i.ZERO))))

	if int(world.get("structures", 0)) > 0:
		candidates.append(_candidate("inspect_structure", 32.0 + randf() * 6.0, "farm structures need a quick check", world.get("structure_tile", world.get("home_tile", Vector2i.ZERO))))

	var failed_actions: int = memory.recent_failed_player_actions()
	if failed_actions >= 2:
		candidates.append(_candidate("side_eye", 58.0 + failed_actions * 4.0, "player has repeated failed actions", world.get("home_tile", Vector2i.ZERO)))

	candidates.append(_candidate("wander", 24.0 + randf() * 12.0, "keeping an eye on the farm", world.get("wander_tile", world.get("home_tile", Vector2i.ZERO))))

	var best := candidates[0]
	for candidate in candidates:
		if float(candidate.get("score", 0.0)) > float(best.get("score", 0.0)):
			best = candidate
	return best


func _reaction_candidate(agent_state: Dictionary, event: Dictionary) -> Dictionary:
	var action := str(event.get("action", "farm work"))
	var target = event.get("grid_pos", Vector2i.ZERO)
	if bool(event.get("success", false)):
		return _candidate("approve", 95.0, "player succeeded at %s" % action, target, _positive_line(agent_state, action))
	return _candidate("side_eye", 98.0, "player failed at %s" % action, target, _negative_line(agent_state, action))


func _candidate(action_name: String, score: float, reason: String, target_tile, comment: String = "") -> Dictionary:
	return {
		"action": action_name,
		"score": score,
		"reason": reason,
		"target_tile": target_tile,
		"comment": comment
	}


func _positive_line(agent_state: Dictionary, action_name: String) -> String:
	match str(agent_state.get("trait", "")):
		"grizzled":
			return "That %s was almost competent. Dangerous precedent." % action_name
		"hopeful":
			return "Nice %s. The soil noticed." % action_name
		"chaotic":
			return "A clean %s? I had money on disaster." % action_name
	return "Good %s." % action_name


func _negative_line(agent_state: Dictionary, action_name: String) -> String:
	match str(agent_state.get("trait", "")):
		"grizzled":
			return "I've seen scarecrows make a better %s decision." % action_name
		"hopeful":
			return "That %s did not land, but we can recover." % action_name
		"chaotic":
			return "That %s was a mess. I respect the commitment." % action_name
	return "That %s needs work." % action_name
