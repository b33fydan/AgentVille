class_name AgentActor
extends Node3D

signal comment_generated(message: String)
signal state_changed(snapshot: Dictionary)
signal world_action_performed(event: Dictionary)

const VoxelFactory := preload("res://scripts/core/Voxel.gd")
const AgentMemoryScript := preload("res://scripts/ai/AgentMemory.gd")
const UtilityAgentDecisionModelScript := preload("res://scripts/ai/UtilityAgentDecisionModel.gd")
const AgentReactionModelScript := preload("res://scripts/ai/AgentReactionModel.gd")
const AgentDialogueLibraryScript := preload("res://scripts/ai/AgentDialogueLibrary.gd")
const ARRIVAL_DISTANCE := 0.04
const WORK_SECONDS := 0.58

var agent_id: String = "agent"
var display_name: String = "Agent"
var personality_trait: String = "steady"
var home_tile: Vector2i = Vector2i.ZERO
var current_grid_pos: Vector2i = Vector2i.ZERO
var target_grid_pos: Vector2i = Vector2i.ZERO
var state: Dictionary = {}
var memory = AgentMemoryScript.new()
var decision_model = UtilityAgentDecisionModelScript.new()
var reaction_model = AgentReactionModelScript.new()
var dialogue_library = AgentDialogueLibraryScript.new()
var move_speed: float = 1.85

var grid_manager
var event_log

var _body_color := Color("#5e8ec7")
var _accent_color := Color("#f2cf6b")
var _skin_color := Color("#ffd8aa")
var _visual_root: Node3D
var _head: MeshInstance3D
var _mood_pip: MeshInstance3D
var _face_label: Label3D
var _reason_badge: Label3D
var _reason_badge_plate: MeshInstance3D
var _reason_badge_last_text: String = ""
var _reason_badge_pulse: float = 0.0
var _target_position := Vector3.ZERO
var _decision_timer: float = 1.5
var _pending_focus_event: Dictionary = {}
var _walk_phase: float = 0.0
var _reaction_shake_phase: float = 0.0
var _active_decision: Dictionary = {}
var _arrival_action_done: bool = false
var _work_timer: float = 0.0
var _morale_boost_timer: float = 0.0
var _morale_speed_multiplier: float = 1.0


func setup(config: Dictionary, new_grid_manager, new_event_log) -> void:
	agent_id = str(config.get("id", agent_id))
	display_name = str(config.get("name", display_name))
	personality_trait = str(config.get("trait", personality_trait))
	home_tile = config.get("home_tile", home_tile)
	current_grid_pos = home_tile
	target_grid_pos = home_tile
	_body_color = config.get("body_color", _body_color)
	_accent_color = config.get("accent_color", _accent_color)
	_skin_color = config.get("skin_color", _skin_color)
	grid_manager = new_grid_manager
	event_log = new_event_log
	var daily_intention := _daily_intention_for_trait(personality_trait)
	state = {
		"id": agent_id,
		"name": display_name,
		"trait": personality_trait,
		"energy": float(config.get("energy", 72.0)),
		"mood": float(config.get("mood", 58.0)),
		"friendship": float(config.get("friendship", 50.0)),
		"irritation": float(config.get("irritation", 0.0)),
		"expression": "neutral",
		"reaction_intensity": 0.0,
		"helped_today": 0,
		"recent_help_label": "",
		"favor_spent_today": 0,
		"recent_spent_favor_label": "",
		"remembered_help_label": "",
		"remembered_help_days": 0,
		"memory_discussed_today": 0,
		"recent_discussed_memory_label": "",
		"truce_label": "",
		"truce_days": 0,
		"truce_absorbed_today": 0,
		"completed_authored_order_today": 0,
		"recent_completed_order_label": "",
		"completed_mission_today": 0,
		"recent_completed_mission_label": "",
		"recent_completed_mission_origin_source": "",
		"recent_completed_mission_origin_label": "",
		"ignored_ask_today": 0,
		"recent_ignored_ask_label": "",
		"memory_consequence_source": "",
		"memory_consequence_label": "",
		"memory_consequence_origin_source": "",
		"memory_consequence_origin_label": "",
		"memory_consequence_days": 0,
		"active_social_preference_source": "",
		"active_social_preference_label": "",
		"active_social_preference_origin_source": "",
		"active_social_preference_origin_label": "",
		"daily_intention_id": str(daily_intention.get("id", "")),
		"daily_intention_label": str(daily_intention.get("label", "")),
		"daily_intention_focus": str(daily_intention.get("focus", "")),
		"current_action": "idle",
		"current_phase": "idle"
	}


func _ready() -> void:
	_build_visual()
	_reset_position()
	_decision_timer = randf_range(0.6, 2.2)
	state_changed.emit(get_snapshot())


func _process(delta: float) -> void:
	_update_morale_boost(delta)
	_update_movement(delta)
	_update_visual_motion(delta)

	if not _active_decision.is_empty():
		_update_active_decision(delta)
		return

	_decision_timer -= delta
	if _decision_timer <= 0.0:
		_choose_next_action()


func observe_event(event: Dictionary, focus: bool = false) -> void:
	memory.remember_event(event)

	if str(event.get("type", "")) == "day_advanced":
		_roll_daily_social_credit_into_memory()
		state["energy"] = minf(100.0, float(state.get("energy", 60.0)) + 24.0)
		state["helped_today"] = 0
		state["recent_help_label"] = ""
		state["favor_spent_today"] = 0
		state["recent_spent_favor_label"] = ""
		state["memory_discussed_today"] = 0
		state["recent_discussed_memory_label"] = ""
		state["completed_authored_order_today"] = 0
		state["recent_completed_order_label"] = ""
		state["completed_mission_today"] = 0
		state["recent_completed_mission_label"] = ""
		state["recent_completed_mission_origin_source"] = ""
		state["recent_completed_mission_origin_label"] = ""
		state["ignored_ask_today"] = 0
		state["recent_ignored_ask_label"] = ""
		_refresh_daily_intention()
		_decision_timer = minf(_decision_timer, 0.8)
		state_changed.emit(get_snapshot())
		return

	var reaction: Dictionary = reaction_model.score_event(state, event, focus)
	if not reaction.is_empty():
		_apply_reaction(reaction, event, focus)

	if focus and str(event.get("type", "")) == "player_action":
		_pending_focus_event = event.duplicate(true)
		_decision_timer = minf(_decision_timer, 0.18)


