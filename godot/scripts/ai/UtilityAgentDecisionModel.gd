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

	var daily_intention := _daily_intention_candidate(agent_state, world)
	if not daily_intention.is_empty():
		candidates.append(daily_intention)

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


func _daily_intention_candidate(agent_state: Dictionary, world: Dictionary) -> Dictionary:
	var intention_id := str(agent_state.get("daily_intention_id", "")).strip_edges()
	var intention_label := str(agent_state.get("daily_intention_label", "")).strip_edges()
	var focus := str(agent_state.get("daily_intention_focus", "")).strip_edges()
	if intention_id == "" or intention_label == "" or focus == "":
		return {}

	var metadata := _daily_intention_metadata(agent_state)
	match focus:
		"grow":
			if int(world.get("ready_crops", 0)) > 0:
				return _candidate(
					"harvest_crop",
					77.0,
					"daily intention points toward harvest work: %s" % intention_label,
					world.get("ready_tile", world.get("home_tile", Vector2i.ZERO)),
					_daily_intention_line(agent_state, "harvest", intention_label),
					metadata
				)
			if int(world.get("growing_crops", 0)) > 0:
				return _candidate(
					"inspect_ready_crop",
					70.0,
					"daily intention points toward crop watching: %s" % intention_label,
					world.get("growing_tile", world.get("home_tile", Vector2i.ZERO)),
					_daily_intention_line(agent_state, "crop_watch", intention_label),
					metadata
				)
			if int(world.get("empty_soil", 0)) > 0:
				return _candidate(
					"inspect_soil",
					68.0,
					"daily intention points toward soil planning: %s" % intention_label,
					world.get("soil_tile", world.get("home_tile", Vector2i.ZERO)),
					_daily_intention_line(agent_state, "soil", intention_label),
					metadata
				)
		"clear":
			if int(world.get("brush_tiles", 0)) > 0:
				return _candidate(
					"clear_brush",
					76.0,
					"daily intention points toward clearing work: %s" % intention_label,
					world.get("brush_tile", world.get("home_tile", Vector2i.ZERO)),
					_daily_intention_line(agent_state, "brush", intention_label),
					metadata
				)
			if int(world.get("structures", 0)) > 0:
				return _candidate(
					"inspect_structure",
					65.0,
					"daily intention points toward route checks: %s" % intention_label,
					world.get("structure_tile", world.get("home_tile", Vector2i.ZERO)),
					_daily_intention_line(agent_state, "route", intention_label),
					metadata
				)
		"boundary":
			if int(world.get("structures", 0)) > 0:
				return _candidate(
					"inspect_structure",
					77.0,
					"daily intention points toward boundary checks: %s" % intention_label,
					world.get("structure_tile", world.get("home_tile", Vector2i.ZERO)),
					_daily_intention_line(agent_state, "fence", intention_label),
					metadata
				)
			if int(world.get("brush_tiles", 0)) > 0:
				return _candidate(
					"clear_brush",
					72.0,
					"daily intention points toward clearing boundary space: %s" % intention_label,
					world.get("brush_tile", world.get("home_tile", Vector2i.ZERO)),
					_daily_intention_line(agent_state, "brush", intention_label),
					metadata
				)
			if int(world.get("empty_soil", 0)) > 0:
				return _candidate(
					"inspect_soil",
					66.0,
					"daily intention points toward boundary planning: %s" % intention_label,
					world.get("soil_tile", world.get("home_tile", Vector2i.ZERO)),
					_daily_intention_line(agent_state, "fence_space", intention_label),
					metadata
				)
	return {}


