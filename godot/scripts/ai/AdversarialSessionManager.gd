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
	var social_credit_bonus := _social_credit_patience_bonus(agent_snapshot, context)
	var social_credit_label := _social_credit_label(agent_snapshot, context)
	var remembered_help_label := _remembered_help_label(agent_snapshot, context)
	var starting_patience := clampf(76.0 - irritation * 0.36 - float(recent_failures * 4) + social_credit_bonus, 32.0, 94.0)
	var grievance := _build_grievance(agent_snapshot, context)
	var grievance_text := str(grievance.get("text", "The crew wants a word."))
	if social_credit_label != "":
		grievance_text = "%s %s" % [_social_credit_opening_note(personality_trait, social_credit_label), grievance_text]
	elif remembered_help_label != "":
		grievance_text = "%s %s" % [_remembered_help_opening_note(personality_trait, remembered_help_label), grievance_text]
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
		"social_credit_bonus": social_credit_bonus,
		"social_credit_label": social_credit_label,
		"social_credit_used": false,
		"remembered_help_label": remembered_help_label,
		"truce_label": str(agent_snapshot.get("truce_label", context.get("truce_label", ""))).strip_edges(),
		"truce_days": int(agent_snapshot.get("truce_days", context.get("truce_days", 0))),
		"resolution_meter": 0.0,
		"turn_count": 0,
		"max_turns": MAX_TURNS,
		"claims": [],
		"npc_goal": str(grievance.get("npc_goal", "get the farm back under control")),
		"player_goal": "settle the grievance before patience runs out",
		"grievance": grievance_text,
		"npc_line": _opening_line(agent_name, personality_trait, grievance_text),
		"context": context.duplicate(true)
	}
	_session["choices"] = _build_choices_for_session()
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
	if choice_id == "call_favor":
		_session["social_credit_used"] = true
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
	_session["npc_line"] = _response_line(personality_trait, choice_id, patience, resolution, choice)
	_session["choices"] = _build_choices_for_session()

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
	result["resource_delta"] = _resource_delta_for(outcome)
	result["agent_mood_delta"] = _agent_mood_delta_for(outcome)
	result["agent_irritation_delta"] = _agent_irritation_delta_for(outcome)
	result["crew_boost_seconds"] = _crew_boost_seconds_for(outcome)
	result["patience_tax_orders"] = _patience_tax_orders_for(outcome)
	result["crew_mission"] = _crew_mission_for(outcome, result)
	result["crafting_demand"] = _crafting_demand_for(outcome, result)
	result["choices"] = []
	_session = result.duplicate(true)
	session_ended.emit(result.duplicate(true))
	return result


func _choice_for(choice_id: String) -> Dictionary:
	for choice in _session.get("choices", []):
		if str(choice.get("id", "")) == choice_id:
			return choice
	return {}


func _build_choices_for_session() -> Array[Dictionary]:
	return _build_choices(
		str(_session.get("trait", "steady")),
		float(_session.get("patience_meter", 50.0)),
		float(_session.get("social_credit_bonus", 0.0)) > 0.0 and not bool(_session.get("social_credit_used", false)),
		str(_session.get("social_credit_label", ""))
	)


