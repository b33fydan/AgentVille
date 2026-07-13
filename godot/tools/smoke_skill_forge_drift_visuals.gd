extends SceneTree

const SkillForgeRunHarnessScript := preload("res://scripts/systems/SkillForgeRunHarness.gd")
const SkillForgeTemplateLibraryScript := preload("res://scripts/systems/SkillForgeTemplateLibrary.gd")

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var agent_manager = scene.get_node("FarmWorld/AgentManager")
	for actor in agent_manager.agents:
		actor.set_process(false)
		actor.call("_complete_active_decision")
		actor.state["expression"] = "neutral"
		actor.call("_update_expression_visuals")

	_test_wobbly_directive_visuals(scene)
	if _failed:
		return
	_test_game_work_order_drift_bridge(scene)
	if _failed:
		return
	_test_blocked_hallucination_reaction(scene)
	if _failed:
		return

	scene.queue_free()
	await process_frame
	quit()


func _test_wobbly_directive_visuals(scene: Node) -> void:
	var harness = SkillForgeRunHarnessScript.new()
	var library = SkillForgeTemplateLibraryScript.new()
	var spec: Dictionary = library.get_template_spec("clear_patch_starter")
	var tools: Array = spec.get("tools", []).duplicate()
	tools.append("inspect_tile")
	spec["tools"] = tools
	var start: Dictionary = harness.start_manual_run(spec, {
		"agent_id": "chuck",
		"agent_name": "Chuck",
		"target_tile": Vector2i(0, 1),
		"day": 3,
		"source_context": {
			"source": "completed_mission",
			"label": "Drift Visual QA"
		}
	})
	if str(start.get("status", "")) != "started":
		_fail("Warning-only Forge spec did not start. result=%s" % str(start))
		return

	var directive: Dictionary = start.get("directive", {})
	var drift: Dictionary = directive.get("drift", {})
	if str(drift.get("level", "")) != "wobbly" or str(drift.get("face_hint", "")) != "sweating" or str(drift.get("observer_hint", "")) != "crew_noticing":
		_fail("Wobbly validator drift did not survive in the real run directive. directive=%s" % str(directive))
		return
	if not _start_event_has_drift_hints(start, "sweating", "crew_noticing"):
		_fail("Wobbly run event did not preserve its visual drift hints. result=%s" % str(start))
		return
	var runtime_blocked: Dictionary = harness.block_run(start, {
		"result_detail": "Runtime brush guard changed before dispatch."
	})
	var blocked_drift: Dictionary = runtime_blocked.get("run", {}).get("drift", {})
	if str(blocked_drift.get("level", "")) != "wobbly" or str(blocked_drift.get("face_hint", "")) != "sweating" or str(blocked_drift.get("observer_hint", "")) != "crew_noticing":
		_fail("Runtime blocking rewrote warning-only drift into an impossible visual state. result=%s" % str(runtime_blocked))
		return
	if not _start_event_has_drift_hints(runtime_blocked, "sweating", "crew_noticing"):
		_fail("Runtime-blocked event dropped its warning-only visual hints. result=%s" % str(runtime_blocked))
		return
	var explicitly_steady: Dictionary = harness.block_run(start, {
		"result_detail": "Internal steady override coverage.",
		"drift_level": "steady"
	})
	var steady_drift: Dictionary = explicitly_steady.get("run", {}).get("drift", {})
	if str(steady_drift.get("level", "")) != "steady" or str(steady_drift.get("face_hint", "")) != "focused" or str(steady_drift.get("observer_hint", "")) != "calm":
		_fail("Explicit drift override did not update level and visual hints atomically. result=%s" % str(explicitly_steady))
		return

	var chuck = _agent_actor(scene, "chuck")
	if chuck == null:
		_fail("Could not find Chuck for the wobbly execution visual check.")
		return
	var target = scene.get_node("FarmWorld/GridManager").get_tile(Vector2i(0, 1))
	var decor_before := str(target.decor_id)
	chuck.call("start_directive", str(directive.get("agent_action", "clear_brush")), directive.get("target_tile", Vector2i(0, 1)), "execute wobbly Forge run", {
		"forge_run_id": str(directive.get("forge_run_id", "")),
		"skill_id": str(directive.get("skill_id", "")),
		"skill_name": str(directive.get("skill_name", "")),
		"directive_id": str(directive.get("id", "")),
		"directive_kind": str(directive.get("kind", "")),
		"forge_source_context": directive.get("source_context", {}).duplicate(true),
		"drift": drift.duplicate(true)
	})

	var active: Dictionary = chuck.get("_active_decision")
	var active_drift: Dictionary = active.get("forge_drift", {})
	if active.is_empty() or str(active_drift.get("face_hint", "")) != "sweating" or str(active_drift.get("observer_hint", "")) != "crew_noticing":
		_fail("AgentActor did not consume wobbly drift from the active Forge directive. active=%s" % str(active))
		return
	if str(target.decor_id) != decor_before:
		_fail("Wobbly visual setup executed farm work before the actor reached its target.")
		return
	_assert_actor_visuals(chuck, "o_o;", "Crew notices", "wobbly", "sweating", "crew_noticing", false)
	if _failed:
		return

	chuck.call("_complete_active_decision")
	if _face_text(chuck) != "o_o" or _badge_text(chuck) == "Crew notices":
		_fail("Wobbly execution visuals did not clear when the Forge decision completed.")


