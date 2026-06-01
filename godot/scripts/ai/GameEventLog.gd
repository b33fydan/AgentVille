class_name GameEventLog
extends Node

signal event_recorded(event: Dictionary)

const PlayerVibeScorerScript := preload("res://scripts/ai/PlayerVibeScorer.gd")
const MAX_EVENTS := 240

var events: Array[Dictionary] = []
var _vibe_scorer = PlayerVibeScorerScript.new()


func record_event(event_type: String, payload: Dictionary = {}) -> Dictionary:
	var event := payload.duplicate(true)
	event["type"] = event_type
	event["tick_ms"] = Time.get_ticks_msec()
	events.append(event)
	if events.size() > MAX_EVENTS:
		events.pop_front()
	event_recorded.emit(event)
	return event


func get_recent_events(limit: int = 20) -> Array[Dictionary]:
	var start_index := maxi(0, events.size() - limit)
	var result: Array[Dictionary] = []
	for i in range(start_index, events.size()):
		result.append(events[i])
	return result


func build_day_summary(day: int) -> Dictionary:
	var summary := {
		"day": day,
		"player_actions": {},
		"agent_actions": {},
		"agent_world_actions": {},
		"agent_social_preference_actions": {},
		"agent_intention_actions": {},
		"successful_player_actions": 0,
		"failed_player_actions": 0,
		"harvest_value": 0,
		"agent_harvest_value": 0,
		"resources_gained": {},
		"crafted_items": {},
		"craft_count": 0,
		"work_order_events": {},
		"helped_agents": {},
		"completed_agent_demands": 0,
		"supply_delivery_count": 0,
		"adversarial_sessions": {},
		"adversarial_session_count": 0,
		"resolved_adversarial_sessions": 0,
		"called_favors": 0,
		"favored_agents": {},
		"memory_context_sessions": 0,
		"remembered_help_sessions": {},
		"total_player_actions": 0,
		"top_action": "none",
		"notable_events": [],
		"vibe": {}
	}

	for event in events:
		if int(event.get("day", day)) != day:
			continue

		match str(event.get("type", "")):
			"player_action":
				var action := str(event.get("action", "unknown"))
				summary["player_actions"][action] = int(summary["player_actions"].get(action, 0)) + 1
				summary["total_player_actions"] += 1
				if not bool(event.get("success", true)):
					summary["failed_player_actions"] += 1
					summary["notable_events"].append(event)
				else:
					summary["successful_player_actions"] += 1
					if action == "harvest" or int(event.get("value", 0)) > 0:
						summary["harvest_value"] += int(event.get("value", 0))
					_add_resource_summary(summary, event.get("resources", {}))
			"agent_action":
				var agent_id := str(event.get("agent_id", "agent"))
				summary["agent_actions"][agent_id] = int(summary["agent_actions"].get(agent_id, 0)) + 1
			"agent_world_action":
				var action_name := str(event.get("action", "work"))
				summary["agent_world_actions"][action_name] = int(summary["agent_world_actions"].get(action_name, 0)) + 1
				summary["agent_harvest_value"] += int(event.get("value", 0))
				_add_resource_summary(summary, event.get("resources", {}))
				_add_agent_social_preference_summary(summary, event)
				_add_agent_intention_summary(summary, event)
			"craft_action":
				var recipe_id := str(event.get("recipe_id", "recipe"))
				summary["crafted_items"][recipe_id] = int(summary["crafted_items"].get(recipe_id, 0)) + 1
				summary["craft_count"] += 1
				if _is_player_craft_source(str(event.get("source", ""))):
					_count_successful_player_action(summary, "craft")
			"work_order":
				var status := str(event.get("status", "unknown"))
				summary["work_order_events"][status] = int(summary["work_order_events"].get(status, 0)) + 1
			"crafting_demand":
				var status := str(event.get("status", "unknown"))
				if status == "done":
					summary["completed_agent_demands"] += 1
					_add_helped_agent_summary(summary, event)
					if str(event.get("kind", "")) == "deliver_item":
						summary["supply_delivery_count"] += 1
						_count_successful_player_action(summary, "deliver_supply")
			"adversarial_session":
				var outcome := str(event.get("outcome", "unknown"))
				summary["adversarial_sessions"][outcome] = int(summary["adversarial_sessions"].get(outcome, 0)) + 1
				summary["adversarial_session_count"] += 1
				if outcome in ["resolved", "uneasy_truce"]:
					summary["resolved_adversarial_sessions"] += 1
				if bool(event.get("social_credit_used", false)):
					summary["called_favors"] += 1
					_add_called_favor_summary(summary, event)
				if str(event.get("remembered_help_label", "")) != "":
					summary["memory_context_sessions"] += 1
					_add_remembered_help_session_summary(summary, event)
				summary["notable_events"].append(event)

	var top_action := "none"
	var top_count := 0
	for action in summary["player_actions"].keys():
		var count := int(summary["player_actions"][action])
		if count > top_count:
			top_action = str(action)
			top_count = count
	summary["top_action"] = top_action
	summary["vibe"] = _vibe_scorer.score_summary(summary)

	return summary


func _is_player_craft_source(source: String) -> bool:
	return source == "" or source.begins_with("player")


