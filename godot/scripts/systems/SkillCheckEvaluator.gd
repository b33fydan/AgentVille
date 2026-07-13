class_name SkillCheckEvaluator
extends RefCounted

const SUPPORTED_GUARDS := [
	"always",
	"inspect.has_brush",
	"crop.needs_tending",
	"crop.ready",
	"tile.empty"
]


func snapshot(tile = null, inventory: Dictionary = {}, target: Vector2i = Vector2i(-1, -1)) -> Dictionary:
	var tile_exists := _is_tile_value(tile)
	var tile_state := {
		"terrain": "",
		"is_tilled": false,
		"decor_id": "",
		"structure_id": "",
		"crop_exists": false,
		"crop_id": "",
		"crop_stage": -1,
		"crop_ready": false
	}

	if tile_exists:
		tile_state["terrain"] = str(_value_from(tile, "terrain", ""))
		tile_state["is_tilled"] = bool(_value_from(tile, "is_tilled", false))
		tile_state["decor_id"] = str(_value_from(tile, "decor_id", ""))
		tile_state["structure_id"] = str(_value_from(tile, "structure_id", ""))
		var crop_value = _value_from(tile, "crop", null)
		var crop_exists := _is_crop_value(crop_value)
		if not crop_exists:
			crop_exists = bool(_value_from(tile, "crop_exists", false))
		tile_state["crop_exists"] = crop_exists
		if crop_exists:
			if _is_crop_value(crop_value):
				tile_state["crop_id"] = str(_value_from(crop_value, "crop_id", ""))
				tile_state["crop_stage"] = int(_value_from(crop_value, "stage", -1))
				tile_state["crop_ready"] = _crop_ready_from(crop_value)
			else:
				tile_state["crop_id"] = str(_value_from(tile, "crop_id", ""))
				tile_state["crop_stage"] = int(_value_from(tile, "crop_stage", -1))
				tile_state["crop_ready"] = bool(_value_from(tile, "crop_ready", false))

	return {
		"target": target,
		"tile_exists": tile_exists,
		"tile": tile_state,
		"inventory": _normalize_inventory(inventory)
	}


func evaluate(success_check: Dictionary, before: Dictionary, after: Dictionary) -> Dictionary:
	var check_type := str(success_check.get("type", "")).strip_edges()
	if check_type == "":
		return _verdict(false, "", "a supported success check", "no success check type", "Success check is malformed: expected a supported check type, observed none.")

	var snapshot_error := _snapshot_error(before, after)
	if snapshot_error != "":
		return _verdict(false, check_type, "the same existing farm tile before and after the run", snapshot_error, "Success check could not run: expected the same existing farm tile before and after the run, observed %s." % snapshot_error)

	match check_type:
		"tile_state":
			return _evaluate_tile_state(success_check, after)
		"crop_state":
			return _evaluate_crop_state(success_check, before, after)
		"inventory_delta":
			return _evaluate_inventory_delta(success_check, before, after)
		_:
			return _verdict(false, check_type, "one of tile_state, crop_state, or inventory_delta", "unsupported check %s" % check_type, "Success check is unsupported: expected tile_state, crop_state, or inventory_delta, observed %s." % check_type)


func evaluate_guard(condition: String, current: Dictionary) -> Dictionary:
	condition = condition.strip_edges()
	if condition == "":
		condition = "always"

	var target: Vector2i = _target_from_snapshot(current)
	if not SUPPORTED_GUARDS.has(condition):
		return _guard_verdict(false, condition, target, "a supported guard condition", "unsupported condition %s" % condition)
	if not bool(current.get("tile_exists", false)):
		return _guard_verdict(false, condition, target, _guard_expectation(condition), "no tile exists")

	var tile: Dictionary = current.get("tile", {})
	var allowed := false
	match condition:
		"always":
			allowed = true
		"inspect.has_brush":
			allowed = str(tile.get("decor_id", "")) in ["tall_grass", "flower_patch"]
		"crop.needs_tending":
			allowed = bool(tile.get("crop_exists", false)) and not bool(tile.get("crop_ready", false))
		"crop.ready":
			allowed = bool(tile.get("crop_exists", false)) and bool(tile.get("crop_ready", false))
		"tile.empty":
			allowed = not bool(tile.get("crop_exists", false)) and str(tile.get("decor_id", "")) == "" and str(tile.get("structure_id", "")) == ""

	return _guard_verdict(allowed, condition, target, _guard_expectation(condition), _describe_tile(tile))