func _test_blocked_hallucination_reaction(scene: Node) -> void:
	var harness = SkillForgeRunHarnessScript.new()
	var library = SkillForgeTemplateLibraryScript.new()
	var spec: Dictionary = library.get_template_spec("clear_patch_starter")
	spec["tools"] = ["inspect_tile", "summon_rain"]
	spec["steps"][1]["tool"] = "summon_rain"
	var blocked: Dictionary = scene.call("_start_skill_forge_spec", spec, {
		"agent_id": "bert",
		"agent_name": "Bert",
		"target_tile": Vector2i(0, 1),
		"day": 3
	}, "skill_forge")
	if str(blocked.get("status", "")) != "blocked" or not blocked.get("directive", {}).is_empty():
		_fail("Hallucinating spec did not remain sandbox-blocked. result=%s" % str(blocked))
		return
	if not _start_event_has_drift_hints(blocked, "glitched", "crew_worried"):
		_fail("Blocked run event did not preserve its hallucination visual hints. result=%s" % str(blocked))
		return

	var bert = _agent_actor(scene, "bert")
	if bert == null:
		_fail("Could not find Bert for the blocked hallucination reaction check.")
		return
	var active_before: Dictionary = bert.get("_active_decision").duplicate(true)
	var target_before: Vector2i = bert.target_grid_pos
	var hallucination_drift: Dictionary = blocked.get("run", {}).get("drift", {})
	var live_snapshot: Dictionary = bert.call("get_snapshot")
	if not bool(live_snapshot.get("forge_drift_transient", false)):
		_fail("Game did not route blocked validator hallucination to the named agent.")
		return
	if bert.get("_active_decision") != active_before or bert.target_grid_pos != target_before or not bool(bert.call("is_available")):
		_fail("Blocked hallucination reaction dispatched or occupied the named agent.")
		return
	_assert_actor_visuals(bert, "x_x", "Crew worried", "hallucinating", "glitched", "crew_worried", true)
	if _failed:
		return

	bert.call("_update_forge_drift_reaction", 2.0)
	var snapshot: Dictionary = bert.call("get_snapshot")
	if str(snapshot.get("forge_drift_level", "")) != "" or bool(snapshot.get("forge_drift_transient", true)) or _badge_text(bert) == "Crew worried":
		_fail("Transient hallucination reaction did not restore the idle actor visuals. snapshot=%s" % str(snapshot))
		return
	if not bert.get("_active_decision").is_empty():
		_fail("Transient hallucination expiry unexpectedly dispatched work.")
		return
	if bool(bert.call("show_forge_drift_reaction", {"level": "arbitrary", "face_hint": "angry"}, 1.0)):
		_fail("AgentActor accepted an unrecognized drift payload.")


func _test_game_work_order_drift_bridge(scene: Node) -> void:
	var library = SkillForgeTemplateLibraryScript.new()
	var spec: Dictionary = library.get_template_spec("clear_patch_starter")
	var tools: Array = spec.get("tools", []).duplicate()
	tools.append("inspect_tile")
	spec["tools"] = tools
	var start: Dictionary = scene.call("_start_skill_forge_spec", spec, {
		"agent_id": "chuck",
		"agent_name": "Chuck",
		"target_tile": Vector2i(0, 1),
		"target_source": "selected_tile",
		"day": 3,
		"source_context": {"source": "completed_mission", "label": "Drift bridge QA"}
	}, "skill_forge")
	if str(start.get("status", "")) != "started":
		_fail("Game bridge could not start a warning-only Forge run. result=%s" % str(start))
		return
	var order_id := str(start.get("drafted_order_id", ""))
	var order: Dictionary = scene.work_orders.get(order_id, {})
	var order_drift: Dictionary = order.get("drift", {})
	if order_id == "" or str(order_drift.get("level", "")) != "wobbly":
		_fail("Game dropped validator drift while drafting the work order. order=%s" % str(order))
		return
	var chuck = _agent_actor(scene, "chuck")
	chuck.call("_complete_active_decision")
	chuck.set_process(false)
	scene.call("_on_work_order_requested", order_id)
	var active: Dictionary = chuck.get("_active_decision")
	var active_drift: Dictionary = active.get("forge_drift", {})
	if str(active.get("forge_run_id", "")) != str(start.get("run", {}).get("id", "")) or str(active_drift.get("face_hint", "")) != "sweating" or str(active_drift.get("observer_hint", "")) != "crew_noticing":
		_fail("Game work-order dispatch dropped drift before AgentActor execution. active=%s" % str(active))
		return
	_assert_actor_visuals(chuck, "o_o;", "Crew notices", "wobbly", "sweating", "crew_noticing", false)
	if _failed:
		return
	scene.call("_cancel_pending_skill_forge_run", "drift bridge smoke cleanup", true)
	if not chuck.call("is_available"):
		_fail("Game drift bridge cleanup left Chuck occupied.")