func _count_successful_player_action(summary: Dictionary, action: String) -> void:
	summary["player_actions"][action] = int(summary["player_actions"].get(action, 0)) + 1
	summary["total_player_actions"] += 1
	summary["successful_player_actions"] += 1


func _add_helped_agent_summary(summary: Dictionary, event: Dictionary) -> void:
	var agent_id := str(event.get("agent_id", ""))
	if agent_id == "":
		return

	var helped_agents: Dictionary = summary["helped_agents"]
	var receipt: Dictionary = helped_agents.get(agent_id, {
		"name": str(event.get("agent_name", "Crew")),
		"completed_demands": 0,
		"supply_deliveries": 0
	})
	receipt["name"] = str(event.get("agent_name", receipt.get("name", "Crew")))
	receipt["completed_demands"] = int(receipt.get("completed_demands", 0)) + 1
	if str(event.get("kind", "")) == "deliver_item":
		receipt["supply_deliveries"] = int(receipt.get("supply_deliveries", 0)) + 1
	helped_agents[agent_id] = receipt
	summary["helped_agents"] = helped_agents


func _add_agent_social_preference_summary(summary: Dictionary, event: Dictionary) -> void:
	if not bool(event.get("success", false)):
		return

	var source := str(event.get("social_preference_source", "")).strip_edges()
	var label := str(event.get("social_preference_label", "")).strip_edges()
	var agent_id := str(event.get("agent_id", ""))
	if source == "" or label == "" or agent_id == "":
		return

	var social_actions: Dictionary = summary["agent_social_preference_actions"]
	var receipt: Dictionary = social_actions.get(agent_id, {
		"name": str(event.get("agent_name", "Crew")),
		"actions": 0,
		"last_source": "",
		"last_label": ""
	})
	receipt["name"] = str(event.get("agent_name", receipt.get("name", "Crew")))
	receipt["actions"] = int(receipt.get("actions", 0)) + 1
	receipt["last_source"] = source
	receipt["last_label"] = label
	social_actions[agent_id] = receipt
	summary["agent_social_preference_actions"] = social_actions


func _add_agent_intention_summary(summary: Dictionary, event: Dictionary) -> void:
	if not bool(event.get("success", false)):
		return

	var intention_id := str(event.get("daily_intention_id", "")).strip_edges()
	var intention_label := str(event.get("daily_intention_label", "")).strip_edges()
	var agent_id := str(event.get("agent_id", ""))
	if intention_id == "" or intention_label == "" or agent_id == "":
		return

	var intention_actions: Dictionary = summary["agent_intention_actions"]
	var receipt: Dictionary = intention_actions.get(agent_id, {
		"name": str(event.get("agent_name", "Crew")),
		"actions": 0,
		"last_intention_id": "",
		"last_intention_label": ""
	})
	receipt["name"] = str(event.get("agent_name", receipt.get("name", "Crew")))
	receipt["actions"] = int(receipt.get("actions", 0)) + 1
	receipt["last_intention_id"] = intention_id
	receipt["last_intention_label"] = intention_label
	intention_actions[agent_id] = receipt
	summary["agent_intention_actions"] = intention_actions


func _add_called_favor_summary(summary: Dictionary, event: Dictionary) -> void:
	var agent_id := str(event.get("agent_id", ""))
	if agent_id == "":
		return

	var favored_agents: Dictionary = summary["favored_agents"]
	var receipt: Dictionary = favored_agents.get(agent_id, {
		"name": str(event.get("agent_name", "Crew")),
		"called_favors": 0,
		"last_favor_label": ""
	})
	receipt["name"] = str(event.get("agent_name", receipt.get("name", "Crew")))
	receipt["called_favors"] = int(receipt.get("called_favors", 0)) + 1
	receipt["last_favor_label"] = _favor_help_label(str(event.get("social_credit_label", "")))
	favored_agents[agent_id] = receipt
	summary["favored_agents"] = favored_agents


func _add_remembered_help_session_summary(summary: Dictionary, event: Dictionary) -> void:
	var agent_id := str(event.get("agent_id", ""))
	if agent_id == "":
		return

	var remembered_sessions: Dictionary = summary["remembered_help_sessions"]
	var receipt: Dictionary = remembered_sessions.get(agent_id, {
		"name": str(event.get("agent_name", "Crew")),
		"memory_context_sessions": 0,
		"last_memory_label": ""
	})
	receipt["name"] = str(event.get("agent_name", receipt.get("name", "Crew")))
	receipt["memory_context_sessions"] = int(receipt.get("memory_context_sessions", 0)) + 1
	receipt["last_memory_label"] = str(event.get("remembered_help_label", ""))
	remembered_sessions[agent_id] = receipt
	summary["remembered_help_sessions"] = remembered_sessions


func _favor_help_label(social_credit_label: String) -> String:
	var help_label := social_credit_label.replace("Helped today: ", "")
	if help_label == "" or help_label == "Helped today":
		return "the crew"
	return help_label


func _add_resource_summary(summary: Dictionary, gains) -> void:
	if typeof(gains) != TYPE_DICTIONARY:
		return

	for resource_id in gains.keys():
		var amount := int(gains[resource_id])
		if amount <= 0:
			continue
		summary["resources_gained"][resource_id] = int(summary["resources_gained"].get(resource_id, 0)) + amount