func start_work_order(order: Dictionary) -> void:
	var target_tile := _validated_tile(order.get("target_tile", home_tile))
	var extra := {
		"work_order": order.duplicate(true)
	}
	var source := str(order.get("social_preference_source", "")).strip_edges()
	var label := str(order.get("social_preference_label", "")).strip_edges()
	if source != "" and label != "":
		extra["social_preference_source"] = source
		extra["social_preference_label"] = label
		var origin_source := str(order.get("social_preference_origin_source", "")).strip_edges()
		var origin_label := str(order.get("social_preference_origin_label", "")).strip_edges()
		if origin_source == "":
			origin_source = str(order.get("preference_origin_source", "")).strip_edges()
		if origin_label == "":
			origin_label = str(order.get("preference_origin_label", "")).strip_edges()
		if origin_source != "" and origin_label != "" and not (origin_source == source and origin_label == label):
			extra["social_preference_origin_source"] = origin_source
			extra["social_preference_origin_label"] = origin_label
	var forge_run_id := str(order.get("forge_run_id", "")).strip_edges()
	var skill_name := str(order.get("skill_name", "")).strip_edges()
	if skill_name == "":
		skill_name = str(order.get("preference_label", "")).strip_edges()
	if forge_run_id != "" or skill_name != "":
		extra["forge_run_id"] = forge_run_id
		extra["skill_id"] = str(order.get("skill_id", ""))
		extra["skill_name"] = skill_name
		extra["directive_id"] = str(order.get("directive_id", ""))
		extra["directive_kind"] = str(order.get("directive_kind", ""))
		var source_context = order.get("source_context", {})
		if typeof(source_context) == TYPE_DICTIONARY and not source_context.is_empty():
			extra["forge_source_context"] = source_context.duplicate(true)
	var mission_id := str(order.get("mission_id", "")).strip_edges()
	if mission_id != "":
		extra["mission_id"] = mission_id
		extra["mission_label"] = str(order.get("mission_label", "Crew Mission"))
		extra["mission_step_index"] = int(order.get("mission_step_index", -1))
		extra["mission_total_steps"] = int(order.get("mission_total_steps", 0))
		extra["mission_step_label"] = str(order.get("mission_step_label", ""))
	start_directive("build_fence_order", target_tile, "crew work order: %s" % str(order.get("label", "farm task")), extra)


func start_directive(action_name: String, target_tile: Vector2i, reason: String, extra: Dictionary = {}) -> void:
	var decision := {
		"action": action_name,
		"reason": reason,
		"score": 110.0,
		"target_tile": _validated_tile(target_tile),
		"comment": ""
	}
	for key in extra.keys():
		decision[key] = extra[key]
	_start_decision(decision)


func is_available() -> bool:
	return _active_decision.is_empty()


func _choose_next_action() -> void:
	if not _active_decision.is_empty():
		return

	var world := _build_world_snapshot()
	if not _pending_focus_event.is_empty():
		world["focus_event"] = _pending_focus_event
		_pending_focus_event = {}

	var decision := decision_model.decide(state, world, memory)
	_start_decision(decision)
	_decision_timer = randf_range(4.8, 7.6)


func _start_decision(decision: Dictionary) -> void:
	var action := str(decision.get("action", "idle"))
	var reason := str(decision.get("reason", ""))
	var score := float(decision.get("score", 0.0))
	var target_tile := _validated_tile(decision.get("target_tile", home_tile))

	state["current_action"] = action
	_apply_action_state_change(action)
	memory.remember_action(action, reason, score)
	_set_target_grid(target_tile)
	_active_decision = decision.duplicate(true)
	_set_active_social_preference(decision)
	_arrival_action_done = false
	_work_timer = 0.0
	_set_phase("working" if _is_at_target() else "walking")

	if event_log:
		var action_event := {
			"agent_id": agent_id,
			"agent_name": display_name,
			"day": int(grid_manager.day) if grid_manager else 1,
			"action": action,
			"phase": str(state.get("current_phase", "walking")),
			"reason": reason,
			"score": score,
			"target_tile": target_tile,
			"mood": float(state.get("mood", 0.0)),
			"energy": float(state.get("energy", 0.0))
		}
		_add_social_preference_metadata(action_event, decision)
		_add_skill_forge_metadata(action_event, decision)
		_add_daily_intention_metadata(action_event, decision)
		event_log.record_event("agent_action", action_event)

	var comment := str(decision.get("comment", ""))
	if comment != "":
		comment_generated.emit("%s: \"%s\"" % [display_name, comment])
	state_changed.emit(get_snapshot())


func get_snapshot() -> Dictionary:
	return {
		"id": agent_id,
		"name": display_name,
		"trait": personality_trait,
		"mood": float(state.get("mood", 0.0)),
		"energy": float(state.get("energy", 0.0)),
		"irritation": float(state.get("irritation", 0.0)),
		"expression": str(state.get("expression", "neutral")),
		"reaction_intensity": float(state.get("reaction_intensity", 0.0)),
		"helped_today": int(state.get("helped_today", 0)),
		"recent_help_label": str(state.get("recent_help_label", "")),
		"favor_spent_today": int(state.get("favor_spent_today", 0)),
		"recent_spent_favor_label": str(state.get("recent_spent_favor_label", "")),
		"remembered_help_label": str(state.get("remembered_help_label", "")),
		"remembered_help_days": int(state.get("remembered_help_days", 0)),
		"memory_discussed_today": int(state.get("memory_discussed_today", 0)),
		"recent_discussed_memory_label": str(state.get("recent_discussed_memory_label", "")),
		"truce_label": str(state.get("truce_label", "")),
		"truce_days": int(state.get("truce_days", 0)),
		"truce_absorbed_today": int(state.get("truce_absorbed_today", 0)),
		"completed_authored_order_today": int(state.get("completed_authored_order_today", 0)),
		"recent_completed_order_label": str(state.get("recent_completed_order_label", "")),
		"completed_mission_today": int(state.get("completed_mission_today", 0)),
		"recent_completed_mission_label": str(state.get("recent_completed_mission_label", "")),
		"recent_completed_mission_origin_source": str(state.get("recent_completed_mission_origin_source", "")),
		"recent_completed_mission_origin_label": str(state.get("recent_completed_mission_origin_label", "")),
		"ignored_ask_today": int(state.get("ignored_ask_today", 0)),
		"recent_ignored_ask_label": str(state.get("recent_ignored_ask_label", "")),
		"memory_consequence_source": str(state.get("memory_consequence_source", "")),
		"memory_consequence_label": str(state.get("memory_consequence_label", "")),
		"memory_consequence_origin_source": str(state.get("memory_consequence_origin_source", "")),
		"memory_consequence_origin_label": str(state.get("memory_consequence_origin_label", "")),
		"memory_consequence_days": int(state.get("memory_consequence_days", 0)),
		"active_social_preference_source": str(state.get("active_social_preference_source", "")),
		"active_social_preference_label": str(state.get("active_social_preference_label", "")),
		"active_social_preference_origin_source": str(state.get("active_social_preference_origin_source", "")),
		"active_social_preference_origin_label": str(state.get("active_social_preference_origin_label", "")),
		"daily_intention_id": str(state.get("daily_intention_id", "")),
		"daily_intention_label": str(state.get("daily_intention_label", "")),
		"daily_intention_focus": str(state.get("daily_intention_focus", "")),
		"morale_boost": _morale_boost_timer,
		"action": str(state.get("current_action", "idle")),
		"phase": str(state.get("current_phase", "idle")),
		"grid_pos": current_grid_pos,
		"target_grid_pos": target_grid_pos
	}


