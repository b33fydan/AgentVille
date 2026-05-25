class_name PlacementTool
extends Node

const PlacementPreviewScript: Script = preload("res://scripts/tools/PlacementPreview.gd")

signal action_performed(message: String)
signal harvest_collected(amount: int)
signal sound_requested(stamp_name: String)
signal action_logged(event: Dictionary)
signal crew_order_targeted(action_id: String, grid_pos: Vector2i)

enum Tool { PLACE, TILL, PLANT, HARVEST, ERASE, PAN, SELECT }

var current_tool: Tool = Tool.TILL
var selected_item_id: String = "corn_seed"
var grid_manager
var camera_controller
var game_ui
var item_availability_checker: Callable
var crew_order_target_checker: Callable

var _hovered_tile
var _preview
var _crew_order_action_id: String = ""
var _crew_order_preview_item_id: String = ""


func configure(new_grid_manager, new_camera_controller, new_game_ui) -> void:
	grid_manager = new_grid_manager
	camera_controller = new_camera_controller
	game_ui = new_game_ui
	_setup_preview()


func set_tool(tool_name: String) -> void:
	match tool_name:
		"place":
			current_tool = Tool.PLACE
		"till":
			current_tool = Tool.TILL
		"plant":
			current_tool = Tool.PLANT
		"harvest":
			current_tool = Tool.HARVEST
		"erase":
			current_tool = Tool.ERASE
		"pan":
			current_tool = Tool.PAN
		"select":
			current_tool = Tool.SELECT
		_:
			current_tool = Tool.PLACE

	if camera_controller:
		camera_controller.set_pan_tool_active(current_tool == Tool.PAN)
	_update_preview_visibility()


func set_selected_item(item_id: String) -> void:
	selected_item_id = item_id
	if _preview:
		_preview.call("set_item", selected_item_id)
	_update_preview_visibility()


func set_item_availability_checker(checker: Callable) -> void:
	item_availability_checker = checker
	_update_preview_visibility()


func set_crew_order_target_checker(checker: Callable) -> void:
	crew_order_target_checker = checker
	_update_preview_visibility()


func set_crew_order_targeting(action_id: String, preview_item_id: String) -> void:
	_crew_order_action_id = action_id
	_crew_order_preview_item_id = preview_item_id
	if camera_controller:
		camera_controller.set_pan_tool_active(false)
	_update_preview_visibility()


func clear_crew_order_targeting() -> void:
	if _crew_order_action_id == "":
		return
	_crew_order_action_id = ""
	_crew_order_preview_item_id = ""
	if camera_controller:
		camera_controller.set_pan_tool_active(current_tool == Tool.PAN)
	_update_preview_visibility()


func _input(event: InputEvent) -> void:
	if grid_manager == null:
		return

	if event is InputEventMouseMotion:
		_update_hover((event as InputEventMouseMotion).position)

	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT and mouse_button.pressed:
			_update_hover(mouse_button.position)
			if _hovered_tile:
				if _is_targeting_crew_order():
					crew_order_targeted.emit(_crew_order_action_id, _hovered_tile.grid_pos)
				elif current_tool != Tool.PAN:
					_apply_to_tile(_hovered_tile)
				get_viewport().set_input_as_handled()


func _update_hover(mouse_position: Vector2) -> void:
	if game_ui != null and game_ui.is_pointer_over_ui(mouse_position):
		_set_hovered_tile(null)
		_update_preview_visibility()
		return

	var camera := get_viewport().get_camera_3d()
	if camera == null:
		_set_hovered_tile(null)
		_update_preview_visibility()
		return

	var ray_origin := camera.project_ray_origin(mouse_position)
	var ray_direction := camera.project_ray_normal(mouse_position)
	var hit = Plane(Vector3.UP, 0.08).intersects_ray(ray_origin, ray_direction)
	if hit == null:
		_set_hovered_tile(null)
		_update_preview_visibility()
		return

	_set_hovered_tile(grid_manager.get_tile_from_world(hit))
	_update_preview_visibility()


func _set_hovered_tile(tile) -> void:
	if _hovered_tile == tile:
		return
	if _hovered_tile:
		_hovered_tile.set_hovered(false)
	_hovered_tile = tile
	if _hovered_tile:
		_hovered_tile.set_hovered(true)


