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


func is_grid_pos_occupied(grid_pos: Vector2i) -> bool:
	if grid_manager == null:
		return false
	for agent in agents:
		var occupied_tile = grid_manager.get_tile_from_world(agent.position)
		if occupied_tile != null and occupied_tile.grid_pos == grid_pos:
			return true
	return false


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


func absorb_order_escalation_with_truce(agent_id: String, order_label: String) -> Dictionary:
	if agent_id == "":
		return {}

	for agent in agents:
		if str(agent.get("agent_id")) != agent_id:
			continue
		var receipt: Dictionary = agent.call("try_absorb_order_escalation_with_truce", order_label)
		if not receipt.is_empty():
			crew_updated.emit(get_agent_snapshots())
		return receipt
	return {}


func has_active_truce(agent_id: String) -> bool:
	if agent_id == "":
		return false

	for agent in agents:
		if str(agent.get("agent_id")) != agent_id:
			continue
		var snapshot: Dictionary = agent.call("get_snapshot")
		return int(snapshot.get("truce_days", 0)) > 0 and str(snapshot.get("truce_label", "")) != ""
	return false


func acknowledge_supply_delivery(agent_id: String, item_label: String, payoff_label: String = "") -> void:
	if agent_id == "":
		return

	for agent in agents:
		if str(agent.get("agent_id")) != agent_id:
			continue
		agent.call("acknowledge_supply_delivery", item_label, payoff_label)
		crew_updated.emit(get_agent_snapshots())
		return


func acknowledge_completed_authored_order(agent_id: String, order_label: String) -> void:
	if agent_id == "":
		return

	for agent in agents:
		if str(agent.get("agent_id")) != agent_id:
			continue
		agent.call("acknowledge_completed_authored_order", order_label)
		crew_updated.emit(get_agent_snapshots())
		return


func acknowledge_completed_mission(agent_id: String, mission_label: String, origin_source: String = "", origin_label: String = "") -> void:
	if agent_id == "":
		return

	for agent in agents:
		if str(agent.get("agent_id")) != agent_id:
			continue
		agent.call("acknowledge_completed_mission", mission_label, origin_source, origin_label)
		crew_updated.emit(get_agent_snapshots())
		return


func remember_ignored_ask(agent_id: String, order_label: String) -> void:
	if agent_id == "":
		return

	for agent in agents:
		if str(agent.get("agent_id")) != agent_id:
			continue
		agent.call("remember_ignored_ask", order_label)
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
	var helped_agents: Dictionary = summary.get("helped_agents", {})
	var helped_names := _format_helped_agent_names(helped_agents)
	var favored_agents: Dictionary = summary.get("favored_agents", {})
	var favor_names := _format_called_favor_names(favored_agents)
	var remembered_help_sessions: Dictionary = summary.get("remembered_help_sessions", {})
	var memory_names := _format_remembered_help_session_names(remembered_help_sessions)
	var social_autonomy_names := _format_agent_social_preference_names(summary.get("agent_social_preference_actions", {}))
	var completed_mission_names := _format_completed_crew_mission_names(summary.get("crew_missions", {}))
	var work_order_events: Dictionary = summary.get("work_order_events", {})
	var truce_delayed_orders := int(work_order_events.get("truce_delayed", 0))

	if truce_delayed_orders > 0:
		var order_text := "%s order%s" % [truce_delayed_orders, "" if truce_delayed_orders == 1 else "s"]
		match personality:
			"grizzled":
				return "%s: \"Truce held on %s. Pressure postponed, not forgotten.\"" % [name, order_text]
			"hopeful":
				return "%s: \"The truce held on %s. That bought the farm a calmer morning.\"" % [name, order_text]
			"chaotic":
				return "%s: \"Truce held on %s. Emotional duct tape, but surprisingly load-bearing.\"" % [name, order_text]

	if memory_names != "":
		match personality:
			"grizzled":
				return "%s: \"Remembered %s during Parley. Context logged; still not a blank check.\"" % [name, memory_names]
			"hopeful":
				return "%s: \"Remembered %s during Parley. That kind of care keeps the room warmer.\"" % [name, memory_names]
			"chaotic":
				return "%s: \"Remembered %s during Parley. Friendship ledger glittered, allegedly.\"" % [name, memory_names]

	if completed_mission_names != "":
		match personality:
			"grizzled":
				return "%s: \"Mission complete: %s. Source context held all the way through.\"" % [name, completed_mission_names]
			"hopeful":
				return "%s: \"Mission complete: %s. That is a real run with a clean receipt.\"" % [name, completed_mission_names]
			"chaotic":
				return "%s: \"Mission complete: %s. Tiny plan, actual follow-through. Thrilling.\"" % [name, completed_mission_names]

	if social_autonomy_names != "":
		match personality:
			"grizzled":
				return "%s: \"Crew followed %s on their own. Fine. Useful initiative.\"" % [name, social_autonomy_names]
			"hopeful":
				return "%s: \"Crew followed %s on their own. That is real relationship momentum.\"" % [name, social_autonomy_names]
			"chaotic":
				return "%s: \"Crew followed %s on their own. Feelings became farm labor. Incredible.\"" % [name, social_autonomy_names]

	if total == 0:
		match personality:
			"grizzled":
				return "%s: \"Neglectful day. Even the weeds looked under-managed.\"" % name
			"hopeful":
				return "%s: \"Quiet day. Tomorrow can still earn its keep. Please let it.\"" % name
			"chaotic":
				return "%s: \"No farm work? Bold performance art.\"" % name

	if favor_names != "":
		match personality:
			"grizzled":
				return "%s: \"Called %s today. Goodwill spent cleanly, which beats pretending it was infinite.\"" % [name, favor_names]
			"hopeful":
				return "%s: \"Called %s today. A spent favor can still be honest relationship work.\"" % [name, favor_names]
			"chaotic":
				return "%s: \"Called %s today. Friendship coupon redeemed; paperwork sparkly.\"" % [name, favor_names]

	if helped_names != "":
		match personality:
			"grizzled":
				return "%s: \"Helped %s today. Practical debts paid, for once.\"" % [name, helped_names]
			"hopeful":
				return "%s: \"Helped %s today. That kind of care lands.\"" % [name, helped_names]
			"chaotic":
				return "%s: \"Helped %s today. Friendship paperwork filed.\"" % [name, helped_names]

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


