extends SceneTree

const SkillCheckEvaluatorScript := preload("res://scripts/systems/SkillCheckEvaluator.gd")

var _failed := false
var _evaluator = SkillCheckEvaluatorScript.new()


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_tile_state()
	_test_crop_planted()
	_test_crop_growth_advanced()
	_test_inventory_delta()
	_test_supported_guards()
	_test_guard_failures()
	_test_unknown_guard_fails_closed()
	_test_malformed_and_missing_tiles_fail_closed()
	if not _failed:
		quit()


func _test_tile_state() -> void:
	var before := _snapshot(_tile({"decor_id": "tall_grass"}))
	var cleared := _snapshot(_tile())
	var passed: Dictionary = _evaluator.evaluate({
		"type": "tile_state",
		"target": "context.target",
		"decor_id": ""
	}, before, cleared)
	_assert_verdict(passed, true, "tile_state", "no decor")

	var failed: Dictionary = _evaluator.evaluate({
		"type": "tile_state",
		"target": "context.target",
		"decor_id": "fence"
	}, before, cleared)
	_assert_verdict(failed, false, "tile_state", "Expected decor fence")


func _test_crop_planted() -> void:
	var before := _snapshot(_tile({"is_tilled": true, "terrain": "soil"}))
	var after := _snapshot(_tile({
		"is_tilled": true,
		"terrain": "soil",
		"crop": {"crop_id": "wheat", "stage": 0, "ready": false}
	}))
	var passed: Dictionary = _evaluator.evaluate({
		"type": "crop_state",
		"target": "context.target",
		"state": "planted"
	}, before, after)
	_assert_verdict(passed, true, "crop_state", "no crop -> wheat stage 0")

	var failed: Dictionary = _evaluator.evaluate({
		"type": "crop_state",
		"target": "context.target",
		"state": "planted"
	}, before, before)
	_assert_verdict(failed, false, "crop_state", "Expected a newly planted crop")


func _test_crop_growth_advanced() -> void:
	var before := _snapshot(_tile({
		"crop": {"crop_id": "corn", "stage": 1, "ready": false}
	}))
	var after := _snapshot(_tile({
		"crop": {"crop_id": "corn", "stage": 2, "ready": false}
	}))
	var passed: Dictionary = _evaluator.evaluate({
		"type": "crop_state",
		"target": "context.target",
		"state": "growth_advanced"
	}, before, after)
	_assert_verdict(passed, true, "crop_state", "corn stage 1 -> corn stage 2")

	var unchanged := _snapshot(_tile({
		"crop": {"crop_id": "corn", "stage": 1, "ready": false}
	}))
	var failed: Dictionary = _evaluator.evaluate({
		"type": "crop_state",
		"target": "context.target",
		"state": "growth_advanced"
	}, before, unchanged)
	_assert_verdict(failed, false, "crop_state", "Expected the same crop's growth stage to increase")


func _test_inventory_delta() -> void:
	var tile := _tile({"crop": {"crop_id": "corn", "stage": 3, "ready": true}})
	var before := _snapshot(tile, {"resources": {"grain": 2}})
	var after := _snapshot(_tile(), {"resources": {"grain": 3}})
	var check := {
		"type": "inventory_delta",
		"target": "context.target",
		"item": "grain",
		"min_delta": 1
	}
	var passed: Dictionary = _evaluator.evaluate(check, before, after)
	_assert_verdict(passed, true, "inventory_delta", "observed +1 grain")

	var unchanged := _snapshot(tile, {"resources": {"grain": 2}})
	var failed: Dictionary = _evaluator.evaluate(check, before, unchanged)
	_assert_verdict(failed, false, "inventory_delta", "observed +0 grain")


func _test_supported_guards() -> void:
	_assert_guard("always", _snapshot(_tile()), true, "passed")
	_assert_guard("inspect.has_brush", _snapshot(_tile({"decor_id": "flower_patch"})), true, "flower patch")
	_assert_guard("crop.needs_tending", _snapshot(_tile({"crop": {"crop_id": "wheat", "stage": 1, "ready": false}})), true, "growing wheat crop")
	_assert_guard("crop.ready", _snapshot(_tile({"crop": {"crop_id": "corn", "stage": 3, "ready": true}})), true, "ready corn crop")
	_assert_guard("tile.empty", _snapshot(_tile()), true, "empty tile")


