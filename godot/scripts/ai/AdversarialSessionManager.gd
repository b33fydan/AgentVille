class_name AdversarialSessionManager
extends RefCounted

signal session_started(session: Dictionary)
signal session_updated(session: Dictionary)
signal session_ended(result: Dictionary)

const MAX_TURNS := 3

var _session: Dictionary = {}
var _next_session_number := 1


func has_active_session() -> bool:
	return not _session.is_empty() and bool(_session.get("active", false))


func get_session_snapshot() -> Dictionary:
	return _session.duplicate(true)


func clear_session() -> void:
	_session = {}


func start_session(agent_snapshot: Dictionary, context: Dictionary = {}) -> Dictionary:
	if has_active_session():
		return get_session_snapshot()

	var agent_name := str(agent_snapshot.get("name", "Crew"))
	var personality_trait := str(agent_snapshot.get("trait", "steady"))
	var irritation := float(agent_snapshot.get("irritation", 0.0))
	var recent_failures := int(context.get("recent_failures", _count_recent_failures(context.get("recent_events", []))))
	var starting_patience := clampf(76.0 - irritation * 0.36 - float(recent_failures * 4), 32.0, 88.0)
	var grievance := _build_grievance(agent_snapshot, context)
	var session_id := "arg_%03d" % _next_session_number
	_next_session_number += 1

	_session = {
		"active": true,
		"status": "active",
		"session_id": session_id,
		"day": int(context.get("day", 1)),
		"agent_id": str(agent_snapshot.get("id", "agent")),
		"agent_name": agent_name,
		"trait": personality_trait,
		"patience_meter": starting_patience,
		"resolution_meter": 0.0,
		"turn_count": 0,
		"max_turns": MAX_TURNS,
		"claims": [],
		"npc_goal": str(grievance.get("npc_goal", "get the farm back under control")),
		"player_goal": "settle the grievance before patience runs out",
		"grievance": str(grievance.get("text", "The crew wants a word.")),
		"npc_line": _opening_line(agent_name, personality_trait, str(grievance.get("text", ""))),
		"context": context.duplicate(true)
	}
	_session["choices"] = _build_choices(personality_trait, starting_patience)
	session_started.emit(get_session_snapshot())
	return get_session_snapshot()


func choose_response(choice_id: String) -> Dictionary:
	if not has_active_session():
		return {}

	var choice := _choice_for(choice_id)
	if choice.is_empty():
		return get_session_snapshot()

	var personality_trait := str(_session.get("trait", "steady"))
	var turn_count := int(_session.get("turn_count", 0)) + 1
	var patience_delta := float(choice.get("patience_delta", 0.0)) + _trait_patience_delta(personality_trait, choice_id)
	var resolution_delta := float(choice.get("resolution_delta", 0.0)) + _trait_resolution_delta(personality_trait, choice_id)
	var patience := clampf(float(_session.get("patience_meter", 0.0)) + patience_delta, 0.0, 100.0)
	var resolution := clampf(float(_session.get("resolution_meter", 0.0)) + resolution_delta, 0.0, 100.0)
	var claims: Array = _session.get("claims", [])
	claims.append({
		"turn": turn_count,
		"choice_id": choice_id,
		"claim": str(choice.get("claim", "")),
		"patience_delta": patience_delta,
		"resolution_delta": resolution_delta
	})

	_session["turn_count"] = turn_count
	_session["claims"] = claims
	_session["patience_meter"] = patience
	_session["resolution_meter"] = resolution
	_session["last_choice_id"] = choice_id
	_session["npc_line"] = _response_line(personality_trait, choice_id, patience, resolution)
	_session["choices"] = _build_choices(personality_trait, patience)

	if resolution >= 72.0:
		return _end_session("resolved")
	if patience <= 0.0:
		return _end_session("lost_patience")
	if turn_count >= MAX_TURNS:
		return _end_session("uneasy_truce" if resolution >= 48.0 else "walked_away")

	session_updated.emit(get_session_snapshot())
	return get_session_snapshot()


func _end_session(outcome: String) -> Dictionary:
	var result := get_session_snapshot()
	result["active"] = false
	result["status"] = "ended"
	result["outcome"] = outcome
	result["verdict"] = _verdict_for(outcome, result)
	result["money_delta"] = _money_delta_for(outcome)
	result["agent_mood_delta"] = _agent_mood_delta_for(outcome)
	result["agent_irritation_delta"] = _agent_irritation_delta_for(outcome)
	result["choices"] = []
	_session = result.duplicate(true)
	session_ended.emit(result.duplicate(true))
	return result


func _choice_for(choice_id: String) -> Dictionary:
	for choice in _build_choices(str(_session.get("trait", "steady")), float(_session.get("patience_meter", 50.0))):
		if str(choice.get("id", "")) == choice_id:
			return choice
	return {}


func _build_choices(_personality_trait: String, patience: float) -> Array[Dictionary]:
	var tense := patience < 36.0
	return [
		{
			"id": "own_mistake",
			"label": "Own it",
			"stance": "repair",
			"patience_delta": 14.0 if tense else 11.0,
			"resolution_delta": 40.0,
			"claim": "Admits the mess and promises one concrete repair."
		},
		{
			"id": "show_plan",
			"label": "Show plan",
			"stance": "practical",
			"patience_delta": 10.0,
			"resolution_delta": 32.0,
			"claim": "Points to the next useful farm task."
		},
		{
			"id": "deflect",
			"label": "Deflect",
			"stance": "dodge",
			"patience_delta": -22.0 if tense else -18.0,
			"resolution_delta": -8.0,
			"claim": "Suggests the crew is overreacting."
		}
	]


