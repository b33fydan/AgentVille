class_name AgentManager
extends Node3D

signal agent_comment(message: String)
signal agent_world_action(event: Dictionary)
signal crew_updated(snapshots: Array)

const AgentActorScript: Script = preload("res://scripts/ai/AgentActor.gd")

var grid_manager
var event_log
var agents: Array = []

var _focused_agent_index: int = 0


func configure(new_grid_manager, new_event_log) -> void:
	grid_manager = new_grid_manager
	event_log = new_event_log
	if event_log and not event_log.event_recorded.is_connected(_on_event_recorded):
		event_log.event_recorded.connect(_on_event_recorded)


func _ready() -> void:
	_spawn_agents()


func _spawn_agents() -> void:
	for child in get_children():
		child.queue_free()
	agents.clear()

	var configs := [
		{
			"id": "bert",
			"name": "Bert",
			"trait": "grizzled",
			"home_tile": Vector2i(2, 4),
			"body_color": Color("#5c7f9f"),
			"accent_color": Color("#6b4a34"),
			"mood": 46.0,
			"energy": 68.0
		},
		{
			"id": "marigold",
			"name": "Marigold",
			"trait": "hopeful",
			"home_tile": Vector2i(5, 5),
			"body_color": Color("#7faf62"),
			"accent_color": Color("#f0cd5e"),
			"mood": 72.0,
			"energy": 78.0
		},
		{
			"id": "chuck",
			"name": "Chuck",
			"trait": "chaotic",
			"home_tile": Vector2i(8, 4),
			"body_color": Color("#9b6fb6"),
			"accent_color": Color("#e47c53"),
			"mood": 61.0,
			"energy": 84.0
		}
	]

	for config in configs:
		var actor = Node3D.new()
		actor.set_script(AgentActorScript)
		actor.call("setup", config, grid_manager, event_log)
		actor.comment_generated.connect(_on_agent_comment)
		actor.state_changed.connect(_on_agent_state_changed)
		actor.world_action_performed.connect(_on_agent_world_action)
		add_child(actor)
		agents.append(actor)
	crew_updated.emit(get_agent_snapshots())


func _on_event_recorded(event: Dictionary) -> void:
	if agents.is_empty():
		return

	var event_type := str(event.get("type", ""))
	if event_type in ["agent_action", "agent_world_action"]:
		return
	if event_type == "day_summary":
		agent_comment.emit(_summary_comment(event.get("summary", {})))

	var focused_agent = null
	if event_type == "player_action":
		focused_agent = _next_focused_agent()
	for agent in agents:
		agent.call("observe_event", event, agent == focused_agent)
	crew_updated.emit(get_agent_snapshots())


func _next_focused_agent():
	var agent = agents[_focused_agent_index % agents.size()]
	_focused_agent_index += 1
	return agent


func _on_agent_comment(message: String) -> void:
	agent_comment.emit(message)


func _on_agent_world_action(event: Dictionary) -> void:
	agent_world_action.emit(event)
	crew_updated.emit(get_agent_snapshots())


func _on_agent_state_changed(_snapshot: Dictionary) -> void:
	crew_updated.emit(get_agent_snapshots())


func get_agent_snapshots() -> Array:
	var snapshots: Array = []
	for agent in agents:
		snapshots.append(agent.call("get_snapshot"))
	return snapshots


func apply_adversarial_result(result: Dictionary) -> void:
	var target_id := str(result.get("agent_id", ""))
	if target_id == "":
		return

	for agent in agents:
		if str(agent.get("agent_id")) != target_id:
			continue
		agent.call("apply_adversarial_result", result)
		crew_updated.emit(get_agent_snapshots())
		return


func acknowledge_supply_delivery(agent_id: String, item_label: String, payoff_label: String = "") -> void:
	if agent_id == "":
		return

	for agent in agents:
		if str(agent.get("agent_id")) != agent_id:
			continue
		agent.call("acknowledge_supply_delivery", item_label, payoff_label)
		crew_updated.emit(get_agent_snapshots())
		return


func apply_crew_boost(seconds: float, multiplier: float = 1.28) -> void:
	if seconds <= 0.0:
		return

	for agent in agents:
		agent.call("apply_crew_boost", seconds, multiplier)
	crew_updated.emit(get_agent_snapshots())


func assign_work_order(order: Dictionary) -> bool:
	if agents.is_empty():
		return false

	var agent = _next_available_agent()
	if agent == null:
		return false

	agent.call("start_work_order", order)
	agent_comment.emit("%s: \"On it. Fence kit in hand.\"" % str(agent.display_name))
	return true


