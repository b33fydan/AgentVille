class_name AgentMemory
extends RefCounted

const MAX_OBSERVATIONS := 20
const MAX_ACTIONS := 10

var observations: Array[Dictionary] = []
var actions: Array[Dictionary] = []


func remember_event(event: Dictionary) -> void:
	observations.append(event.duplicate(true))
	if observations.size() > MAX_OBSERVATIONS:
		observations.pop_front()


func remember_action(action_name: String, reason: String, score: float) -> void:
	actions.append({
		"action": action_name,
		"reason": reason,
		"score": score,
		"tick_ms": Time.get_ticks_msec()
	})
	if actions.size() > MAX_ACTIONS:
		actions.pop_front()


func last_player_action() -> Dictionary:
	for i in range(observations.size() - 1, -1, -1):
		var event := observations[i]
		if str(event.get("type", "")) == "player_action":
			return event
	return {}


func recent_failed_player_actions() -> int:
	var count := 0
	for event in observations:
		if str(event.get("type", "")) == "player_action" and not bool(event.get("success", true)):
			count += 1
	return count


func recent_successful_player_actions(action_name: String) -> int:
	var count := 0
	for event in observations:
		if str(event.get("type", "")) != "player_action":
			continue
		if str(event.get("action", "")) == action_name and bool(event.get("success", false)):
			count += 1
	return count