func _trait_patience_delta(personality_trait: String, choice_id: String) -> float:
	match personality_trait:
		"grizzled":
			match choice_id:
				"show_plan":
					return 5.0
				"deflect":
					return -7.0
		"hopeful":
			match choice_id:
				"own_mistake":
					return 5.0
				"deflect":
					return -5.0
		"chaotic":
			match choice_id:
				"deflect":
					return 2.0
				"show_plan":
					return -2.0
	return 0.0


func _trait_resolution_delta(personality_trait: String, choice_id: String) -> float:
	match personality_trait:
		"grizzled":
			return 5.0 if choice_id == "show_plan" else 0.0
		"hopeful":
			return 5.0 if choice_id == "own_mistake" else 0.0
		"chaotic":
			return 4.0 if choice_id == "deflect" else 0.0
	return 0.0


func _build_grievance(agent_snapshot: Dictionary, context: Dictionary) -> Dictionary:
	var personality_trait := str(agent_snapshot.get("trait", "steady"))
	var top_failed_action := str(context.get("top_failed_action", "farm work")).replace("_", " ")
	var recent_failures := int(context.get("recent_failures", 0))
	var work_orders := int(context.get("open_work_orders", 0))

	if recent_failures >= 3:
		match personality_trait:
			"grizzled":
				return {
					"text": "You keep bouncing %s off the farm like a weather event." % top_failed_action,
					"npc_goal": "make the player commit to cleaner field work"
				}
			"hopeful":
				return {
					"text": "The farm can forgive %s misses, but it wants a plan." % recent_failures,
					"npc_goal": "turn chaos into one recoverable next step"
				}
			"chaotic":
				return {
					"text": "%s failed actions is a performance. I need to know if it is intentional." % recent_failures,
					"npc_goal": "extract entertainment and a tiny bit of accountability"
				}

	if work_orders > 0:
		return {
			"text": "The order board is filling up, and the crew wants priorities.",
			"npc_goal": "get a clear priority before the farm becomes errands with grass"
		}

	return {
		"text": "The crew wants to review today's farm management choices.",
		"npc_goal": "test whether the player has an actual plan"
	}


func _opening_line(agent_name: String, personality_trait: String, grievance: String) -> String:
	match personality_trait:
		"grizzled":
			return "%s: \"%s We are discussing it before the soil asks for representation.\"" % [agent_name, grievance]
		"hopeful":
			return "%s: \"%s I am staying optimistic, but my eyebrows are not.\"" % [agent_name, grievance]
		"chaotic":
			return "%s: \"%s Explain before I start selling tickets.\"" % [agent_name, grievance]
	return "%s: \"%s\"" % [agent_name, grievance]


func _response_line(personality_trait: String, choice_id: String, patience: float, resolution: float) -> String:
	if resolution >= 72.0:
		match personality_trait:
			"grizzled":
				return "Fine. That sounded like a plan, which is legally different from flailing."
			"hopeful":
				return "That helps. The farm can work with honest course correction."
			"chaotic":
				return "Accountability arc detected. Unexpected, but marketable."

	if patience <= 0.0:
		match personality_trait:
			"grizzled":
				return "Nope. Patience is empty and so is my tolerance bin."
			"hopeful":
				return "I tried to stay sunny. The sun has left the meeting."
			"chaotic":
				return "Incredible. You turned a conversation into debris."

	match choice_id:
		"own_mistake":
			match personality_trait:
				"grizzled":
					return "Owning it helps. Now give the farm fewer reasons to sigh."
				"hopeful":
					return "Thank you. A clean admission is a seed we can actually plant."
				"chaotic":
					return "Direct accountability. Weirdly spicy. Continue."
		"show_plan":
			match personality_trait:
				"grizzled":
					return "A plan. Finally, a sentence with boots on."
				"hopeful":
					return "That is a next step. I can breathe near that."
				"chaotic":
					return "Plans are just chaos wearing shoes, but fine."
		"deflect":
			match personality_trait:
				"grizzled":
					return "Deflection noted. The farm remains unconvinced and lightly offended."
				"hopeful":
					return "I hear you. I also hear the problem still standing there."
				"chaotic":
					return "Bold dodge. Very shiny. Solves almost nothing."
	return "The crew waits for something more convincing."


func _verdict_for(outcome: String, session: Dictionary) -> String:
	var name := str(session.get("agent_name", "Crew"))
	match outcome:
		"resolved":
			return "%s cooled down. The grievance became a tiny action plan." % name
		"lost_patience":
			return "%s lost patience. The farm meeting ended with consequences." % name
		"uneasy_truce":
			return "%s accepted an uneasy truce. Nobody is framing the minutes." % name
		"walked_away":
			return "%s walked away unconvinced. The grievance is still warm." % name
	return "%s ended the encounter." % name


func _money_delta_for(outcome: String) -> int:
	match outcome:
		"resolved":
			return 3
		"lost_patience":
			return -2
	return 0


func _agent_mood_delta_for(outcome: String) -> float:
	match outcome:
		"resolved":
			return 4.0
		"lost_patience":
			return -4.0
		"uneasy_truce":
			return 1.0
		"walked_away":
			return -2.0
	return 0.0


func _agent_irritation_delta_for(outcome: String) -> float:
	match outcome:
		"resolved":
			return -18.0
		"lost_patience":
			return 14.0
		"uneasy_truce":
			return -5.0
		"walked_away":
			return 5.0
	return 0.0


func _count_recent_failures(events) -> int:
	if typeof(events) != TYPE_ARRAY:
		return 0

	var count := 0
	for event in events:
		if typeof(event) == TYPE_DICTIONARY and str(event.get("type", "")) == "player_action" and not bool(event.get("success", true)):
			count += 1
	return count
