class_name UtilityAgentDecisionModel
extends RefCounted


func decide(agent_state: Dictionary, world: Dictionary, memory) -> Dictionary:
	var candidates: Array[Dictionary] = []
	var focus_event: Dictionary = world.get("focus_event", {})

	if not focus_event.is_empty():
		candidates.append(_reaction_candidate(agent_state, focus_event))

	var social_preference := _social_preference_candidate(agent_state, world)
	if not social_preference.is_empty():
		candidates.append(social_preference)

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


func _social_preference_candidate(agent_state: Dictionary, world: Dictionary) -> Dictionary:
	var context := _social_preference_context(agent_state)
	var label := str(context.get("label", ""))
	if label == "":
		return {}

	var source := str(context.get("source", "memory"))
	var base_score := 88.0 if source == "truce" else 80.0
	var lower_label := label.to_lower()
	if _label_matches_any(lower_label, ["seed", "spring", "harvest", "crop"]):
		if int(world.get("ready_crops", 0)) > 0:
			return _candidate(
				"harvest_crop",
				base_score + 7.0,
				"%s points toward harvest work: %s" % [source, label],
				world.get("ready_tile", world.get("home_tile", Vector2i.ZERO)),
				_social_preference_line(agent_state, source, "harvest", label),
				_social_preference_metadata(source, label)
			)
		if int(world.get("empty_soil", 0)) > 0:
			return _candidate(
				"inspect_soil",
				base_score,
				"%s points toward spring planning: %s" % [source, label],
				world.get("soil_tile", world.get("home_tile", Vector2i.ZERO)),
				_social_preference_line(agent_state, source, "soil", label),
				_social_preference_metadata(source, label)
			)

	if _label_matches_any(lower_label, ["rush", "hustle", "clear", "brush", "fiber"]):
		if int(world.get("brush_tiles", 0)) > 0:
			return _candidate(
				"clear_brush",
				base_score + 6.0,
				"%s points toward clearing work: %s" % [source, label],
				world.get("brush_tile", world.get("home_tile", Vector2i.ZERO)),
				_social_preference_line(agent_state, source, "brush", label),
				_social_preference_metadata(source, label)
			)

	if _label_matches_any(lower_label, ["fence", "boundary"]):
		if int(world.get("structures", 0)) > 0:
			return _candidate(
				"inspect_structure",
				base_score + 3.0,
				"%s points toward fence checks: %s" % [source, label],
				world.get("structure_tile", world.get("home_tile", Vector2i.ZERO)),
				_social_preference_line(agent_state, source, "fence", label),
				_social_preference_metadata(source, label)
			)
		if int(world.get("brush_tiles", 0)) > 0:
			return _candidate(
				"clear_brush",
				base_score + 2.0,
				"%s points toward clearing fence space: %s" % [source, label],
				world.get("brush_tile", world.get("home_tile", Vector2i.ZERO)),
				_social_preference_line(agent_state, source, "brush", label),
				_social_preference_metadata(source, label)
			)

	return {}


func _social_preference_context(agent_state: Dictionary) -> Dictionary:
	var truce_label := str(agent_state.get("truce_label", "")).strip_edges()
	if truce_label != "" and int(agent_state.get("truce_days", 0)) > 0:
		return {
			"source": "truce",
			"label": truce_label
		}

	var remembered_label := str(agent_state.get("remembered_help_label", "")).strip_edges()
	if remembered_label != "" and int(agent_state.get("remembered_help_days", 0)) > 0:
		return {
			"source": "memory",
			"label": remembered_label
		}

	return {}


func _social_preference_metadata(source: String, label: String) -> Dictionary:
	return {
		"social_preference_source": source,
		"social_preference_label": label
	}


func _label_matches_any(label: String, needles: Array[String]) -> bool:
	for needle in needles:
		if label.contains(needle):
			return true
	return false


func _social_preference_line(agent_state: Dictionary, source: String, focus: String, label: String) -> String:
	var context := "Truce" if source == "truce" else "Memory"
	match str(agent_state.get("trait", "")):
		"grizzled":
			match focus:
				"harvest":
					return "%s says %s means we finish the crop work." % [context, label]
				"soil":
					return "%s says %s starts with checking the soil." % [context, label]
				"brush":
					return "%s says %s starts by making room." % [context, label]
				"fence":
					return "%s says %s means checking the boundaries." % [context, label]
		"hopeful":
			match focus:
				"harvest":
					return "%s says %s can turn into a useful harvest." % [context, label]
				"soil":
					return "%s says %s wants a good place to grow." % [context, label]
				"brush":
					return "%s says %s can clear a better path." % [context, label]
				"fence":
					return "%s says %s can make the farm feel steadier." % [context, label]
		"chaotic":
			match focus:
				"harvest":
					return "%s says %s. The vegetables are implicated." % [context, label]
				"soil":
					return "%s says %s. I am interrogating the dirt." % [context, label]
				"brush":
					return "%s says %s. The weeds have been notified." % [context, label]
				"fence":
					return "%s says %s. Boundary inspection mode." % [context, label]
	return "%s says %s matters right now." % [context, label]


func _reaction_candidate(agent_state: Dictionary, event: Dictionary) -> Dictionary:
	var action := str(event.get("action", "farm work"))
	var target = event.get("grid_pos", Vector2i.ZERO)
	if bool(event.get("success", false)):
		return _candidate("approve", 95.0, "player succeeded at %s" % action, target, _positive_line(agent_state, action))
	return _candidate("side_eye", 98.0, "player failed at %s" % action, target, _negative_line(agent_state, action))


func _candidate(action_name: String, score: float, reason: String, target_tile, comment: String = "", extra: Dictionary = {}) -> Dictionary:
	var candidate := {
		"action": action_name,
		"score": score,
		"reason": reason,
		"target_tile": target_tile,
		"comment": comment
	}
	for key in extra.keys():
		candidate[key] = extra[key]
	return candidate


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