func _format_helped_agent_names(helped_agents: Dictionary) -> String:
	var names: Array[String] = []
	for agent_id in helped_agents.keys():
		var receipt: Dictionary = helped_agents.get(agent_id, {})
		var helped_name := str(receipt.get("name", str(agent_id).capitalize()))
		if helped_name != "" and not names.has(helped_name):
			names.append(helped_name)
	names.sort()
	return _join_names(names)


func _format_called_favor_names(favored_agents: Dictionary) -> String:
	var names: Array[String] = []
	for agent_id in favored_agents.keys():
		var receipt: Dictionary = favored_agents.get(agent_id, {})
		var favored_name := str(receipt.get("name", str(agent_id).capitalize()))
		if favored_name == "":
			continue
		var count := int(receipt.get("called_favors", 0))
		var label := "%s's favor" % favored_name
		if count > 1:
			label += " x%s" % count
		if not names.has(label):
			names.append(label)
	names.sort()
	return _join_names(names)


func _format_remembered_help_session_names(memory_sessions: Dictionary) -> String:
	var names: Array[String] = []
	for agent_id in memory_sessions.keys():
		var receipt: Dictionary = memory_sessions.get(agent_id, {})
		var remembered_name := str(receipt.get("name", str(agent_id).capitalize()))
		var memory_label := str(receipt.get("last_memory_label", ""))
		if remembered_name == "" or memory_label == "":
			continue
		var count := int(receipt.get("memory_context_sessions", 0))
		var label := "%s's %s" % [remembered_name, memory_label]
		if count > 1:
			label += " x%s" % count
		if not names.has(label):
			names.append(label)
	names.sort()
	return _join_names(names)


func _format_agent_social_preference_names(social_actions) -> String:
	if typeof(social_actions) != TYPE_DICTIONARY:
		return ""

	var names: Array[String] = []
	for agent_id in social_actions.keys():
		var receipt: Dictionary = social_actions.get(agent_id, {})
		var social_name := str(receipt.get("name", str(agent_id).capitalize()))
		var label := str(receipt.get("last_label", ""))
		var source := _readable_social_preference_source(str(receipt.get("last_source", "")))
		if social_name == "" or label == "":
			continue
		var detail := "%s's %s" % [social_name, label]
		if source != "":
			detail += " %s" % source
		var origin_detail := _format_social_preference_origin_detail(receipt)
		if origin_detail != "":
			detail += " (%s)" % origin_detail
		var count := int(receipt.get("actions", 0))
		if count > 1:
			detail += " x%s" % count
		if not names.has(detail):
			names.append(detail)
	names.sort()
	return _join_names(names)


func _format_social_preference_origin_detail(receipt: Dictionary) -> String:
	var origin_source := str(receipt.get("last_origin_source", "")).strip_edges()
	var origin_label := str(receipt.get("last_origin_label", "")).strip_edges()
	if origin_source == "" or origin_label == "":
		return ""
	return "%s: %s" % [_readable_social_preference_source(origin_source), origin_label]


func _format_completed_crew_mission_names(crew_missions) -> String:
	if typeof(crew_missions) != TYPE_DICTIONARY:
		return ""

	var names: Array[String] = []
	for mission_id in crew_missions.keys():
		var receipt: Dictionary = crew_missions.get(mission_id, {})
		if str(receipt.get("status", "")) != "done":
			continue
		var mission_label := str(receipt.get("label", "Crew Mission")).strip_edges()
		var agent_name := str(receipt.get("agent_name", "")).strip_edges()
		var detail := mission_label if mission_label != "" else "Crew Mission"
		if agent_name != "" and not detail.contains(agent_name):
			detail = "%s's %s" % [agent_name, detail]
		var source := _readable_social_preference_source(str(receipt.get("preference_source", "")))
		var label := str(receipt.get("preference_label", "")).strip_edges()
		if source != "" and label != "":
			detail += " [%s: %s]" % [source, label]
		elif source != "":
			detail += " [%s]" % source
		elif label != "":
			detail += " [%s]" % label
		if not names.has(detail):
			names.append(detail)
	names.sort()
	return _join_names(names)


func _readable_social_preference_source(source: String) -> String:
	match source.strip_edges():
		"memory", "remembered_help":
			return "Memory"
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
	return source.replace("_", " ").capitalize()


func _join_names(names: Array[String]) -> String:
	if names.is_empty():
		return ""
	if names.size() == 1:
		return names[0]
	if names.size() == 2:
		return "%s and %s" % [names[0], names[1]]
	var last := names[names.size() - 1]
	var head := names.slice(0, names.size() - 1)
	return "%s, and %s" % [", ".join(head), last]