func _roll_daily_social_credit_into_memory() -> void:
	var next_consequence := _next_memory_consequence()
	var discussed_label := str(state.get("recent_discussed_memory_label", "")).strip_edges()
	if int(state.get("memory_discussed_today", 0)) > 0 and discussed_label != "":
		state["truce_label"] = discussed_label
		state["truce_days"] = 1
		state["truce_absorbed_today"] = 0
	elif int(state.get("truce_days", 0)) > 0:
		var truce_days := int(state.get("truce_days", 0)) - 1
		state["truce_days"] = maxi(0, truce_days)
		state["truce_absorbed_today"] = 0
		if truce_days <= 0:
			state["truce_label"] = ""

	var next_memory := ""
	if int(state.get("helped_today", 0)) > 0:
		next_memory = str(state.get("recent_help_label", ""))
	elif int(state.get("favor_spent_today", 0)) > 0:
		next_memory = str(state.get("recent_spent_favor_label", ""))

	if next_memory != "":
		state["remembered_help_label"] = next_memory
		state["remembered_help_days"] = 1
	else:
		var remembered_days := int(state.get("remembered_help_days", 0))
		if remembered_days <= 0:
			state["remembered_help_label"] = ""
		else:
			remembered_days -= 1
			state["remembered_help_days"] = remembered_days
			if remembered_days <= 0:
				state["remembered_help_label"] = ""

	_apply_memory_consequence(next_consequence)


func _next_memory_consequence() -> Dictionary:
	var truce_label := str(state.get("truce_label", "")).strip_edges()
	if int(state.get("truce_absorbed_today", 0)) > 0 and truce_label != "":
		return {
			"source": "held_truce",
			"label": truce_label
		}

	var ignored_label := str(state.get("recent_ignored_ask_label", "")).strip_edges()
	if int(state.get("ignored_ask_today", 0)) > 0 and ignored_label != "":
		return {
			"source": "ignored_ask",
			"label": ignored_label
		}

	var completed_label := str(state.get("recent_completed_order_label", "")).strip_edges()
	if int(state.get("completed_authored_order_today", 0)) > 0 and completed_label != "":
		return {
			"source": "completed_order",
			"label": completed_label
		}

	var completed_mission_label := str(state.get("recent_completed_mission_label", "")).strip_edges()
	if int(state.get("completed_mission_today", 0)) > 0 and completed_mission_label != "":
		return {
			"source": "completed_mission",
			"label": completed_mission_label,
			"origin_source": str(state.get("recent_completed_mission_origin_source", "")).strip_edges(),
			"origin_label": str(state.get("recent_completed_mission_origin_label", "")).strip_edges()
		}

	var remembered_label := str(state.get("remembered_help_label", "")).strip_edges()
	var recent_help_label := str(state.get("recent_help_label", "")).strip_edges()
	if int(state.get("helped_today", 0)) > 0 and remembered_label != "":
		return {
			"source": "repeated_help",
			"label": recent_help_label if recent_help_label != "" else remembered_label
		}
	return {}


func _apply_memory_consequence(consequence: Dictionary) -> void:
	if not consequence.is_empty():
		state["memory_consequence_source"] = str(consequence.get("source", ""))
		state["memory_consequence_label"] = str(consequence.get("label", ""))
		state["memory_consequence_origin_source"] = str(consequence.get("origin_source", ""))
		state["memory_consequence_origin_label"] = str(consequence.get("origin_label", ""))
		state["memory_consequence_days"] = 1
		return

	var consequence_days := int(state.get("memory_consequence_days", 0))
	if consequence_days <= 0:
		state["memory_consequence_source"] = ""
		state["memory_consequence_label"] = ""
		state["memory_consequence_origin_source"] = ""
		state["memory_consequence_origin_label"] = ""
		return

	consequence_days -= 1
	state["memory_consequence_days"] = consequence_days
	if consequence_days <= 0:
		state["memory_consequence_source"] = ""
		state["memory_consequence_label"] = ""
		state["memory_consequence_origin_source"] = ""
		state["memory_consequence_origin_label"] = ""


func apply_adversarial_result(result: Dictionary) -> void:
	state["mood"] = clampf(float(state.get("mood", 50.0)) + float(result.get("agent_mood_delta", 0.0)), 0.0, 100.0)
	state["irritation"] = clampf(float(state.get("irritation", 0.0)) + float(result.get("agent_irritation_delta", 0.0)), 0.0, 100.0)
	match str(result.get("outcome", "")):
		"resolved":
			state["expression"] = "pleased"
		"lost_patience":
			state["expression"] = "angry"
		"uneasy_truce":
			state["expression"] = "side_eye"
		"walked_away":
			state["expression"] = "annoyed"
		_:
			state["expression"] = "neutral"
	state["reaction_intensity"] = maxf(float(state.get("reaction_intensity", 0.0)), 0.82)
	if bool(result.get("social_credit_used", false)):
		var spent_label := _spent_favor_label(str(result.get("social_credit_label", "")))
		if spent_label == "":
			spent_label = str(state.get("recent_help_label", ""))
		state["favor_spent_today"] = int(state.get("favor_spent_today", 0)) + 1
		state["recent_spent_favor_label"] = spent_label
		state["helped_today"] = 0
		state["recent_help_label"] = ""
	var remembered_label := str(result.get("remembered_help_label", "")).strip_edges()
	if remembered_label != "":
		state["memory_discussed_today"] = int(state.get("memory_discussed_today", 0)) + 1
		state["recent_discussed_memory_label"] = remembered_label
		if str(state.get("remembered_help_label", "")) == remembered_label:
			state["remembered_help_label"] = ""
			state["remembered_help_days"] = 0
	_update_expression_visuals()
	state_changed.emit(get_snapshot())