func assign_directive(action_name: String, target_tile: Vector2i, reason: String, extra: Dictionary = {}) -> bool:
	if agents.is_empty():
		return false

	var agent = _next_available_agent()
	if agent == null:
		return false

	agent.call("start_directive", action_name, target_tile, reason, extra)
	agent_comment.emit("%s: \"I will handle %s.\"" % [str(agent.display_name), reason])
	return true


func has_available_agent() -> bool:
	return _next_available_agent(false) != null


func _next_available_agent(advance_index: bool = true):
	for offset in range(agents.size()):
		var index := (_focused_agent_index + offset) % agents.size()
		var agent = agents[index]
		if bool(agent.call("is_available")):
			if advance_index:
				_focused_agent_index = index + 1
			return agent
	return null


func _summary_comment(summary: Dictionary) -> String:
	if agents.is_empty():
		return "Crew: \"No one saw anything. Suspicious.\""

	var speaker = _next_focused_agent()
	var snapshot: Dictionary = speaker.call("get_snapshot")
	var name := str(snapshot.get("name", "Crew"))
	var personality := str(snapshot.get("trait", "steady"))
	var total := int(summary.get("total_player_actions", 0))
	var failed := int(summary.get("failed_player_actions", 0))
	var harvest_value := int(summary.get("harvest_value", 0))
	var agent_harvest_value := int(summary.get("agent_harvest_value", 0))
	var top_action := str(summary.get("top_action", "work"))
	var vibe: Dictionary = summary.get("vibe", {})
	var vibe_label := str(vibe.get("label", "mixed"))
	var vibe_reasons: Array = vibe.get("reasons", [])
	var first_reason := str(vibe_reasons[0]) if not vibe_reasons.is_empty() else "the day happened"

	if total == 0:
		match personality:
			"grizzled":
				return "%s: \"Neglectful day. Even the weeds looked under-managed.\"" % name
			"hopeful":
				return "%s: \"Quiet day. Tomorrow can still earn its keep. Please let it.\"" % name
			"chaotic":
				return "%s: \"No farm work? Bold performance art.\"" % name

	if vibe_label == "chaotic":
		match personality:
			"grizzled":
				return "%s: \"Chaotic day: %s. I am putting the farm on emotional probation.\"" % [name, first_reason]
			"hopeful":
				return "%s: \"Chaotic day, but recoverable. %s is not the end of the story.\"" % [name, first_reason.capitalize()]
			"chaotic":
				return "%s: \"Chaotic day. %s. Horrible. Fascinating. Continue.\"" % [name, first_reason.capitalize()]

	if vibe_label == "productive":
		match personality:
			"grizzled":
				return "%s: \"Productive day. %s. I will complain quieter.\"" % [name, first_reason.capitalize()]
			"hopeful":
				return "%s: \"Productive day. %s, and the farm felt it.\"" % [name, first_reason.capitalize()]
			"chaotic":
				return "%s: \"Productive day. %s. Capitalism has entered the vegetables.\"" % [name, first_reason.capitalize()]

	if vibe_label == "careful":
		match personality:
			"grizzled":
				return "%s: \"Careful day. No drama, which is suspicious but useful.\"" % name
			"hopeful":
				return "%s: \"Careful day. The farm likes a steady hand.\"" % name
			"chaotic":
				return "%s: \"Careful day. Disturbingly competent. I am bored and proud.\"" % name

	if failed >= 3:
		match personality:
			"grizzled":
				return "%s: \"%s misses in one day. The soil filed a complaint.\"" % [name, failed]
			"hopeful":
				return "%s: \"%s misses, but the farm is still standing. Barely counts as progress.\"" % [name, failed]
			"chaotic":
				return "%s: \"%s misses. Messy, memorable, marketable.\"" % [name, failed]

	if harvest_value > 0:
		match personality:
			"grizzled":
				return "%s: \"%s coins harvested. I will postpone my lecture.\"" % [name, harvest_value]
			"hopeful":
				return "%s: \"%s coins harvested. That is a good little rhythm.\"" % [name, harvest_value]
			"chaotic":
				return "%s: \"%s coins harvested. Capitalism survives another sunrise.\"" % [name, harvest_value]

	if agent_harvest_value > 0:
		match personality:
			"grizzled":
				return "%s: \"Crew pulled %s coins without supervision. Troublingly efficient.\"" % [name, agent_harvest_value]
			"hopeful":
				return "%s: \"Crew added %s coins today. We are learning the farm's rhythm.\"" % [name, agent_harvest_value]
			"chaotic":
				return "%s: \"Crew harvested %s coins. Autonomous vegetables beware.\"" % [name, agent_harvest_value]

	return "%s: \"Mostly %s today. I am writing that down.\"" % [name, top_action]
