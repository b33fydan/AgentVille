class_name AgentDialogueLibrary
extends RefCounted


func line_for(agent_state: Dictionary, reaction: Dictionary, event: Dictionary) -> String:
	var personality := str(agent_state.get("trait", "steady"))
	var expression := str(reaction.get("expression", "neutral"))
	var action := _pretty_action(str(event.get("action", "work")))
	var lines := _lines(personality, expression, action)
	if lines.is_empty():
		return ""
	return str(lines[randi() % lines.size()])


func _pretty_action(action_name: String) -> String:
	return action_name.replace("_", " ")


func _lines(personality: String, expression: String, action: String) -> Array[String]:
	match expression:
		"pleased":
			match personality:
				"grizzled":
					return [
						"That %s almost looked intentional. I am unsettled." % action,
						"Fine. The %s was competent. I will update the complaint ledger." % action
					]
				"hopeful":
					return [
						"Good %s. See, the farm responds to effort." % action,
						"That %s helped. Tiny victory, real victory." % action
					]
				"chaotic":
					return [
						"A clean %s? I had money on disaster." % action,
						"The %s worked. Weird day for entropy." % action
					]
		"side_eye":
			match personality:
				"grizzled":
					return [
						"Really? That %s was your plan?" % action,
						"I have seen scarecrows make a better %s decision." % action
					]
				"hopeful":
					return [
						"That %s did not land, but I am choosing optimism under protest." % action,
						"Small setback. Large facial expression."
					]
				"chaotic":
					return [
						"That %s was a mess. I respect the commitment." % action,
						"Bold %s. Incorrect, but bold." % action
					]
		"annoyed":
			match personality:
				"grizzled":
					return [
						"The farm saw that %s and asked for a manager." % action,
						"I am seconds from filing a soil incident report."
					]
				"hopeful":
					return [
						"We can recover from this %s. Probably. Maybe." % action,
						"I believe in you, which is becoming expensive."
					]
				"chaotic":
					return [
						"The %s failed so loudly I heard it emotionally." % action,
						"Congratulations, the map is judging you now."
					]
		"angry":
			match personality:
				"grizzled":
					return [
						"No. Look at me. Then look at that %s. Explain." % action,
						"This farm deserves hazard pay and I am the hazard."
					]
				"hopeful":
					return [
						"I am still rooting for you, but my face has resigned.",
						"Deep breath. For me, mostly."
					]
				"chaotic":
					return [
						"I blinked and the %s became a cautionary tale." % action,
						"Impressive. You weaponized confusion."
					]
	return []