func _build_choices(_personality_trait: String, patience: float, include_call_favor: bool = false, social_credit_label: String = "") -> Array[Dictionary]:
	var tense := patience < 36.0
	var choices: Array[Dictionary] = [
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
	if include_call_favor:
		choices.append({
			"id": "call_favor",
			"label": "Call favor",
			"stance": "social_credit",
			"patience_delta": 12.0,
			"resolution_delta": 46.0,
			"claim": _call_favor_claim(social_credit_label),
			"social_credit_label": social_credit_label
		})
	return choices


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


func _call_favor_claim(social_credit_label: String) -> String:
	var help_label := _social_credit_help_label(social_credit_label)
	return "Reminds the crew that %s should count for something." % help_label


func _build_grievance(agent_snapshot: Dictionary, context: Dictionary) -> Dictionary:
	var queued_text := str(context.get("grievance_text", ""))
	if queued_text != "":
		return {
			"text": queued_text,
			"npc_goal": str(context.get("npc_goal", "get a concrete recovery plan"))
		}

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


func _social_credit_patience_bonus(agent_snapshot: Dictionary, context: Dictionary) -> float:
	var helped_today := int(agent_snapshot.get("helped_today", context.get("helped_today", 0)))
	if helped_today <= 0:
		return 0.0
	return minf(14.0, 8.0 + float(helped_today - 1) * 3.0)


func _social_credit_label(agent_snapshot: Dictionary, context: Dictionary) -> String:
	if _social_credit_patience_bonus(agent_snapshot, context) <= 0.0:
		return ""

	var help_label := str(agent_snapshot.get("recent_help_label", context.get("recent_help_label", "")))
	if help_label == "":
		return "Helped today"
	return "Helped today: %s" % help_label


func _remembered_help_label(agent_snapshot: Dictionary, context: Dictionary) -> String:
	if _social_credit_patience_bonus(agent_snapshot, context) > 0.0:
		return ""
	if int(agent_snapshot.get("memory_discussed_today", context.get("memory_discussed_today", 0))) > 0:
		return ""

	var help_label := str(agent_snapshot.get("remembered_help_label", context.get("remembered_help_label", "")))
	return help_label.strip_edges()


func _social_credit_opening_note(personality_trait: String, social_credit_label: String) -> String:
	var help_label := _social_credit_help_label(social_credit_label)
	match personality_trait:
		"grizzled":
			return "You did help with %s today, so this starts less badly." % help_label
		"hopeful":
			return "You did help with %s today, so I am starting warmer." % help_label
		"chaotic":
			return "You did help with %s today, so the complaint has a tiny cushion." % help_label
	return "You did help with %s today, so this starts calmer." % help_label


func _remembered_help_opening_note(personality_trait: String, help_label: String) -> String:
	match personality_trait:
		"grizzled":
			return "I remember the %s. That is context, not a coupon." % help_label
		"hopeful":
			return "I remember the %s, and I am carrying that into this." % help_label
		"chaotic":
			return "The %s is still in the friendship ledger. Mildly glowing." % help_label
	return "I remember the %s, and that matters." % help_label


func _social_credit_help_label(social_credit_label: String) -> String:
	var help_label := social_credit_label.replace("Helped today: ", "")
	if help_label == "Helped today" or help_label == "":
		return "the crew"
	return help_label


func _opening_line(agent_name: String, personality_trait: String, grievance: String) -> String:
	match personality_trait:
		"grizzled":
			return "%s: \"%s We are discussing it before the soil asks for representation.\"" % [agent_name, grievance]
		"hopeful":
			return "%s: \"%s I am staying optimistic, but my eyebrows are not.\"" % [agent_name, grievance]
		"chaotic":
			return "%s: \"%s Explain before I start selling tickets.\"" % [agent_name, grievance]
	return "%s: \"%s\"" % [agent_name, grievance]


func _response_line(personality_trait: String, choice_id: String, patience: float, resolution: float, choice: Dictionary = {}) -> String:
	if choice_id == "call_favor":
		var help_label := _social_credit_help_label(str(choice.get("social_credit_label", "")))
		match personality_trait:
			"grizzled":
				return "Fair. %s counts. Do not make me regret accounting for it." % help_label
			"hopeful":
				return "Fair. %s does count for something. Keep going." % help_label
			"chaotic":
				return "Fine. %s is admissible evidence in friendship court." % help_label

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


func _resource_delta_for(outcome: String) -> Dictionary:
	match outcome:
		"resolved":
			return {"fiber": 1}
	return {}


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
			return -8.0
		"lost_patience":
			return 14.0
		"uneasy_truce":
			return -5.0
		"walked_away":
			return 5.0
	return 0.0


func _crew_boost_seconds_for(outcome: String) -> float:
	match outcome:
		"resolved":
			return 9.0
	return 0.0


func _patience_tax_orders_for(outcome: String) -> int:
	return 1 if outcome == "lost_patience" else 0


func _crafting_demand_for(outcome: String, session: Dictionary) -> Dictionary:
	if outcome != "resolved":
		return {}

	var context: Dictionary = session.get("context", {})
	var demand_hint := str(context.get("demand_hint", "deliver_fence_kit"))
	match demand_hint:
		"growth_run":
			return {}
		"deliver_agent_supply":
			var preference_kind := _preference_followup_demand_kind(session)
			if preference_kind != "":
				return _with_preference_context(_demand_template(preference_kind, session), session)
			return _demand_template(_agent_supply_demand_kind(session), session)
		"deliver_seed_bundle":
			return _demand_template("deliver_seed_bundle", session)
		"deliver_rush_kit":
			return _demand_template("deliver_rush_kit", session)
		"clear_brush":
			return _demand_template("clear_brush", session)
		"harvest_crop":
			return _demand_template("harvest_crop", session)
		"build_fence":
			return _demand_template("build_fence", session)
	return _demand_template("deliver_fence_kit", session)


func _crew_mission_for(outcome: String, session: Dictionary) -> Dictionary:
	if outcome != "resolved":
		return {}

	var context: Dictionary = session.get("context", {})
	var mission_hint := str(context.get("mission_hint", "")).strip_edges()
	if mission_hint == "":
		mission_hint = str(context.get("demand_hint", "")).strip_edges()

	match mission_hint:
		"growth_run":
			var agent_name := str(session.get("agent_name", "Crew"))
			return {
				"label": "%s Growth Run" % agent_name,
				"steps": [
					_demand_template("clear_brush", session),
					_demand_template("harvest_crop", session)
				],
				"completion_resource_delta": {
					"grain": 1
				}
			}
	return {}


func _preference_followup_demand_kind(session: Dictionary) -> String:
	var preference := _active_preference_signal(session)
	if preference.is_empty():
		return ""

	return _first_unblocked_preference_kind(_preference_followup_demand_kinds(session, preference), session)


func _preference_followup_demand_kinds(session: Dictionary, preference: Dictionary) -> Array[String]:
	var label := str(preference.get("label", "")).to_lower()
	if label.contains("seed") or label.contains("spring") or label.contains("harvest") or label.contains("crop"):
		return ["harvest_crop", "deliver_seed_bundle", "clear_brush"]
	if label.contains("rush") or label.contains("hustle") or label.contains("clear") or label.contains("brush") or label.contains("fiber"):
		return ["clear_brush", "deliver_rush_kit", "harvest_crop"]
	if label.contains("fence") or label.contains("boundary"):
		return ["build_fence", "clear_brush", "deliver_fence_kit"]

	match str(session.get("agent_id", "")):
		"marigold":
			return ["harvest_crop", "deliver_seed_bundle", "clear_brush"]
		"chuck":
			return ["clear_brush", "deliver_rush_kit", "harvest_crop"]
		"bert":
			return ["build_fence", "clear_brush", "deliver_fence_kit"]
	return []


func _first_unblocked_preference_kind(ranked_kinds: Array[String], session: Dictionary) -> String:
	var fallback := ""
	for demand_kind in ranked_kinds:
		if fallback == "":
			fallback = demand_kind
		if not _is_preference_kind_blocked(demand_kind, session):
			return demand_kind
	return fallback


func _is_preference_kind_blocked(demand_kind: String, session: Dictionary) -> bool:
	var context: Dictionary = session.get("context", {})
	var history = context.get("demand_history", [])
	if typeof(history) != TYPE_ARRAY:
		return false

	var current_day := int(context.get("day", session.get("day", 1)))
	var agent_id := str(session.get("agent_id", ""))
	for record in history:
		if typeof(record) != TYPE_DICTIONARY:
			continue
		if str(record.get("agent_id", "")) != agent_id:
			continue
		if not _demand_record_matches_kind(record, demand_kind):
			continue

		var status := str(record.get("status", ""))
		if status == "open":
			return true
		var completed_day := int(record.get("completed_day", record.get("created_day", current_day)))
		if status == "done" and current_day - completed_day <= 1:
			return true
	return false


func _demand_record_matches_kind(record: Dictionary, demand_kind: String) -> bool:
	var required_item := _required_item_for_demand_kind(demand_kind)
	if required_item != "":
		return str(record.get("kind", "")) == "deliver_item" and str(record.get("required_item", "")) == required_item
	return str(record.get("kind", "")) == demand_kind


func _required_item_for_demand_kind(demand_kind: String) -> String:
	match demand_kind:
		"deliver_seed_bundle":
			return "seed_bundle"
		"deliver_rush_kit":
			return "rush_kit"
		"deliver_fence_kit":
			return "fence_kit"
	return ""


func _active_preference_signal(session: Dictionary) -> Dictionary:
	var truce_label := str(session.get("truce_label", "")).strip_edges()
	if truce_label != "" and int(session.get("truce_days", 0)) > 0:
		return {
			"source": "truce",
			"label": truce_label
		}

	var remembered_label := str(session.get("remembered_help_label", "")).strip_edges()
	if remembered_label != "":
		return {
			"source": "remembered_help",
			"label": remembered_label
		}
	return {}


func _agent_supply_demand_kind(session: Dictionary) -> String:
	match str(session.get("agent_id", "")):
		"marigold":
			return "deliver_seed_bundle"
		"chuck":
			return "deliver_rush_kit"
	return "deliver_fence_kit"


func _demand_template(demand_kind: String, session: Dictionary) -> Dictionary:
	var agent_name := str(session.get("agent_name", "Crew"))
	var template := {}
	match demand_kind:
		"clear_brush":
			template = {
				"kind": "clear_brush",
				"required_action": "clear_brush",
				"amount": 1,
				"label": "Clear Brush",
				"reason": "%s wants one messy patch cut before more grand plans." % agent_name
			}
		"harvest_crop":
			template = {
				"kind": "harvest_crop",
				"required_action": "harvest_crop",
				"amount": 1,
				"label": "Harvest Crop",
				"reason": "%s wants proof the field can still produce something edible." % agent_name
			}
		"build_fence":
			template = {
				"kind": "build_fence",
				"required_action": "build_fence",
				"amount": 1,
				"label": "Build Fence",
				"reason": "%s wants the kit to become an actual boundary." % agent_name
			}
		"deliver_seed_bundle":
			template = {
				"kind": "deliver_item",
				"required_item": "seed_bundle",
				"amount": 1,
				"label": "Deliver Seed Bundle",
				"reason": "%s wants seed stock before optimism becomes a budget category." % agent_name
			}
		"deliver_rush_kit":
			template = {
				"kind": "deliver_item",
				"required_item": "rush_kit",
				"amount": 1,
				"label": "Deliver Rush Kit",
				"reason": "%s wants velocity with handles on it." % agent_name
			}
		_:
			template = {
				"kind": "deliver_item",
				"required_item": "fence_kit",
				"amount": 1,
				"label": "Deliver Fence Kit",
				"reason": "%s wants proof that the recovery plan has materials behind it." % agent_name
			}
	return template


func _with_preference_context(template: Dictionary, session: Dictionary) -> Dictionary:
	var preference := _active_preference_signal(session)
	if preference.is_empty():
		return template

	var enriched := template.duplicate(true)
	var source := str(preference.get("source", ""))
	var label := str(preference.get("label", ""))
	enriched["preference_source"] = source
	enriched["preference_label"] = label
	match source:
		"truce":
			enriched["reason"] = "%s Truce over %s turned the ask toward %s." % [str(enriched.get("reason", "")), label, str(enriched.get("label", "the next job"))]
		"remembered_help":
			enriched["reason"] = "%s Remembering %s turned the ask toward %s." % [str(enriched.get("reason", "")), label, str(enriched.get("label", "the next job"))]
	return enriched


func _count_recent_failures(events) -> int:
	if typeof(events) != TYPE_ARRAY:
		return 0

	var count := 0
	for event in events:
		if typeof(event) == TYPE_DICTIONARY and str(event.get("type", "")) == "player_action" and not bool(event.get("success", true)):
			count += 1
	return count