func _assert_actor_visuals(actor, expected_face: String, expected_badge: String, expected_level: String, expected_face_hint: String, expected_observer_hint: String, expected_transient: bool) -> void:
	var snapshot: Dictionary = actor.call("get_snapshot")
	if str(snapshot.get("forge_drift_level", "")) != expected_level or str(snapshot.get("forge_face_hint", "")) != expected_face_hint or str(snapshot.get("forge_observer_hint", "")) != expected_observer_hint or bool(snapshot.get("forge_drift_transient", false)) != expected_transient:
		_fail("Agent snapshot did not expose the active drift visual state. snapshot=%s" % str(snapshot))
		return
	if _face_text(actor) != expected_face:
		_fail("Agent face did not render %s as %s. saw=%s" % [expected_face_hint, expected_face, _face_text(actor)])
		return
	if _badge_text(actor) != expected_badge:
		_fail("Agent observer badge did not render %s as %s. saw=%s" % [expected_observer_hint, expected_badge, _badge_text(actor)])
		return
	var expected_colors := _expected_drift_colors(actor, expected_level)
	var head_color := _mesh_color(actor.get("_head") as MeshInstance3D)
	var pip_color := _mesh_color(actor.get("_mood_pip") as MeshInstance3D)
	if expected_colors.is_empty() or not head_color.is_equal_approx(expected_colors.get("head", Color.BLACK)) or not pip_color.is_equal_approx(expected_colors.get("pip", Color.BLACK)):
		_fail("Agent Drift tint did not match %s. head=%s pip=%s expected=%s" % [expected_level, head_color, pip_color, str(expected_colors)])


func _expected_drift_colors(actor, drift_level: String) -> Dictionary:
	var irritation := float(actor.state.get("irritation", 0.0))
	var heat := clampf(irritation / 80.0, 0.0, 1.0)
	var head_color: Color = (actor.get("_skin_color") as Color).lerp(Color("#ff8a68"), heat * 0.68)
	match drift_level:
		"wobbly":
			return {
				"head": head_color.lerp(Color("#ffd17a"), 0.34),
				"pip": Color("#e7a63b")
			}
		"hallucinating":
			return {
				"head": head_color.lerp(Color("#d58cff"), 0.38),
				"pip": Color("#a959d1")
			}
	return {}


func _mesh_color(mesh_instance: MeshInstance3D) -> Color:
	if mesh_instance == null or not (mesh_instance.material_override is StandardMaterial3D):
		return Color.BLACK
	return (mesh_instance.material_override as StandardMaterial3D).albedo_color


func _start_event_has_drift_hints(result: Dictionary, face_hint: String, observer_hint: String) -> bool:
	for entry in result.get("event_log_entries", []):
		if str(entry.get("type", "")) != "skill_forge_run":
			continue
		var payload: Dictionary = entry.get("payload", {})
		return str(payload.get("drift_face_hint", "")) == face_hint and str(payload.get("drift_observer_hint", "")) == observer_hint
	return false


func _agent_actor(scene: Node, wanted_id: String):
	var agent_manager = scene.get_node("FarmWorld/AgentManager")
	for actor in agent_manager.agents:
		if str(actor.get("agent_id")) == wanted_id:
			return actor
	return null


func _face_text(actor) -> String:
	var face = actor.get_node_or_null("VoxelRig/FaceLabel")
	return str(face.text) if face != null else ""


func _badge_text(actor) -> String:
	var badge = actor.get_node_or_null("VoxelRig/ReasonBadge")
	if badge == null or not badge.visible:
		return ""
	return str(badge.text)


func _fail(message: String) -> void:
	_failed = true
	push_error(message)
	quit(1)