func try_absorb_order_escalation_with_truce(order_label: String) -> Dictionary:
	var truce_label := str(state.get("truce_label", "")).strip_edges()
	if truce_label == "" or int(state.get("truce_days", 0)) <= 0:
		return {}
	if int(state.get("truce_absorbed_today", 0)) > 0:
		return {}

	state["truce_absorbed_today"] = int(state.get("truce_absorbed_today", 0)) + 1
	state["mood"] = clampf(float(state.get("mood", 50.0)) + 0.6, 0.0, 100.0)
	state["irritation"] = clampf(float(state.get("irritation", 0.0)) - 2.0, 0.0, 100.0)
	state["expression"] = "side_eye"
	state["reaction_intensity"] = maxf(float(state.get("reaction_intensity", 0.0)), 0.48)
	_update_expression_visuals()
	state_changed.emit(get_snapshot())
	return {
		"agent_id": agent_id,
		"agent_name": display_name,
		"truce_label": truce_label,
		"order_label": order_label
	}


func _spent_favor_label(social_credit_label: String) -> String:
	var help_label := social_credit_label.replace("Helped today: ", "")
	if help_label == "" or help_label == "Helped today":
		return ""
	return help_label


func acknowledge_supply_delivery(item_label: String, payoff_label: String = "") -> void:
	state["mood"] = clampf(float(state.get("mood", 50.0)) + 1.6, 0.0, 100.0)
	state["irritation"] = clampf(float(state.get("irritation", 0.0)) - 4.0, 0.0, 100.0)
	state["expression"] = "pleased"
	state["reaction_intensity"] = maxf(float(state.get("reaction_intensity", 0.0)), 0.72)
	state["helped_today"] = int(state.get("helped_today", 0)) + 1
	state["recent_help_label"] = item_label
	_update_expression_visuals()
	var line := _supply_acknowledgement_line(item_label, payoff_label)
	if line != "":
		comment_generated.emit("%s: \"%s\"" % [display_name, line])
	state_changed.emit(get_snapshot())


func acknowledge_completed_authored_order(order_label: String) -> void:
	state["completed_authored_order_today"] = int(state.get("completed_authored_order_today", 0)) + 1
	state["recent_completed_order_label"] = order_label
	state["mood"] = clampf(float(state.get("mood", 50.0)) + 0.8, 0.0, 100.0)
	state["irritation"] = clampf(float(state.get("irritation", 0.0)) - 1.4, 0.0, 100.0)
	state_changed.emit(get_snapshot())


func acknowledge_completed_mission(mission_label: String, origin_source: String = "", origin_label: String = "") -> void:
	state["completed_mission_today"] = int(state.get("completed_mission_today", 0)) + 1
	state["recent_completed_mission_label"] = mission_label
	state["recent_completed_mission_origin_source"] = origin_source.strip_edges()
	state["recent_completed_mission_origin_label"] = origin_label.strip_edges()
	state["mood"] = clampf(float(state.get("mood", 50.0)) + 1.0, 0.0, 100.0)
	state["irritation"] = clampf(float(state.get("irritation", 0.0)) - 1.0, 0.0, 100.0)
	state_changed.emit(get_snapshot())


func remember_ignored_ask(order_label: String) -> void:
	state["ignored_ask_today"] = int(state.get("ignored_ask_today", 0)) + 1
	state["recent_ignored_ask_label"] = order_label
	state_changed.emit(get_snapshot())


func apply_crew_boost(seconds: float, multiplier: float = 1.28) -> void:
	_morale_boost_timer = maxf(_morale_boost_timer, seconds)
	_morale_speed_multiplier = maxf(_morale_speed_multiplier, multiplier)
	state_changed.emit(get_snapshot())


func _apply_action_state_change(action: String) -> void:
	var energy := float(state.get("energy", 70.0))
	var mood := float(state.get("mood", 50.0))

	match action:
		"rest":
			energy += 13.0
		"approve":
			energy -= 1.0
			mood += 1.4
		"side_eye":
			energy -= 1.0
			mood -= 0.9
		_:
			energy -= 2.2

	state["energy"] = clampf(energy, 0.0, 100.0)
	state["mood"] = clampf(mood, 0.0, 100.0)


func _apply_reaction(reaction: Dictionary, event: Dictionary, focus: bool) -> void:
	state["mood"] = clampf(float(state.get("mood", 50.0)) + float(reaction.get("mood_delta", 0.0)), 0.0, 100.0)
	state["irritation"] = clampf(float(state.get("irritation", 0.0)) + float(reaction.get("irritation_delta", 0.0)), 0.0, 100.0)
	state["expression"] = str(reaction.get("expression", "neutral"))
	state["reaction_intensity"] = maxf(float(state.get("reaction_intensity", 0.0)), float(reaction.get("intensity", 0.0)))
	_update_expression_visuals()

	if focus:
		var line := dialogue_library.line_for(state, reaction, event)
		if line != "":
			comment_generated.emit("%s: \"%s\"" % [display_name, line])
	state_changed.emit(get_snapshot())


func _build_world_snapshot() -> Dictionary:
	var ready_tiles: Array[Vector2i] = []
	var growing_tiles: Array[Vector2i] = []
	var soil_tiles: Array[Vector2i] = []
	var brush_tiles: Array[Vector2i] = []
	var structure_tiles: Array[Vector2i] = []

	if grid_manager:
		for tile in grid_manager.tiles.values():
			if tile.crop:
				if tile.crop.is_ready():
					ready_tiles.append(tile.grid_pos)
				else:
					growing_tiles.append(tile.grid_pos)
			elif tile.is_tilled:
				soil_tiles.append(tile.grid_pos)

			if str(tile.decor_id) in ["tall_grass", "flower_patch"]:
				brush_tiles.append(tile.grid_pos)
			if str(tile.structure_id) != "" or str(tile.decor_id) in ["rock", "fence", "tree", "wooden_sign"]:
				structure_tiles.append(tile.grid_pos)

	return {
		"home_tile": home_tile,
		"ready_crops": ready_tiles.size(),
		"growing_crops": growing_tiles.size(),
		"empty_soil": soil_tiles.size(),
		"brush_tiles": brush_tiles.size(),
		"structures": structure_tiles.size(),
		"ready_tile": _nearest_tile(ready_tiles),
		"growing_tile": _nearest_tile(growing_tiles),
		"soil_tile": _nearest_tile(soil_tiles),
		"brush_tile": _nearest_tile(brush_tiles),
		"structure_tile": _nearest_tile(structure_tiles),
		"wander_tile": _wander_tile()
	}


