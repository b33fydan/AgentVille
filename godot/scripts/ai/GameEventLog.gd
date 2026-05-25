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
		"successful_player_actions": 0,
		"failed_player_actions": 0,
		"harvest_value": 0,
		"agent_harvest_value": 0,
		"resources_gained": {},
		"crafted_items": {},
		"craft_count": 0,
		"work_order_events": {},
		"adversarial_sessions": {},
		"adversarial_session_count": 0,
		"resolved_adversarial_sessions": 0,
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
			"craft_action":
				var recipe_id := str(event.get("recipe_id", "recipe"))
				summary["crafted_items"][recipe_id] = int(summary["crafted_items"].get(recipe_id, 0)) + 1
				summary["craft_count"] += 1
			"work_order":
				var status := str(event.get("status", "unknown"))
				summary["work_order_events"][status] = int(summary["work_order_events"].get(status, 0)) + 1
			"adversarial_session":
				var outcome := str(event.get("outcome", "unknown"))
				summary["adversarial_sessions"][outcome] = int(summary["adversarial_sessions"].get(outcome, 0)) + 1
				summary["adversarial_session_count"] += 1
				if outcome in ["resolved", "uneasy_truce"]:
					summary["resolved_adversarial_sessions"] += 1
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


func _add_resource_summary(summary: Dictionary, gains) -> void:
	if typeof(gains) != TYPE_DICTIONARY:
		return

	for resource_id in gains.keys():
		var amount := int(gains[resource_id])
		if amount <= 0:
			continue
		summary["resources_gained"][resource_id] = int(summary["resources_gained"].get(resource_id, 0)) + amount
