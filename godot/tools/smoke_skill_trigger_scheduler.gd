extends SceneTree

const SkillTriggerSchedulerScript := preload("res://scripts/systems/SkillTriggerScheduler.gd")

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_initial_state()
	_test_deep_copy_and_next_day_consumption()
	_test_replacement()
	_test_disarm()
	if not _failed:
		quit()


func _test_initial_state() -> void:
	var scheduler = SkillTriggerSchedulerScript.new()
	if scheduler.has_armed():
		_fail("A new trigger scheduler started armed.")
		return
	if not scheduler.snapshot().is_empty():
		_fail("A new trigger scheduler exposed a non-empty snapshot.")
		return
	var idle: Dictionary = scheduler.consume_day_start(1)
	if str(idle.get("status", "")) != "idle" or bool(idle.get("fired", true)) or bool(idle.get("consumed", true)):
		_fail("An idle scheduler reported a fired trigger. result=%s" % str(idle))


func _test_deep_copy_and_next_day_consumption() -> void:
	var scheduler = SkillTriggerSchedulerScript.new()
	var spec := _day_start_spec("Morning Plant")
	var request := {
		"agent_id": "marigold",
		"target_tile": Vector2i(2, 4),
		"source_context": {"label": "Selected 2,4"}
	}
	var source := {
		"text": "agent \"Marigold\" { on day_start }",
		"metadata": {"draft": 1}
	}
	var source_map := {
		"trigger.type": {"line": 2, "column": 6}
	}
	var armed: Dictionary = scheduler.arm(spec, request, source, source_map, 7)
	if str(armed.get("status", "")) != "armed" or not bool(armed.get("armed", false)):
		_fail("A valid day-start program did not arm. result=%s" % str(armed))
		return
	if str(armed.get("arm", {}).get("id", "")) != "day_start_arm_001":
		_fail("The first arm did not receive its deterministic ID. result=%s" % str(armed))
		return

	# Mutate every caller-owned container after arming. The captured target and
	# teaching context must remain exactly as they were at Compile time.
	spec["name"] = "Changed"
	spec["steps"][0]["tool"] = "clear_brush"
	request["target_tile"] = Vector2i(9, 9)
	request["source_context"]["label"] = "Changed"
	source["text"] = "changed"
	source["metadata"]["draft"] = 2
	source_map["trigger.type"]["line"] = 99
	var captured: Dictionary = scheduler.snapshot()
	if str(captured.get("spec", {}).get("name", "")) != "Morning Plant" \
		or str(captured.get("spec", {}).get("steps", [])[0].get("tool", "")) != "plant_seed":
		_fail("The scheduler retained a mutable reference to the authored spec. snapshot=%s" % str(captured))
		return
	if captured.get("request", {}).get("target_tile", Vector2i.ZERO) != Vector2i(2, 4) \
		or str(captured.get("request", {}).get("source_context", {}).get("label", "")) != "Selected 2,4":
		_fail("The scheduler retained a mutable request or retargeted the arm. snapshot=%s" % str(captured))
		return
	if str(captured.get("source", {}).get("text", "")) == "changed" \
		or int(captured.get("source", {}).get("metadata", {}).get("draft", 0)) != 1 \
		or int(captured.get("source_map", {}).get("trigger.type", {}).get("line", 0)) != 2:
		_fail("The scheduler retained mutable source evidence. snapshot=%s" % str(captured))
		return

	# A returned snapshot is also caller-owned and cannot mutate the scheduler.
	captured["request"]["target_tile"] = Vector2i(8, 8)
	if scheduler.snapshot().get("request", {}).get("target_tile", Vector2i.ZERO) != Vector2i(2, 4):
		_fail("Mutating a returned snapshot changed the armed target.")
		return

	var same_day: Dictionary = scheduler.consume_day_start(7)
	if str(same_day.get("status", "")) != "waiting" or bool(same_day.get("fired", true)) or bool(same_day.get("consumed", true)):
		_fail("A same-day consume attempt fired the arm. result=%s" % str(same_day))
		return
	if not scheduler.has_armed():
		_fail("A same-day consume attempt removed the arm.")
		return

	var next_day: Dictionary = scheduler.consume_day_start(8)
	if str(next_day.get("status", "")) != "fired" or not bool(next_day.get("fired", false)) or not bool(next_day.get("consumed", false)):
		_fail("The next day did not consume the arm. result=%s" % str(next_day))
		return
	if next_day.get("arm", {}).get("request", {}).get("target_tile", Vector2i.ZERO) != Vector2i(2, 4):
		_fail("The consumed activation lost its captured target. result=%s" % str(next_day))
		return
	if scheduler.has_armed():
		_fail("A fired one-shot arm remained scheduled.")
		return
	var second_consume: Dictionary = scheduler.consume_day_start(9)
	if str(second_consume.get("status", "")) != "idle" or bool(second_consume.get("fired", true)):
		_fail("A one-shot arm fired more than once. result=%s" % str(second_consume))