func _nearest_tile(candidates: Array[Vector2i]) -> Vector2i:
	if candidates.is_empty():
		return home_tile

	var best := candidates[0]
	var best_distance := current_grid_pos.distance_squared_to(best)
	for candidate in candidates:
		var distance := current_grid_pos.distance_squared_to(candidate)
		if distance < best_distance:
			best = candidate
			best_distance = distance
	return best


func _wander_tile() -> Vector2i:
	if grid_manager == null:
		return home_tile

	var x := clampi(home_tile.x + randi_range(-2, 2), 0, grid_manager.width - 1)
	var z := clampi(home_tile.y + randi_range(-2, 2), 0, grid_manager.height - 1)
	return Vector2i(x, z)


func _validated_tile(value) -> Vector2i:
	if typeof(value) != TYPE_VECTOR2I:
		return home_tile
	if grid_manager == null or grid_manager.get_tile(value) == null:
		return home_tile
	return value


func _set_target_grid(tile_pos: Vector2i) -> void:
	target_grid_pos = tile_pos
	_target_position = _world_for(tile_pos)


func _reset_position() -> void:
	position = _world_for(home_tile)
	current_grid_pos = home_tile
	target_grid_pos = home_tile
	_target_position = position


func _world_for(tile_pos: Vector2i) -> Vector3:
	if grid_manager == null:
		return Vector3.ZERO
	var world: Vector3 = grid_manager.grid_to_world(tile_pos)
	world.y = 0.20
	return world


func _update_movement(delta: float) -> void:
	var before: Vector3 = position
	position = position.move_toward(_target_position, move_speed * _current_speed_multiplier() * delta)
	if _is_at_target():
		current_grid_pos = target_grid_pos
	var movement: Vector3 = position - before
	if movement.length_squared() > 0.0001:
		rotation.y = atan2(movement.x, movement.z)


func _update_active_decision(delta: float) -> void:
	if _work_timer > 0.0:
		_work_timer -= delta * _current_speed_multiplier()
		if _work_timer <= 0.0:
			_complete_active_decision()
		return

	if not _is_at_target():
		_set_phase("walking")
		return

	current_grid_pos = target_grid_pos
	if not _arrival_action_done:
		_arrival_action_done = true
		_set_phase("working")
		_execute_arrival_action(_active_decision)
		_work_timer = WORK_SECONDS


func _execute_arrival_action(decision: Dictionary) -> void:
	var action := str(decision.get("action", "idle"))
	var tile_pos: Vector2i = _validated_tile(decision.get("target_tile", target_grid_pos))

	match action:
		"harvest_crop":
			_harvest_crop_at(tile_pos, str(decision.get("work_order_id", "")))
		"clear_brush":
			_clear_brush_at(tile_pos, str(decision.get("work_order_id", "")))
		"plant_seed":
			_plant_seed_at(tile_pos, str(decision.get("work_order_id", "")))
		"inspect_structure":
			_inspect_structure_at(tile_pos)
		"inspect_ready_crop":
			_inspect_crop_at(tile_pos)
		"inspect_soil":
			_inspect_soil_at(tile_pos)
		"build_fence_order":
			_build_fence_order_at(tile_pos, decision.get("work_order", {}))
		_:
			pass


func _complete_active_decision() -> void:
	_active_decision = {}
	_arrival_action_done = false
	_work_timer = 0.0
	state["current_action"] = "idle"
	_clear_active_social_preference()
	_set_phase("idle")
	state_changed.emit(get_snapshot())


func _is_at_target() -> bool:
	return position.distance_to(_target_position) <= ARRIVAL_DISTANCE


func _update_morale_boost(delta: float) -> void:
	if _morale_boost_timer <= 0.0:
		return

	_morale_boost_timer = maxf(0.0, _morale_boost_timer - delta)
	if _morale_boost_timer <= 0.0:
		_morale_speed_multiplier = 1.0
		state_changed.emit(get_snapshot())


func _current_speed_multiplier() -> float:
	return _morale_speed_multiplier if _morale_boost_timer > 0.0 else 1.0


func _set_phase(new_phase: String) -> void:
	var previous := str(state.get("current_phase", "idle"))
	state["current_phase"] = new_phase
	if previous != new_phase:
		state_changed.emit(get_snapshot())


func _harvest_crop_at(tile_pos: Vector2i, work_order_id: String = "") -> void:
	var tile = grid_manager.get_tile(tile_pos) if grid_manager else null
	var crop_name := "crop"
	if tile and tile.crop:
		crop_name = str(tile.crop.crop_id)

	var value := 0
	var success: bool = tile != null and tile.crop != null and tile.crop.is_ready()
	if success:
		value = tile.harvest()
		success = value > 0

	var resource_gain := {"grain": 1} if success else {}
	var message := "%s harvested %s for %s coins." % [display_name, crop_name, value] if success else "%s reached for a crop, but it was not ready." % display_name
	_emit_world_action("harvest_crop", tile_pos, success, message, value, crop_name, ["harvest_chime", "coin_burst", "plant_pop"] if success else [], resource_gain, {}, work_order_id)


func _clear_brush_at(tile_pos: Vector2i, work_order_id: String = "") -> void:
	var tile = grid_manager.get_tile(tile_pos) if grid_manager else null
	var brush_name := "brush"
	if tile:
		brush_name = str(tile.decor_id).replace("_", " ")

	var success: bool = tile != null and str(tile.decor_id) in ["tall_grass", "flower_patch"]
	if success:
		tile.cut_with_sickle()

	var resource_gain := {"fiber": 2} if success else {}
	var message := "%s cleared %s." % [display_name, brush_name] if success else "%s found nothing useful to cut." % display_name
	_emit_world_action("clear_brush", tile_pos, success, message, 0, brush_name, ["plant_pop"] if success else [], resource_gain, {}, work_order_id)


func _plant_seed_at(tile_pos: Vector2i, work_order_id: String = "") -> void:
	var tile = grid_manager.get_tile(tile_pos) if grid_manager else null
	var subject := "wheat"
	var success: bool = tile != null and tile.crop == null and str(tile.decor_id) == "" and str(tile.structure_id) == "" and str(tile.terrain) != "dirt_path"
	if success and not tile.is_tilled:
		success = tile.till()
	if success:
		success = tile.plant_wheat()

	var message := "%s planted %s." % [display_name, subject] if success else "%s found no open planting tile." % display_name
	_emit_world_action("plant_seed", tile_pos, success, message, 0, subject, ["place_soft", "plant_pop"] if success else [], {}, {}, work_order_id)


