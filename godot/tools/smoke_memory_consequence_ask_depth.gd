extends SceneTree

const AdversarialSessionManagerScript := preload("res://scripts/ai/AdversarialSessionManager.gd")

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_memory_consequence_sources_shape_followup_asks()
	if not _failed:
		quit()


func _test_memory_consequence_sources_shape_followup_asks() -> void:
	var mission_demand := _resolved_supply_demand({
		"id": "marigold",
		"name": "Marigold",
		"trait": "hopeful",
		"irritation": 22.0,
		"memory_consequence_source": "completed_mission",
		"memory_consequence_label": "Marigold Growth Run",
		"memory_consequence_days": 1
	})
	if str(mission_demand.get("kind", "")) != "deliver_item" or str(mission_demand.get("required_item", "")) != "seed_bundle":
		_fail("Completed Growth Run did not turn mission momentum into a Seed Bundle restock ask.")
		return
	if str(mission_demand.get("preference_source", "")) != "completed_mission":
		_fail("Completed mission ask did not preserve its preference source.")
		return

	var ignored_demand := _resolved_supply_demand({
		"id": "marigold",
		"name": "Marigold",
		"trait": "hopeful",
		"irritation": 36.0,
		"memory_consequence_source": "ignored_ask",
		"memory_consequence_label": "Seed Bundle",
		"memory_consequence_days": 1
	})
	if str(ignored_demand.get("kind", "")) != "deliver_item" or str(ignored_demand.get("required_item", "")) != "seed_bundle":
		_fail("Ignored Seed Bundle ask did not press the original supply request.")
		return
	if str(ignored_demand.get("preference_source", "")) != "ignored_ask":
		_fail("Ignored ask demand did not preserve its preference source.")
		return

	var completed_order_demand := _resolved_supply_demand({
		"id": "chuck",
		"name": "Chuck",
		"trait": "chaotic",
		"irritation": 28.0,
		"memory_consequence_source": "completed_order",
		"memory_consequence_label": "Clear Brush",
		"memory_consequence_days": 1
	})
	if str(completed_order_demand.get("kind", "")) != "deliver_item" or str(completed_order_demand.get("required_item", "")) != "rush_kit":
		_fail("Completed brush order did not follow through with a Rush Kit support ask.")
		return
	if str(completed_order_demand.get("preference_source", "")) != "completed_order":
		_fail("Completed-order demand did not preserve its preference source.")
		return

	var held_truce_demand := _resolved_supply_demand({
		"id": "bert",
		"name": "Bert",
		"trait": "grizzled",
		"irritation": 30.0,
		"memory_consequence_source": "held_truce",
		"memory_consequence_label": "Fence Kit",
		"memory_consequence_days": 1
	})
	if str(held_truce_demand.get("kind", "")) != "build_fence":
		_fail("Held Fence Kit truce did not keep the follow-up ask on boundary work.")
		return
	if str(held_truce_demand.get("preference_source", "")) != "held_truce":
		_fail("Held-truce demand did not preserve its preference source.")
		return


func _resolved_supply_demand(agent_snapshot: Dictionary) -> Dictionary:
	var manager = AdversarialSessionManagerScript.new()
	manager.start_session(agent_snapshot, {
		"day": 4,
		"demand_hint": "deliver_agent_supply",
		"recent_failures": 1
	})
	manager.choose_response("own_mistake")
	var result: Dictionary = manager.choose_response("own_mistake")
	return result.get("crafting_demand", {})


func _fail(message: String) -> void:
	_failed = true
	push_error(message)
	quit(1)