func _test_replacement() -> void:
	var scheduler = SkillTriggerSchedulerScript.new()
	var first: Dictionary = scheduler.arm(
		_day_start_spec("First"),
		{"target_tile": Vector2i(1, 1)},
		"first source",
		{},
		3
	)
	var second: Dictionary = scheduler.arm(
		_day_start_spec("Second"),
		{"target_tile": Vector2i(4, 5)},
		"second source",
		{},
		3
	)
	if str(first.get("arm", {}).get("id", "")) != "day_start_arm_001" \
		or str(second.get("arm", {}).get("id", "")) != "day_start_arm_002":
		_fail("Replacement IDs were not stable and monotonic. first=%s second=%s" % [str(first), str(second)])
		return
	if str(second.get("status", "")) != "replaced" or not bool(second.get("replaced", false)):
		_fail("The second arm did not report explicit replacement. result=%s" % str(second))
		return
	if str(second.get("previous_arm", {}).get("spec", {}).get("name", "")) != "First":
		_fail("Replacement did not return the prior arm snapshot. result=%s" % str(second))
		return
	if str(scheduler.snapshot().get("spec", {}).get("name", "")) != "Second" \
		or scheduler.snapshot().get("request", {}).get("target_tile", Vector2i.ZERO) != Vector2i(4, 5):
		_fail("Replacement did not leave exactly the newest arm scheduled.")


func _test_disarm() -> void:
	var scheduler = SkillTriggerSchedulerScript.new()
	var armed: Dictionary = scheduler.arm(
		_day_start_spec("Disarm Me"),
		{"target_tile": Vector2i(6, 2)},
		"source",
		{},
		4
	)
	var arm_id := str(armed.get("arm", {}).get("id", ""))
	var disarmed: Dictionary = scheduler.disarm("player_requested")
	if str(disarmed.get("status", "")) != "disarmed" or not bool(disarmed.get("disarmed", false)):
		_fail("An armed trigger did not disarm. result=%s" % str(disarmed))
		return
	if str(disarmed.get("reason", "")) != "player_requested" \
		or str(disarmed.get("arm", {}).get("id", "")) != arm_id:
		_fail("Disarm did not return its reason and prior snapshot. result=%s" % str(disarmed))
		return
	if scheduler.has_armed():
		_fail("Disarm left an activation scheduled.")
		return
	var idle_disarm: Dictionary = scheduler.disarm("again")
	if str(idle_disarm.get("status", "")) != "idle" or bool(idle_disarm.get("disarmed", true)):
		_fail("Disarming an idle scheduler reported a consumed arm. result=%s" % str(idle_disarm))


func _day_start_spec(label: String) -> Dictionary:
	return {
		"id": label.to_snake_case(),
		"name": label,
		"trigger": {"type": "day_start"},
		"steps": [{"tool": "plant_seed", "target": "selected_tile"}]
	}


func _fail(message: String) -> void:
	if _failed:
		return
	_failed = true
	push_error(message)
	quit(1)