func _test_guard_failures() -> void:
	_assert_guard("always", _evaluator.snapshot(null, {}, Vector2i(3, 4)), false, "no tile exists")
	_assert_guard("inspect.has_brush", _snapshot(_tile()), false, "expected brush")
	_assert_guard("crop.needs_tending", _snapshot(_tile({"crop": {"crop_id": "corn", "stage": 3, "ready": true}})), false, "expected a growing crop")
	_assert_guard("crop.ready", _snapshot(_tile({"crop": {"crop_id": "corn", "stage": 1, "ready": false}})), false, "expected a ready crop")
	_assert_guard("tile.empty", _snapshot(_tile({"decor_id": "fence"})), false, "expected an empty tile")


func _test_unknown_guard_fails_closed() -> void:
	var result: Dictionary = _evaluator.evaluate_guard("weather.raining", _snapshot(_tile()))
	if bool(result.get("allowed", true)):
		_fail("Unknown guard did not fail closed. result=%s" % str(result))
		return
	if not str(result.get("result_detail", "")).contains("unsupported condition weather.raining"):
		_fail("Unknown guard did not explain the unsupported condition. result=%s" % str(result))


func _test_malformed_and_missing_tiles_fail_closed() -> void:
	var valid := _snapshot(_tile())
	var malformed: Dictionary = _evaluator.evaluate({}, valid, valid)
	_assert_verdict(malformed, false, "", "malformed")

	var missing := _evaluator.snapshot(null, {}, Vector2i(3, 4))
	var missing_result: Dictionary = _evaluator.evaluate({
		"type": "tile_state",
		"target": "context.target",
		"decor_id": ""
	}, missing, missing)
	_assert_verdict(missing_result, false, "tile_state", "no target tile")

	var other_target := _evaluator.snapshot(_tile(), {}, Vector2i(4, 4))
	var mismatched: Dictionary = _evaluator.evaluate({
		"type": "tile_state",
		"target": "context.target",
		"decor_id": ""
	}, valid, other_target)
	_assert_verdict(mismatched, false, "tile_state", "different targets")

	var malformed_crop: Dictionary = _evaluator.evaluate({
		"type": "crop_state",
		"target": "context.target",
		"state": "ripe_enough"
	}, valid, valid)
	_assert_verdict(malformed_crop, false, "crop_state", "unsupported state")


func _snapshot(tile: Dictionary, inventory: Dictionary = {}) -> Dictionary:
	return _evaluator.snapshot(tile, inventory, Vector2i(3, 4))


func _tile(overrides: Dictionary = {}) -> Dictionary:
	var result := {
		"terrain": "grass",
		"is_tilled": false,
		"decor_id": "",
		"structure_id": "",
		"crop": null
	}
	for key in overrides.keys():
		result[key] = overrides[key]
	return result


func _assert_verdict(result: Dictionary, expected_pass: bool, check_type: String, detail_fragment: String) -> void:
	if _failed:
		return
	if bool(result.get("passed", not expected_pass)) != expected_pass:
		_fail("Evaluator verdict mismatch. expected=%s result=%s" % [expected_pass, str(result)])
		return
	if str(result.get("check_type", "")) != check_type:
		_fail("Evaluator check type mismatch. expected=%s result=%s" % [check_type, str(result)])
		return
	if str(result.get("expected", "")).strip_edges() == "" or str(result.get("observed", "")).strip_edges() == "":
		_fail("Evaluator verdict omitted observed/expected details. result=%s" % str(result))
		return
	if not str(result.get("result_detail", "")).contains(detail_fragment):
		_fail("Evaluator detail did not contain '%s'. result=%s" % [detail_fragment, str(result)])


func _assert_guard(condition: String, current: Dictionary, expected_allowed: bool, detail_fragment: String) -> void:
	if _failed:
		return
	var result: Dictionary = _evaluator.evaluate_guard(condition, current)
	if bool(result.get("allowed", not expected_allowed)) != expected_allowed:
		_fail("Guard verdict mismatch for %s. expected=%s result=%s" % [condition, expected_allowed, str(result)])
		return
	if str(result.get("condition", "")) != condition:
		_fail("Guard condition was not preserved. expected=%s result=%s" % [condition, str(result)])
		return
	if str(result.get("expected", "")).strip_edges() == "" or str(result.get("observed", "")).strip_edges() == "":
		_fail("Guard verdict omitted observed/expected details. result=%s" % str(result))
		return
	if not str(result.get("result_detail", "")).contains(detail_fragment):
		_fail("Guard detail did not contain '%s'. result=%s" % [detail_fragment, str(result)])


func _fail(message: String) -> void:
	_failed = true
	push_error(message)
	quit(1)