func _evaluate_tile_state(success_check: Dictionary, after: Dictionary) -> Dictionary:
	if not success_check.has("decor_id"):
		return _verdict(false, "tile_state", "an explicit decor_id", "no decor_id was provided", "Tile-state check is malformed: expected an explicit decor_id, observed none.")

	var tile: Dictionary = after.get("tile", {})
	var expected_decor := str(success_check.get("decor_id", ""))
	var observed_decor := str(tile.get("decor_id", ""))
	var passed := observed_decor == expected_decor
	var expected := _decor_words(expected_decor)
	var observed := _decor_words(observed_decor)
	return _verdict(passed, "tile_state", expected, observed, "Expected %s on the target tile, observed %s." % [expected, observed])


func _evaluate_crop_state(success_check: Dictionary, before: Dictionary, after: Dictionary) -> Dictionary:
	var state := str(success_check.get("state", "")).strip_edges()
	var before_tile: Dictionary = before.get("tile", {})
	var after_tile: Dictionary = after.get("tile", {})
	var observed := _crop_transition(before_tile, after_tile)

	match state:
		"planted":
			var planted := not bool(before_tile.get("crop_exists", false)) and bool(after_tile.get("crop_exists", false))
			return _verdict(planted, "crop_state", "a newly planted crop", observed, "Expected a newly planted crop, observed %s." % observed)
		"growth_advanced":
			var before_exists := bool(before_tile.get("crop_exists", false))
			var after_exists := bool(after_tile.get("crop_exists", false))
			var same_crop := str(before_tile.get("crop_id", "")) == str(after_tile.get("crop_id", ""))
			var advanced := before_exists and after_exists and same_crop and int(after_tile.get("crop_stage", -1)) > int(before_tile.get("crop_stage", -1))
			return _verdict(advanced, "crop_state", "the same crop's growth stage to increase", observed, "Expected the same crop's growth stage to increase, observed %s." % observed)
		_:
			var observed_state := "no crop-state name" if state == "" else "unsupported state %s" % state
			return _verdict(false, "crop_state", "planted or growth_advanced", observed_state, "Crop-state check is malformed: expected planted or growth_advanced, observed %s." % observed_state)


func _evaluate_inventory_delta(success_check: Dictionary, before: Dictionary, after: Dictionary) -> Dictionary:
	var item := str(success_check.get("item", "")).strip_edges()
	if item == "" or not success_check.has("min_delta"):
		var observed := "no item id" if item == "" else "no minimum delta"
		return _verdict(false, "inventory_delta", "an item id and minimum delta", observed, "Inventory-delta check is malformed: expected an item id and minimum delta, observed %s." % observed)

	var minimum := int(success_check.get("min_delta", 0))
	var before_count := _inventory_count(before.get("inventory", {}), item)
	var after_count := _inventory_count(after.get("inventory", {}), item)
	var delta := after_count - before_count
	var passed := delta >= minimum
	var expected := "at least %s %s" % [_signed_amount(minimum), _item_words(item)]
	var observed := "%s %s" % [_signed_amount(delta), _item_words(item)]
	return _verdict(passed, "inventory_delta", expected, observed, "Expected %s, observed %s." % [expected, observed])


func _snapshot_error(before: Dictionary, after: Dictionary) -> String:
	if not bool(before.get("tile_exists", false)) and not bool(after.get("tile_exists", false)):
		return "no target tile in either snapshot"
	if not bool(before.get("tile_exists", false)):
		return "no target tile before the run"
	if not bool(after.get("tile_exists", false)):
		return "no target tile after the run"
	var before_target := _target_from_snapshot(before)
	var after_target := _target_from_snapshot(after)
	if before_target != after_target:
		return "different targets %s and %s" % [_format_target(before_target), _format_target(after_target)]
	return ""


func _guard_verdict(allowed: bool, condition: String, target: Vector2i, expected: String, observed: String) -> Dictionary:
	var detail := "Guard %s passed at tile %s: observed %s." % [condition, _format_target(target), observed]
	if not allowed:
		detail = "Guard %s blocked at tile %s: expected %s, observed %s." % [condition, _format_target(target), expected, observed]
	return {
		"allowed": allowed,
		"condition": condition,
		"expected": expected,
		"observed": observed,
		"result_detail": detail
	}


func _verdict(passed: bool, check_type: String, expected: String, observed: String, detail: String) -> Dictionary:
	return {
		"passed": passed,
		"status": "passed" if passed else "failed",
		"check_type": check_type,
		"expected": expected,
		"observed": observed,
		"result_detail": detail
	}


func _normalize_inventory(inventory: Dictionary) -> Dictionary:
	var resources = inventory.get("resources", {})
	if typeof(resources) != TYPE_DICTIONARY:
		resources = {}
	var crafted_items = inventory.get("crafted_items", {})
	if typeof(crafted_items) != TYPE_DICTIONARY:
		crafted_items = {}
	return {
		"resources": resources.duplicate(true),
		"crafted_items": crafted_items.duplicate(true),
		"money": int(inventory.get("money", 0))
	}