func _inspect_structure_at(tile_pos: Vector2i) -> void:
	var tile = grid_manager.get_tile(tile_pos) if grid_manager else null
	var subject := _tile_subject(tile)
	var success: bool = tile != null and subject != "empty tile"
	var message := "%s inspected %s." % [display_name, subject] if success else "%s inspected an empty tile." % display_name
	_emit_world_action("inspect_structure", tile_pos, success, message, 0, subject, ["ui_click"] if success else [])


func _inspect_crop_at(tile_pos: Vector2i) -> void:
	var tile = grid_manager.get_tile(tile_pos) if grid_manager else null
	var subject := _tile_subject(tile)
	var success: bool = tile != null and tile.crop != null
	var message := "%s checked %s." % [display_name, subject] if success else "%s found no crop to check." % display_name
	_emit_world_action("inspect_ready_crop", tile_pos, success, message, 0, subject, [])


func _inspect_soil_at(tile_pos: Vector2i) -> void:
	var tile = grid_manager.get_tile(tile_pos) if grid_manager else null
	var success: bool = tile != null and tile.is_tilled and tile.crop == null
	var message := "%s checked open soil." % display_name if success else "%s found no open soil there." % display_name
	_emit_world_action("inspect_soil", tile_pos, success, message, 0, "soil", [])


func _build_fence_order_at(tile_pos: Vector2i, order: Dictionary) -> void:
	var tile = grid_manager.get_tile(tile_pos) if grid_manager else null
	var success: bool = tile != null and tile.can_apply_item("fence")
	if success:
		success = tile.place_item("fence")

	var label := str(order.get("label", "Fence order"))
	var message := "%s built a fence for %s." % [display_name, label] if success else "%s could not build the fence order." % display_name
	_emit_world_action(
		"build_fence_order",
		tile_pos,
		success,
		message,
		0,
		"fence",
		["place_soft", "plant_pop"] if success else [],
		{},
		{"fence_kit": 1} if success else {},
		str(order.get("id", "road_fence"))
	)


func _emit_world_action(action_name: String, tile_pos: Vector2i, success: bool, message: String, value: int = 0, subject: String = "", stamps: Array = [], resources: Dictionary = {}, crafted_cost: Dictionary = {}, work_order_id: String = "") -> void:
	var world_action := {
		"actor": "agent",
		"agent_id": agent_id,
		"agent_name": display_name,
		"trait": personality_trait,
		"action": action_name,
		"reason": str(_active_decision.get("reason", "")),
		"grid_pos": tile_pos,
		"success": success,
		"message": message,
		"value": value,
		"subject": subject,
		"stamps": stamps,
		"resources": resources,
		"crafted_cost": crafted_cost,
		"work_order_id": work_order_id
	}
	_add_social_preference_metadata(world_action, _active_decision)
	_add_skill_forge_metadata(world_action, _active_decision)
	_add_daily_intention_metadata(world_action, _active_decision)
	_add_mission_metadata(world_action, _active_decision)
	world_action_performed.emit(world_action)

	if success:
		var comment := _work_comment(action_name, value, subject)
		if comment != "":
			comment_generated.emit("%s: \"%s\"" % [display_name, comment])


func _add_social_preference_metadata(payload: Dictionary, decision: Dictionary) -> void:
	var source := str(decision.get("social_preference_source", "")).strip_edges()
	var label := str(decision.get("social_preference_label", "")).strip_edges()
	if source == "" or label == "":
		return
	payload["social_preference_source"] = source
	payload["social_preference_label"] = label
	var origin_source := str(decision.get("social_preference_origin_source", "")).strip_edges()
	var origin_label := str(decision.get("social_preference_origin_label", "")).strip_edges()
	if origin_source != "" and origin_label != "" and not (origin_source == source and origin_label == label):
		payload["social_preference_origin_source"] = origin_source
		payload["social_preference_origin_label"] = origin_label


func _add_skill_forge_metadata(payload: Dictionary, decision: Dictionary) -> void:
	var run_id := str(decision.get("forge_run_id", "")).strip_edges()
	var skill_name := str(decision.get("skill_name", "")).strip_edges()
	if run_id == "" and skill_name == "":
		return
	payload["forge_run_id"] = run_id
	payload["skill_id"] = str(decision.get("skill_id", ""))
	payload["skill_name"] = skill_name
	payload["directive_id"] = str(decision.get("directive_id", ""))
	payload["directive_kind"] = str(decision.get("directive_kind", ""))
	var source_context = decision.get("forge_source_context", {})
	if typeof(source_context) == TYPE_DICTIONARY and not source_context.is_empty():
		payload["forge_source_context"] = source_context.duplicate(true)


func _add_daily_intention_metadata(payload: Dictionary, decision: Dictionary) -> void:
	var intention_id := str(decision.get("daily_intention_id", "")).strip_edges()
	var intention_label := str(decision.get("daily_intention_label", "")).strip_edges()
	if intention_id == "" or intention_label == "":
		return
	payload["daily_intention_id"] = intention_id
	payload["daily_intention_label"] = intention_label


func _add_mission_metadata(payload: Dictionary, decision: Dictionary) -> void:
	var mission_id := str(decision.get("mission_id", "")).strip_edges()
	if mission_id == "":
		return
	payload["mission_id"] = mission_id
	payload["mission_label"] = str(decision.get("mission_label", "Crew Mission"))
	payload["mission_step_index"] = int(decision.get("mission_step_index", -1))
	payload["mission_total_steps"] = int(decision.get("mission_total_steps", 0))
	payload["mission_step_label"] = str(decision.get("mission_step_label", ""))


func _refresh_daily_intention() -> void:
	var daily_intention := _daily_intention_for_memory_consequence()
	if daily_intention.is_empty():
		daily_intention = _daily_intention_for_trait(personality_trait)
	state["daily_intention_id"] = str(daily_intention.get("id", ""))
	state["daily_intention_label"] = str(daily_intention.get("label", ""))
	state["daily_intention_focus"] = str(daily_intention.get("focus", ""))


