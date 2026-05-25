class_name AgentReactionModel
extends RefCounted


func score_event(agent_state: Dictionary, event: Dictionary, focus: bool = false) -> Dictionary:
	var event_type := str(event.get("type", ""))
	if event_type != "player_action" and event_type != "work_order":
		return {}
	if event_type == "player_action" and not focus:
		return {}

	var success := bool(event.get("success", true))
	var action := str(event.get("action", "work"))
	var multiplier := 1.35 if focus else 1.0
	var irritation_delta := 0.0
	var mood_delta := 0.0
	var expression := "neutral"
	var tag := ""

	if success:
		mood_delta = 1.4 * multiplier
		irritation_delta = -2.4 * multiplier
		expression = "pleased"
		tag = "approve_%s" % action
	else:
		mood_delta = -2.7 * multiplier
		irritation_delta = 8.0 * multiplier
		expression = "side_eye"
		tag = "fail_%s" % action

	var current_irritation := clampf(float(agent_state.get("irritation", 0.0)) + irritation_delta, 0.0, 100.0)
	if current_irritation >= 55.0:
		expression = "angry"
	elif current_irritation >= 28.0:
		expression = "annoyed"
	elif current_irritation >= 12.0 and not success:
		expression = "side_eye"

	return {
		"mood_delta": mood_delta,
		"irritation_delta": irritation_delta,
		"expression": expression,
		"line_tag": tag,
		"intensity": clampf(abs(irritation_delta) / 10.0, 0.0, 1.0)
	}