func _apply_to_tile(tile) -> void:
	var success := false
	var message := ""
	var harvested_value := 0
	var resource_gain: Dictionary = {}
	var crafted_cost: Dictionary = {}

	match current_tool:
		Tool.TILL:
			success = tile.till()
			message = "Soil tilled." if success else "That tile cannot be tilled."
			sound_requested.emit("till_soft" if success else "error_soft")
		Tool.PLANT:
			success = tile.plant_corn()
			message = "Corn planted." if success else "Till empty soil before planting corn."
			sound_requested.emit("plant_pop" if success else "error_soft")
		Tool.HARVEST:
			var value: int = tile.harvest()
			harvested_value = value
			success = value > 0
			if success:
				resource_gain["grain"] = 1
				harvest_collected.emit(value)
				message = "Harvested corn for %s coins." % value
				sound_requested.emit("harvest_chime")
				sound_requested.emit("coin_burst")
			else:
				message = "Corn must fully grow before harvest."
				sound_requested.emit("error_soft")
		Tool.ERASE:
			success = tile.erase()
			message = "Tile cleared." if success else "Nothing to erase here."
			sound_requested.emit("erase_puff" if success else "error_soft")
		Tool.PLACE:
			var result := _apply_selected_item(tile)
			success = bool(result.get("success", false))
			message = str(result.get("message", ""))
			harvested_value = int(result.get("value", 0))
			resource_gain = result.get("resources", {})
			crafted_cost = result.get("crafted_cost", {})
			for stamp in result.get("stamps", []):
				sound_requested.emit(stamp)
		Tool.SELECT:
			success = true
			message = _describe_tile(tile)
			sound_requested.emit("ui_click")
		_:
			pass

	if message != "":
		action_performed.emit(message)
		action_logged.emit({
			"actor": "player",
			"tool": _current_tool_name(),
			"action": _logged_action_name(),
			"grid_pos": tile.grid_pos,
			"item_id": selected_item_id,
			"success": success,
			"message": message,
			"value": harvested_value,
			"resources": resource_gain,
			"crafted_cost": crafted_cost
		})
	_update_preview_visibility()


func _setup_preview() -> void:
	if _preview != null or grid_manager == null:
		return

	_preview = Node3D.new()
	_preview.name = "PlacementPreview"
	_preview.set_script(PlacementPreviewScript)
	grid_manager.add_child(_preview)
	_preview.call("set_item", selected_item_id)
	_preview.call("hide_preview")


func _update_preview_visibility() -> void:
	if _preview == null:
		return

	if _hovered_tile == null:
		_preview.call("hide_preview")
		return

	if _is_targeting_crew_order():
		_preview.call("set_item", _crew_order_preview_item_id)
		_preview.call("show_preview", _hovered_tile.position, _can_target_crew_order(_hovered_tile))
		return

	if current_tool != Tool.PLACE:
		_preview.call("hide_preview")
		return

	var is_valid := false
	if _hovered_tile.has_method("can_apply_item"):
		is_valid = _hovered_tile.can_apply_item(selected_item_id) and _has_required_inventory(selected_item_id)
	_preview.call("set_item", selected_item_id)
	_preview.call("show_preview", _hovered_tile.position, is_valid)


func _is_targeting_crew_order() -> bool:
	return _crew_order_action_id != "" and _crew_order_preview_item_id != ""


func _can_target_crew_order(tile) -> bool:
	if tile == null:
		return false
	if not crew_order_target_checker.is_valid():
		return true
	return bool(crew_order_target_checker.call(_crew_order_action_id, tile.grid_pos))


func _apply_selected_item(tile) -> Dictionary:
	match selected_item_id:
		"pickaxe":
			var resource_gain: Dictionary = {}
			if str(tile.decor_id) == "rock":
				resource_gain["stone"] = 1
			elif str(tile.decor_id) in ["fence", "wooden_sign"] or str(tile.structure_id) != "":
				resource_gain["fiber"] = 1
			var success: bool = tile.break_with_pickaxe()
			return {
				"success": success,
				"message": "Pickaxe broke it down." if success else "Pickaxe needs rock, road, fence, sign, or structure.",
				"value": 0,
				"resources": resource_gain if success else {},
				"stamps": ["plant_pop"] if success else ["error_soft"]
			}
		"sickle":
			var resource_gain: Dictionary = {}
			if tile.crop != null and tile.crop.is_ready():
				resource_gain["grain"] = 1
			elif str(tile.decor_id) == "tall_grass":
				resource_gain["fiber"] = 2
			elif str(tile.decor_id) == "flower_patch":
				resource_gain["fiber"] = 1
			var value: int = tile.cut_with_sickle()
			var success: bool = value != 0
			if value > 0:
				harvest_collected.emit(value)
			return {
				"success": success,
				"message": ("Sickle harvested crop for %s coins." % value) if value > 0 else ("Sickle cut it clean." if success else "Sickle needs ready crops, flowers, or tall grass."),
				"value": max(value, 0),
				"resources": resource_gain if success else {},
				"stamps": ["harvest_chime", "coin_burst", "plant_pop"] if value > 0 else (["plant_pop"] if success else ["error_soft"])
			}
		_:
			if not _has_required_inventory(selected_item_id):
				return {
					"success": false,
					"message": _inventory_message(selected_item_id),
					"value": 0,
					"resources": {},
					"crafted_cost": {},
					"stamps": ["error_soft"]
				}
			var success: bool = tile.place_item(selected_item_id)
			var stamps := []
			if success:
				var primary_stamp := _stamp_for_placed_item(selected_item_id)
				stamps.append(primary_stamp)
				if primary_stamp != "plant_pop":
					stamps.append("plant_pop")
			else:
				stamps.append("error_soft")
			return {
				"success": success,
				"message": _item_message(selected_item_id, success),
				"value": 0,
				"resources": {},
				"crafted_cost": _crafted_cost_for_item(selected_item_id) if success else {},
				"stamps": stamps
			}