func _daily_intention_for_memory_consequence() -> Dictionary:
	if int(state.get("memory_consequence_days", 0)) <= 0:
		return {}

	var label := str(state.get("memory_consequence_label", "")).strip_edges()
	match str(state.get("memory_consequence_source", "")):
		"repeated_help":
			return {
				"id": "repeat_goodwill",
				"label": "Repeat Goodwill",
				"focus": _focus_for_consequence_label(label, "grow")
			}
		"completed_order":
			return {
				"id": "follow_through",
				"label": "Follow Through",
				"focus": _focus_for_consequence_label(label, "clear")
			}
		"completed_mission":
			return {
				"id": "mission_momentum",
				"label": "Mission Momentum",
				"focus": _focus_for_consequence_label(label, "grow")
			}
		"ignored_ask":
			return {
				"id": "press_the_ask",
				"label": "Press the Ask",
				"focus": _focus_for_consequence_label(label, "clear")
			}
		"held_truce":
			return {
				"id": "keep_the_truce",
				"label": "Keep the Truce",
				"focus": _focus_for_consequence_label(label, "boundary")
			}
	return {}


func _focus_for_consequence_label(label: String, fallback: String) -> String:
	var lowered := label.to_lower()
	if lowered.contains("seed") or lowered.contains("crop") or lowered.contains("harvest") or lowered.contains("growth"):
		return "grow"
	if lowered.contains("fence") or lowered.contains("boundary"):
		return "boundary"
	if lowered.contains("brush") or lowered.contains("clear") or lowered.contains("rush"):
		return "clear"
	return fallback


func _daily_intention_for_trait(trait_name: String) -> Dictionary:
	match trait_name:
		"grizzled":
			return {
				"id": "shore_boundaries",
				"label": "Shore Boundaries",
				"focus": "boundary"
			}
		"hopeful":
			return {
				"id": "tend_growth",
				"label": "Tend Growth",
				"focus": "grow"
			}
		"chaotic":
			return {
				"id": "clear_paths",
				"label": "Clear the Way",
				"focus": "clear"
			}
	return {
		"id": "keep_watch",
		"label": "Keep Watch",
		"focus": "clear"
	}


func _set_active_social_preference(decision: Dictionary) -> void:
	state["active_social_preference_source"] = str(decision.get("social_preference_source", "")).strip_edges()
	state["active_social_preference_label"] = str(decision.get("social_preference_label", "")).strip_edges()
	state["active_social_preference_origin_source"] = str(decision.get("social_preference_origin_source", "")).strip_edges()
	state["active_social_preference_origin_label"] = str(decision.get("social_preference_origin_label", "")).strip_edges()


func _clear_active_social_preference() -> void:
	state["active_social_preference_source"] = ""
	state["active_social_preference_label"] = ""
	state["active_social_preference_origin_source"] = ""
	state["active_social_preference_origin_label"] = ""


func _tile_subject(tile) -> String:
	if tile == null:
		return "empty tile"
	if tile.crop:
		return "%s crop" % str(tile.crop.crop_id)
	if str(tile.structure_id) != "":
		return str(tile.structure_id).replace("_", " ")
	if str(tile.decor_id) != "":
		return str(tile.decor_id).replace("_", " ")
	if tile.is_tilled:
		return "open soil"
	return "%s tile" % str(tile.terrain).replace("_", " ")


func _work_comment(action_name: String, value: int, subject: String) -> String:
	match action_name:
		"harvest_crop":
			match personality_trait:
				"grizzled":
					return "%s coins in. Try not to spend it all on decorative rocks." % value
				"hopeful":
					return "%s coins harvested. That is a real little win." % value
				"chaotic":
					return "%s coins liberated from the vegetables." % value
		"clear_brush":
			match personality_trait:
				"grizzled":
					return "Cleared the %s. The farm looks one sigh better." % subject
				"hopeful":
					return "Cleared the %s. We made room for something nicer." % subject
				"chaotic":
					return "The %s has been dramatically removed." % subject
		"plant_seed":
			match personality_trait:
				"grizzled":
					return "%s planted. We have made a future chore." % subject.capitalize()
				"hopeful":
					return "%s planted. Tiny start, good direction." % subject.capitalize()
				"chaotic":
					return "%s entered the ground with ceremony." % subject.capitalize()
		"inspect_structure":
			match personality_trait:
				"grizzled":
					return "%s is still standing. I will allow it." % subject.capitalize()
				"hopeful":
					return "%s looks useful. We should build around it." % subject.capitalize()
				"chaotic":
					return "%s passed the vibe inspection." % subject.capitalize()
		"build_fence_order":
			match personality_trait:
				"grizzled":
					return "Fence kit became fence. Paperwork trembles."
				"hopeful":
					return "Fence is up. That is a proper little boundary."
				"chaotic":
					return "Fence deployed. The map has opinions now."
	return ""


func _supply_acknowledgement_line(item_label: String, payoff_label: String) -> String:
	var suffix := " %s ready." % payoff_label if payoff_label != "" else ""
	match personality_trait:
		"grizzled":
			return "%s received. Practical. Appreciated.%s" % [item_label, suffix]
		"hopeful":
			return "%s received. I can work with this.%s" % [item_label, suffix]
		"chaotic":
			return "%s received. Fine, that is useful.%s" % [item_label, suffix]
	return "%s received.%s" % [item_label, suffix]


func _update_visual_motion(delta: float) -> void:
	if _visual_root == null:
		return

	_walk_phase += delta * (7.0 if position.distance_to(_target_position) > 0.02 else 2.0)
	var bob: float = abs(sin(_walk_phase)) * (0.035 if position.distance_to(_target_position) > 0.02 else 0.012)
	var intensity := float(state.get("reaction_intensity", 0.0))
	var shake := 0.0
	if intensity > 0.05 and str(state.get("expression", "neutral")) in ["side_eye", "annoyed", "angry"]:
		_reaction_shake_phase += delta * 42.0
		shake = sin(_reaction_shake_phase) * 0.03 * intensity
		state["reaction_intensity"] = maxf(0.0, intensity - delta * 0.42)
	_face_camera_if_judging()
	_refresh_reason_badge()
	_update_reason_badge_pop(delta)
	_visual_root.position = Vector3(shake, bob, 0.0)