func _inventory_count(inventory, item: String) -> int:
	if typeof(inventory) != TYPE_DICTIONARY:
		return 0
	var resources = inventory.get("resources", {})
	if typeof(resources) == TYPE_DICTIONARY and resources.has(item):
		return int(resources.get(item, 0))
	var crafted_items = inventory.get("crafted_items", {})
	if typeof(crafted_items) == TYPE_DICTIONARY and crafted_items.has(item):
		return int(crafted_items.get(item, 0))
	if item == "money":
		return int(inventory.get("money", 0))
	return 0


func _is_tile_value(value) -> bool:
	if typeof(value) == TYPE_DICTIONARY:
		if value.has("tile_exists") and not bool(value.get("tile_exists", false)):
			return false
		return not value.is_empty()
	return typeof(value) == TYPE_OBJECT and is_instance_valid(value)


func _is_crop_value(value) -> bool:
	if typeof(value) == TYPE_DICTIONARY:
		return not value.is_empty()
	return typeof(value) == TYPE_OBJECT and is_instance_valid(value)


func _value_from(value, key: String, fallback):
	if typeof(value) == TYPE_DICTIONARY:
		return value.get(key, fallback)
	if typeof(value) != TYPE_OBJECT or not is_instance_valid(value):
		return fallback
	for property in value.get_property_list():
		if str(property.get("name", "")) == key:
			return value.get(key)
	return fallback


func _crop_ready_from(crop_value) -> bool:
	if typeof(crop_value) == TYPE_OBJECT and is_instance_valid(crop_value) and crop_value.has_method("is_ready"):
		return bool(crop_value.call("is_ready"))
	if typeof(crop_value) == TYPE_DICTIONARY:
		if crop_value.has("ready"):
			return bool(crop_value.get("ready", false))
		if crop_value.has("crop_ready"):
			return bool(crop_value.get("crop_ready", false))
		if crop_value.has("max_stage"):
			return int(crop_value.get("stage", -1)) >= int(crop_value.get("max_stage", 0))
	return false


func _target_from_snapshot(value: Dictionary) -> Vector2i:
	var target = value.get("target", Vector2i(-1, -1))
	match typeof(target):
		TYPE_VECTOR2I:
			return target
		TYPE_VECTOR2:
			return Vector2i(int(target.x), int(target.y))
		TYPE_ARRAY:
			if target.size() >= 2:
				return Vector2i(int(target[0]), int(target[1]))
		TYPE_DICTIONARY:
			return Vector2i(int(target.get("x", -1)), int(target.get("y", -1)))
	return Vector2i(-1, -1)


func _guard_expectation(condition: String) -> String:
	match condition:
		"always":
			return "the selected tile to exist"
		"inspect.has_brush":
			return "brush such as tall grass or flowers"
		"crop.needs_tending":
			return "a growing crop that is not ready"
		"crop.ready":
			return "a ready crop"
		"tile.empty":
			return "an empty tile with no crop, decor, or structure"
	return "a supported guard condition"


func _describe_tile(tile: Dictionary) -> String:
	if bool(tile.get("crop_exists", false)):
		var crop_id := str(tile.get("crop_id", "crop")).strip_edges()
		if crop_id == "":
			crop_id = "crop"
		if bool(tile.get("crop_ready", false)):
			return "a ready %s crop" % crop_id
		return "a growing %s crop at stage %s" % [crop_id, int(tile.get("crop_stage", -1))]
	var structure_id := str(tile.get("structure_id", "")).strip_edges()
	if structure_id != "":
		return "structure %s" % _item_words(structure_id)
	var decor_id := str(tile.get("decor_id", "")).strip_edges()
	if decor_id != "":
		return "decor %s" % _item_words(decor_id)
	if bool(tile.get("is_tilled", false)):
		return "an empty tilled tile"
	return "an empty tile"


func _crop_transition(before_tile: Dictionary, after_tile: Dictionary) -> String:
	return "%s -> %s" % [_crop_words(before_tile), _crop_words(after_tile)]


func _crop_words(tile: Dictionary) -> String:
	if not bool(tile.get("crop_exists", false)):
		return "no crop"
	var crop_id := str(tile.get("crop_id", "crop")).strip_edges()
	if crop_id == "":
		crop_id = "crop"
	var stage := int(tile.get("crop_stage", -1))
	return "%s stage %s" % [crop_id, stage]


func _decor_words(decor_id: String) -> String:
	if decor_id == "":
		return "no decor"
	return "decor %s" % _item_words(decor_id)


func _item_words(item: String) -> String:
	return item.replace("_", " ")


func _signed_amount(amount: int) -> String:
	return "+%s" % amount if amount >= 0 else str(amount)


func _format_target(target: Vector2i) -> String:
	return "(%s,%s)" % [target.x, target.y]