func _has_required_inventory(item_id: String) -> bool:
	if not item_availability_checker.is_valid():
		return true
	return bool(item_availability_checker.call(item_id))


func _crafted_cost_for_item(item_id: String) -> Dictionary:
	match item_id:
		"fence":
			return {"fence_kit": 1}
	return {}


func _inventory_message(item_id: String) -> String:
	match item_id:
		"fence":
			return "Craft a Fence Kit before placing fences."
	return "Craft the required kit first."


func _current_tool_name() -> String:
	match current_tool:
		Tool.PLACE:
			return "place"
		Tool.TILL:
			return "till"
		Tool.PLANT:
			return "plant"
		Tool.HARVEST:
			return "harvest"
		Tool.ERASE:
			return "erase"
		Tool.PAN:
			return "pan"
		Tool.SELECT:
			return "select"
	return "unknown"


func _logged_action_name() -> String:
	if current_tool == Tool.PLACE and selected_item_id in ["pickaxe", "sickle"]:
		return selected_item_id
	return _current_tool_name()


func _item_message(item_id: String, success: bool) -> String:
	if not success:
		match item_id:
			"corn_seed", "wheat_seed":
				return "Crops need an empty tilled tile."
			"barn":
				return "The barn needs a clear tile."
			"silo":
				return "The silo needs a clear tile."
			"well":
				return "The well needs a clear tile."
			"fence", "flower_patch", "tall_grass", "wooden_sign":
				return "Decor needs an empty tile."
			"rock":
				return "Rock needs an empty tile."
			"pickaxe":
				return "Pickaxe needs something breakable."
			"sickle":
				return "Sickle needs ready crops or brush."
			_:
				return "Cannot place that here."

	match item_id:
		"grass_block":
			return "Grass restored."
		"dirt_path", "dirt_road":
			return "Dirt road placed."
		"soil":
			return "Soil tilled."
		"corn_seed":
			return "Corn planted."
		"wheat_seed":
			return "Wheat planted."
		"fence":
			return "Fence placed."
		"flower_patch":
			return "Flower patch placed."
		"tall_grass":
			return "Tall grass placed."
		"wooden_sign":
			return "Wooden sign placed."
		"rock":
			return "Rock placed."
		"pickaxe":
			return "Pickaxe swung."
		"sickle":
			return "Sickle swept."
		"barn":
			return "Barn placed."
		"silo":
			return "Silo placed."
		"well":
			return "Well placed."
	return "Placed."


func _stamp_for_placed_item(item_id: String) -> String:
	match item_id:
		"soil":
			return "till_soft"
		"corn_seed", "wheat_seed":
			return "plant_pop"
		"grass_block", "dirt_path", "dirt_road", "fence", "flower_patch", "tall_grass", "wooden_sign", "rock", "barn", "silo", "well":
			return "place_soft"
		"pickaxe", "sickle":
			return "plant_pop"
	return "place_soft"


func _describe_tile(tile) -> String:
	if tile.crop:
		return "%s stage %s of 3." % [str(tile.crop.crop_id).capitalize(), tile.crop.stage]
	if tile.structure_id != "":
		return "Structure: %s." % tile.structure_id.capitalize()
	if tile.decor_id != "":
		return "Decor: %s." % tile.decor_id.capitalize()
	if tile.is_tilled:
		return "Empty tilled soil."
	return "A clean %s tile." % tile.terrain.replace("_", " ")