func _social_preference_candidate(agent_state: Dictionary, world: Dictionary) -> Dictionary:
	var context := _social_preference_context(agent_state)
	var label := str(context.get("label", ""))
	if label == "":
		return {}

	var source := str(context.get("source", "memory"))
	var base_score := _social_preference_base_score(source)
	var reason_source := _social_preference_reason_source(source)
	var lower_label := label.to_lower()
	if _label_matches_any(lower_label, ["seed", "spring", "harvest", "crop", "growth"]):
		if int(world.get("ready_crops", 0)) > 0:
			return _candidate(
				"harvest_crop",
				base_score + 7.0,
				"%s points toward harvest work: %s" % [reason_source, label],
				world.get("ready_tile", world.get("home_tile", Vector2i.ZERO)),
				_social_preference_line(agent_state, source, "harvest", label),
				_social_preference_metadata(source, label)
			)
		if int(world.get("empty_soil", 0)) > 0:
			return _candidate(
				"inspect_soil",
				base_score,
				"%s points toward spring planning: %s" % [reason_source, label],
				world.get("soil_tile", world.get("home_tile", Vector2i.ZERO)),
				_social_preference_line(agent_state, source, "soil", label),
				_social_preference_metadata(source, label)
			)
		if int(world.get("growing_crops", 0)) > 0:
			return _candidate(
				"inspect_ready_crop",
				base_score - 2.0,
				"%s points toward crop watching: %s" % [reason_source, label],
				world.get("growing_tile", world.get("home_tile", Vector2i.ZERO)),
				_social_preference_line(agent_state, source, "crop_watch", label),
				_social_preference_metadata(source, label)
			)

	if _label_matches_any(lower_label, ["rush", "hustle", "clear", "brush", "fiber"]):
		if int(world.get("brush_tiles", 0)) > 0:
			return _candidate(
				"clear_brush",
				base_score + 6.0,
				"%s points toward clearing work: %s" % [reason_source, label],
				world.get("brush_tile", world.get("home_tile", Vector2i.ZERO)),
				_social_preference_line(agent_state, source, "brush", label),
				_social_preference_metadata(source, label)
			)
		if int(world.get("structures", 0)) > 0:
			return _candidate(
				"inspect_structure",
				base_score - 1.0,
				"%s points toward route inspection: %s" % [reason_source, label],
				world.get("structure_tile", world.get("home_tile", Vector2i.ZERO)),
				_social_preference_line(agent_state, source, "route", label),
				_social_preference_metadata(source, label)
			)

	if _label_matches_any(lower_label, ["fence", "boundary"]):
		if int(world.get("structures", 0)) > 0:
			return _candidate(
				"inspect_structure",
				base_score + 3.0,
				"%s points toward fence checks: %s" % [reason_source, label],
				world.get("structure_tile", world.get("home_tile", Vector2i.ZERO)),
				_social_preference_line(agent_state, source, "fence", label),
				_social_preference_metadata(source, label)
			)
		if int(world.get("brush_tiles", 0)) > 0:
			return _candidate(
				"clear_brush",
				base_score + 2.0,
				"%s points toward clearing fence space: %s" % [reason_source, label],
				world.get("brush_tile", world.get("home_tile", Vector2i.ZERO)),
				_social_preference_line(agent_state, source, "brush", label),
				_social_preference_metadata(source, label)
			)
		if int(world.get("empty_soil", 0)) > 0:
			return _candidate(
				"inspect_soil",
				base_score - 1.0,
				"%s points toward fence planning: %s" % [reason_source, label],
				world.get("soil_tile", world.get("home_tile", Vector2i.ZERO)),
				_social_preference_line(agent_state, source, "fence_space", label),
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

	var consequence_source := str(agent_state.get("memory_consequence_source", "")).strip_edges()
	var consequence_label := str(agent_state.get("memory_consequence_label", "")).strip_edges()
	if consequence_source != "" and consequence_label != "" and int(agent_state.get("memory_consequence_days", 0)) > 0:
		return {
			"source": consequence_source,
			"label": consequence_label
		}

	var remembered_label := str(agent_state.get("remembered_help_label", "")).strip_edges()
	if remembered_label != "" and int(agent_state.get("remembered_help_days", 0)) > 0:
		return {
			"source": "memory",
			"label": remembered_label
		}

	return {}


func _social_preference_base_score(source: String) -> float:
	match source:
		"truce":
			return 88.0
		"ignored_ask":
			return 84.0
		"held_truce":
			return 82.0
	return 80.0


func _social_preference_metadata(source: String, label: String) -> Dictionary:
	return {
		"social_preference_source": source,
		"social_preference_label": label
	}


func _daily_intention_metadata(agent_state: Dictionary) -> Dictionary:
	return {
		"daily_intention_id": str(agent_state.get("daily_intention_id", "")).strip_edges(),
		"daily_intention_label": str(agent_state.get("daily_intention_label", "")).strip_edges()
	}


func _label_matches_any(label: String, needles: Array[String]) -> bool:
	for needle in needles:
		if label.contains(needle):
			return true
	return false


func _social_preference_line(agent_state: Dictionary, source: String, focus: String, label: String) -> String:
	var context := _social_preference_display_source(source)
	match str(agent_state.get("trait", "")):
		"grizzled":
			match focus:
				"harvest":
					return "%s says %s means we finish the crop work." % [context, label]
				"crop_watch":
					return "%s says %s means we keep an eye on the crop." % [context, label]
				"soil":
					return "%s says %s starts with checking the soil." % [context, label]
				"brush":
					return "%s says %s starts by making room." % [context, label]
				"route":
					return "%s says %s starts with checking the route." % [context, label]
				"fence":
					return "%s says %s means checking the boundaries." % [context, label]
				"fence_space":
					return "%s says %s means checking the ground for a line." % [context, label]
		"hopeful":
			match focus:
				"harvest":
					return "%s says %s can turn into a useful harvest." % [context, label]
				"crop_watch":
					return "%s says %s wants a little crop check-in." % [context, label]
				"soil":
					return "%s says %s wants a good place to grow." % [context, label]
				"brush":
					return "%s says %s can clear a better path." % [context, label]
				"route":
					return "%s says %s wants the path checked first." % [context, label]
				"fence":
					return "%s says %s can make the farm feel steadier." % [context, label]
				"fence_space":
					return "%s says %s needs a sensible line to land on." % [context, label]
		"chaotic":
			match focus:
				"harvest":
					return "%s says %s. The vegetables are implicated." % [context, label]
				"crop_watch":
					return "%s says %s. Crop surveillance begins." % [context, label]
				"soil":
					return "%s says %s. I am interrogating the dirt." % [context, label]
				"brush":
					return "%s says %s. The weeds have been notified." % [context, label]
				"route":
					return "%s says %s. Route inspection, dramatic edition." % [context, label]
				"fence":
					return "%s says %s. Boundary inspection mode." % [context, label]
				"fence_space":
					return "%s says %s. I am measuring imaginary fences." % [context, label]
	return "%s says %s matters right now." % [context, label]


func _social_preference_reason_source(source: String) -> String:
	match source:
		"truce":
			return "truce"
		"repeated_help":
			return "streak"
		"completed_order":
			return "follow-up"
		"completed_mission":
			return "mission momentum"
		"ignored_ask":
			return "pressure"
		"held_truce":
			return "held truce"
	return "memory"


func _social_preference_display_source(source: String) -> String:
	match source:
		"truce":
			return "Truce"
		"repeated_help":
			return "Streak"
		"completed_order":
			return "Follow-up"
		"completed_mission":
			return "Momentum"
		"ignored_ask":
			return "Pressure"
		"held_truce":
			return "Held"
	return "Memory"


func _daily_intention_line(agent_state: Dictionary, focus: String, label: String) -> String:
	match str(agent_state.get("trait", "")):
		"grizzled":
			match focus:
				"harvest":
					return "%s means finishing what is ready." % label
				"crop_watch":
					return "%s means checking the crop before it complains." % label
				"soil":
					return "%s starts with a look at the dirt." % label
				"brush":
					return "%s means clearing a practical line." % label
				"route":
					return "%s starts with checking the route." % label
				"fence":
					return "%s means checking what still stands." % label
				"fence_space":
					return "%s means finding where a boundary could land." % label
		"hopeful":
			match focus:
				"harvest":
					return "%s can turn into a useful harvest." % label
				"crop_watch":
					return "%s gets a crop check-in first." % label
				"soil":
					return "%s starts with finding a good growing spot." % label
				"brush":
					return "%s can make room for something nicer." % label
				"route":
					return "%s starts by checking the path." % label
				"fence":
					return "%s can make the farm feel steadier." % label
				"fence_space":
					return "%s needs a sensible line." % label
		"chaotic":
			match focus:
				"harvest":
					return "%s has nominated the vegetables." % label
				"crop_watch":
					return "%s begins with crop surveillance." % label
				"soil":
					return "%s requires a dirt interview." % label
				"brush":
					return "%s has filed paperwork against these weeds." % label
				"route":
					return "%s is now a dramatic route inspection." % label
				"fence":
					return "%s has entered boundary inspection mode." % label
				"fence_space":
					return "%s requires imaginary fence math." % label
	return "%s matters right now." % label


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