func _build_visual() -> void:
	_visual_root = Node3D.new()
	_visual_root.name = "VoxelRig"
	add_child(_visual_root)

	_visual_root.add_child(VoxelFactory.cube("Body", Vector3(0.24, 0.34, 0.18), _body_color, Vector3(0.0, 0.34, 0.0)))
	_head = VoxelFactory.cube("Head", Vector3(0.20, 0.20, 0.20), _skin_color, Vector3(0.0, 0.64, 0.0))
	_visual_root.add_child(_head)
	_visual_root.add_child(VoxelFactory.cube("HairHat", Vector3(0.23, 0.08, 0.23), _accent_color, Vector3(0.0, 0.78, 0.0)))
	_visual_root.add_child(VoxelFactory.cube("LegA", Vector3(0.08, 0.22, 0.08), Color("#4f4138"), Vector3(-0.06, 0.13, 0.0)))
	_visual_root.add_child(VoxelFactory.cube("LegB", Vector3(0.08, 0.22, 0.08), Color("#4f4138"), Vector3(0.06, 0.13, 0.0)))
	_visual_root.add_child(VoxelFactory.cube("ArmA", Vector3(0.07, 0.25, 0.07), _skin_color, Vector3(-0.18, 0.36, 0.0)))
	_visual_root.add_child(VoxelFactory.cube("ArmB", Vector3(0.07, 0.25, 0.07), _skin_color, Vector3(0.18, 0.36, 0.0)))
	_mood_pip = VoxelFactory.cube("MoodPip", Vector3(0.10, 0.10, 0.10), _accent_color, Vector3(0.0, 0.98, 0.0))
	_visual_root.add_child(_mood_pip)

	_face_label = Label3D.new()
	_face_label.name = "FaceLabel"
	_face_label.text = "o_o"
	_face_label.font_size = 36
	_face_label.pixel_size = 0.006
	_face_label.position = Vector3(0.0, 0.65, 0.105)
	_face_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_face_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_face_label.modulate = Color("#2f241f")
	_face_label.outline_size = 3
	_face_label.outline_modulate = Color("#ffe2bd")
	_face_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_face_label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_visual_root.add_child(_face_label)

	_reason_badge_plate = VoxelFactory.cube("ReasonBadgePlate", Vector3(0.48, 0.14, 0.035), Color("#fff8df"), Vector3(0.0, 1.14, -0.018))
	_visual_root.add_child(_reason_badge_plate)

	_reason_badge = Label3D.new()
	_reason_badge.name = "ReasonBadge"
	_reason_badge.text = "Plan"
	_reason_badge.font_size = 16
	_reason_badge.pixel_size = 0.008
	_reason_badge.position = Vector3(0.0, 1.14, 0.0)
	_reason_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reason_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_reason_badge.modulate = Color("#5f7fb5")
	_reason_badge.outline_size = 4
	_reason_badge.outline_modulate = Color("#fff8df")
	_reason_badge.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_reason_badge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_visual_root.add_child(_reason_badge)
	_update_expression_visuals()


func _update_expression_visuals() -> void:
	var expression := str(state.get("expression", "neutral"))
	var irritation := float(state.get("irritation", 0.0))
	var heat := clampf(irritation / 80.0, 0.0, 1.0)

	if _face_label:
		_face_label.text = _face_text(expression)
	if _head:
		_head.material_override = VoxelFactory.material(_skin_color.lerp(Color("#ff8a68"), heat * 0.68))
	if _mood_pip:
		_mood_pip.material_override = VoxelFactory.material(_accent_color.lerp(Color("#ff5348"), heat))
	_refresh_reason_badge()


func _refresh_reason_badge() -> void:
	if _reason_badge == null:
		return

	var badge := _reason_badge_context()
	_reason_badge.visible = not badge.is_empty()
	if _reason_badge_plate:
		_reason_badge_plate.visible = not badge.is_empty()
	if badge.is_empty():
		return

	var next_text := str(badge.get("text", "Plan"))
	if next_text != _reason_badge_last_text:
		_reason_badge_pulse = 1.0
		_reason_badge_last_text = next_text
	_reason_badge.text = next_text
	var color: Color = badge.get("color", Color("#5f7fb5"))
	_reason_badge.modulate = color
	if _reason_badge_plate:
		_reason_badge_plate.material_override = VoxelFactory.material(color.lightened(0.48))


func _update_reason_badge_pop(delta: float) -> void:
	if _reason_badge == null:
		return

	if _reason_badge_pulse <= 0.0:
		_reason_badge.scale = Vector3.ONE
		if _reason_badge_plate:
			_reason_badge_plate.scale = Vector3.ONE
		return

	var pop := 1.0 + 0.14 * _reason_badge_pulse
	_reason_badge.scale = Vector3.ONE * pop
	if _reason_badge_plate:
		_reason_badge_plate.scale = Vector3(pop, pop, 1.0)
	_reason_badge_pulse = maxf(0.0, _reason_badge_pulse - delta * 4.0)


func _reason_badge_context() -> Dictionary:
	var mission_label := str(_active_decision.get("mission_label", "")).strip_edges()
	if mission_label != "":
		return {
			"text": "Mission",
			"color": Color("#d9a83c")
		}

	var forge_skill := str(_active_decision.get("skill_name", "")).strip_edges()
	if forge_skill != "" or str(_active_decision.get("forge_run_id", "")).strip_edges() != "":
		return {
			"text": "Forge",
			"color": Color("#4f6f8f")
		}

	var source := str(_active_decision.get("social_preference_source", state.get("active_social_preference_source", ""))).strip_edges()
	if source != "":
		return {
			"text": _reason_badge_text_for_social_source(source),
			"color": _reason_badge_color_for_social_source(source)
		}

	var intention_id := str(state.get("daily_intention_id", "")).strip_edges()
	var intention_label := str(state.get("daily_intention_label", "")).strip_edges()
	if intention_label != "":
		if intention_id == "mission_momentum":
			return {
				"text": "Momentum",
				"color": Color("#c58e41")
			}
		return {
			"text": "Plan",
			"color": Color("#5f7fb5")
		}
	return {}


func _reason_badge_text_for_social_source(source: String) -> String:
	match source:
		"truce":
			return "Truce"
		"repeated_help":
			return "Streak"
		"completed_order":
			return "Follow"
		"completed_mission":
			return "Momentum"
		"ignored_ask":
			return "Pressure"
		"held_truce":
			return "Held"
	return "Memory"


func _reason_badge_color_for_social_source(source: String) -> Color:
	match source:
		"truce", "held_truce":
			return Color("#8d75c5")
		"ignored_ask":
			return Color("#c86f74")
		"completed_mission":
			return Color("#c58e41")
		"completed_order":
			return Color("#4f9e8f")
		"repeated_help":
			return Color("#79a95c")
	return Color("#6f9f5d")


func _face_text(expression: String) -> String:
	match expression:
		"pleased":
			return "^_^"
		"side_eye":
			return "-_-"
		"annoyed":
			return ">_>"
		"angry":
			return "-_-!"
	return "o_o"


func _face_camera_if_judging() -> void:
	if str(state.get("expression", "neutral")) not in ["annoyed", "angry"]:
		return
	if position.distance_to(_target_position) > 0.03:
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var direction: Vector3 = camera.global_position - global_position
	direction.y = 0.0
	if direction.length_squared() > 0.001:
		rotation.y = atan2(direction.x, direction.z)
