extends Node

const GameEventLogScript: Script = preload("res://scripts/ai/GameEventLog.gd")
const AgentManagerScript: Script = preload("res://scripts/ai/AgentManager.gd")
const RECIPES: Dictionary = {
	"fence_kit": {
		"label": "Fence Kit",
		"cost": {
			"fiber": 2,
			"grain": 1
		}
	}
}
const WORK_ORDER_ACTIONS: Dictionary = {
	"build_fence": {
		"label": "Fence",
		"verb": "Build fence",
		"agent_action": "build_fence_order",
		"preview_item": "fence",
		"required_item": "fence_kit"
	},
	"clear_brush": {
		"label": "Clear",
		"verb": "Clear brush",
		"agent_action": "clear_brush",
		"preview_item": "sickle",
		"required_item": ""
	},
	"harvest_crop": {
		"label": "Harvest",
		"verb": "Harvest crop",
		"agent_action": "harvest_crop",
		"preview_item": "sickle",
		"required_item": ""
	}
}

@onready var camera_controller = $CameraController
@onready var farm_world: Node3D = $FarmWorld
@onready var grid_manager = $FarmWorld/GridManager
@onready var placement_tool = $PlacementTool
@onready var sound_manager = $SoundManager
@onready var game_ui = $GameUI

var money: int = 42
var resources: Dictionary = {
	"fiber": 0,
	"grain": 0,
	"stone": 0
}
var crafted_items: Dictionary = {
	"fence_kit": 0
}
var reserved_crafted_items: Dictionary = {
	"fence_kit": 0
}
var work_orders: Dictionary = {}
var work_order_ids: Array[String] = []

var _environment: Environment
var _sun: DirectionalLight3D
var _event_log
var _agent_manager
var _crew_priority_timer: float = 0.0
var _next_work_order_number: int = 1


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("#fbfaf3"))
	_setup_environment()
	_setup_ai_layer()
	_connect_systems()
	camera_controller.center_on_farm()
	game_ui.set_day(grid_manager.day)
	game_ui.set_money(money)
	_refresh_inventory_and_orders()


func _process(delta: float) -> void:
	_crew_priority_timer -= delta
	if _crew_priority_timer > 0.0:
		return
	_crew_priority_timer = 0.45
	_continue_resource_orders(true)


func _connect_systems() -> void:
	placement_tool.configure(grid_manager, camera_controller, game_ui)
	placement_tool.set_item_availability_checker(Callable(self, "_can_place_palette_item"))
	placement_tool.set_crew_order_target_checker(Callable(self, "_can_target_crew_order"))
	placement_tool.action_performed.connect(game_ui.show_message)
	placement_tool.harvest_collected.connect(_on_harvest_collected)
	placement_tool.sound_requested.connect(sound_manager.play_stamp)
	placement_tool.action_logged.connect(_on_player_action_logged)
	placement_tool.crew_order_targeted.connect(_on_crew_order_targeted)

	game_ui.tool_selected.connect(_on_tool_selected)
	game_ui.item_selected.connect(_on_palette_item_selected)
	game_ui.advance_day_requested.connect(_on_advance_day_requested)
	game_ui.grid_visibility_changed.connect(grid_manager.set_grid_visible)
	game_ui.shadows_changed.connect(_set_shadows_enabled)
	game_ui.ambient_occlusion_changed.connect(_set_ambient_occlusion_enabled)
	game_ui.sound_requested.connect(sound_manager.play_stamp)
	game_ui.craft_requested.connect(_on_craft_requested)
	game_ui.work_order_requested.connect(_on_work_order_requested)
	game_ui.work_order_cancel_requested.connect(_on_work_order_cancel_requested)
	game_ui.work_order_tool_selected.connect(_on_work_order_tool_selected)

	if _agent_manager:
		_agent_manager.agent_comment.connect(game_ui.show_message)
		_agent_manager.agent_comment.connect(game_ui.add_field_log)
		_agent_manager.agent_world_action.connect(_on_agent_world_action)
		_agent_manager.crew_updated.connect(game_ui.set_agent_snapshots)
		game_ui.set_agent_snapshots(_agent_manager.call("get_agent_snapshots"))


func _setup_environment() -> void:
	var world_environment := WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	_environment = Environment.new()
	_environment.background_mode = Environment.BG_COLOR
	_environment.background_color = Color("#fbfaf3")
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.ambient_light_color = Color("#fff0cf")
	_environment.ambient_light_energy = 0.86
	_environment.ssao_enabled = true
	_environment.ssao_radius = 1.65
	_environment.ssao_intensity = 0.92
	_apply_16gami_atmosphere()
	world_environment.environment = _environment
	add_child(world_environment)

	_sun = DirectionalLight3D.new()
	_sun.name = "WarmSun"
	_sun.light_color = Color("#fff1c6")
	_sun.light_energy = 2.15
	_sun.shadow_enabled = true
	_sun.position = Vector3(-4.5, 7.5, -5.0)
	add_child(_sun)
	_sun.look_at(Vector3.ZERO, Vector3.UP)

	var fill := OmniLight3D.new()
	fill.name = "SoftFill"
	fill.light_color = Color("#fff8e8")
	fill.light_energy = 0.18
	fill.omni_range = 12.0
	fill.position = Vector3(3.0, 5.0, 4.0)
	add_child(fill)

	_setup_haze_wash()


func _setup_ai_layer() -> void:
	_event_log = Node.new()
	_event_log.set_script(GameEventLogScript)
	_event_log.name = "GameEventLog"
	add_child(_event_log)

	_agent_manager = Node3D.new()
	_agent_manager.set_script(AgentManagerScript)
	_agent_manager.name = "AgentManager"
	_agent_manager.call("configure", grid_manager, _event_log)
	farm_world.add_child(_agent_manager)


func _apply_16gami_atmosphere() -> void:
	_set_environment_property("tonemap_mode", 2)
	_set_environment_property("tonemap_exposure", 1.02)
	_set_environment_property("tonemap_white", 1.25)
	_set_environment_property("glow_enabled", true)
	_set_environment_property("glow_normalized", true)
	_set_environment_property("glow_intensity", 0.18)
	_set_environment_property("glow_strength", 0.34)
	_set_environment_property("glow_bloom", 0.12)
	_set_environment_property("glow_blend_mode", 1)
	_set_environment_property("glow_hdr_threshold", 0.74)
	_set_environment_property("glow_hdr_scale", 1.20)
	_set_environment_property("glow_hdr_luminance_cap", 3.0)
	_set_environment_property("adjustment_enabled", true)
	_set_environment_property("adjustment_brightness", 1.02)
	_set_environment_property("adjustment_contrast", 0.96)
	_set_environment_property("adjustment_saturation", 1.06)
	_set_environment_property("fog_enabled", true)
	_set_environment_property("fog_light_color", Color("#fff2dc"))
	_set_environment_property("fog_light_energy", 0.26)
	_set_environment_property("fog_density", 0.004)
	_set_environment_property("fog_aerial_perspective", 0.22)
	_set_environment_property("fog_sun_scatter", 0.08)


func _setup_haze_wash() -> void:
	var layer := CanvasLayer.new()
	layer.name = "WorldHazeWash"
	layer.layer = 0
	add_child(layer)

	var wash := ColorRect.new()
	wash.name = "WarmAirTint"
	wash.anchor_right = 1.0
	wash.anchor_bottom = 1.0
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wash.color = Color(1.0, 0.91, 0.74, 0.032)
	layer.add_child(wash)


func _set_environment_property(property_name: StringName, value) -> void:
	for property in _environment.get_property_list():
		if property.name == property_name:
			_environment.set(property_name, value)
			return


func _on_tool_selected(tool_name: String) -> void:
	placement_tool.clear_crew_order_targeting()
	game_ui.set_selected_work_order_tool("")
	placement_tool.set_tool(tool_name)


func _on_palette_item_selected(item_id: String) -> void:
	placement_tool.clear_crew_order_targeting()
	game_ui.set_selected_work_order_tool("")
	placement_tool.set_selected_item(item_id)
	placement_tool.set_tool("place")


func _on_work_order_tool_selected(action_id: String) -> void:
	if action_id == "":
		placement_tool.clear_crew_order_targeting()
		game_ui.set_selected_work_order_tool("")
		game_ui.show_message("Crew order cleared.")
		sound_manager.play_stamp("ui_click")
		return

	if not WORK_ORDER_ACTIONS.has(action_id):
		game_ui.show_message("Unknown crew order.")
		sound_manager.play_stamp("error_soft")
		return

	var action: Dictionary = WORK_ORDER_ACTIONS[action_id]
	placement_tool.set_tool("select")
	placement_tool.set_crew_order_targeting(action_id, str(action.get("preview_item", "fence")))
	game_ui.set_selected_tool("select")
	game_ui.set_selected_work_order_tool(action_id)
	game_ui.show_message("%s: mark a farm tile." % str(action.get("verb", "Crew order")))
	sound_manager.play_stamp("tool_select")


func _on_crew_order_targeted(action_id: String, grid_pos: Vector2i) -> void:
	if not WORK_ORDER_ACTIONS.has(action_id):
		game_ui.show_message("Unknown crew order.")
		sound_manager.play_stamp("error_soft")
		return

	if not _can_target_crew_order(action_id, grid_pos):
		game_ui.show_message(_targeting_error_message(action_id))
		sound_manager.play_stamp("error_soft")
		return

	var order_id := _create_user_work_order(action_id, grid_pos)
	if order_id == "":
		return
	_on_work_order_requested(order_id)


func _create_user_work_order(action_id: String, grid_pos: Vector2i) -> String:
	var action: Dictionary = WORK_ORDER_ACTIONS[action_id]
	var order_id := "order_%03d" % _next_work_order_number
	_next_work_order_number += 1

	var order := {
		"id": order_id,
		"label": _work_order_label(action_id, grid_pos),
		"status": "ready",
		"action": action_id,
		"agent_action": str(action.get("agent_action", "")),
		"target_tile": grid_pos,
		"required_item": str(action.get("required_item", "")),
		"created_day": grid_manager.day
	}
	work_orders[order_id] = order
	work_order_ids.append(order_id)
	_refresh_work_orders()
	game_ui.add_field_log("Marked order: %s." % str(order.get("label", "Crew task")))
	_record_work_order_event(order_id, "ready")
	return order_id


func _work_order_label(action_id: String, grid_pos: Vector2i) -> String:
	var action: Dictionary = WORK_ORDER_ACTIONS.get(action_id, {})
	return "%s %s,%s" % [str(action.get("label", "Order")), grid_pos.x, grid_pos.y]


func _on_advance_day_requested() -> void:
	sound_manager.play_stamp("day_advance")
	var ending_day: int = grid_manager.day
	if _event_log:
		var summary: Dictionary = _event_log.build_day_summary(ending_day)
		_event_log.record_event("day_summary", {
			"day": ending_day,
			"summary": summary
		})
		game_ui.add_field_log(_format_day_summary(summary))

	grid_manager.advance_day()
	game_ui.set_day(grid_manager.day)
	if _event_log:
		_event_log.record_event("day_advanced", {
			"day": grid_manager.day,
			"previous_day": ending_day
		})
	game_ui.show_message("A warm morning rolls in. Crops advanced one stage.")


func _on_harvest_collected(amount: int) -> void:
	money += amount
	game_ui.set_money(money)


func _on_player_action_logged(event: Dictionary) -> void:
	if _event_log == null:
		return

	var payload := event.duplicate(true)
	payload["day"] = grid_manager.day
	if bool(payload.get("success", false)):
		_consume_crafted_cost(payload.get("crafted_cost", {}))
	_add_resources(payload.get("resources", {}))
	_event_log.record_event("player_action", payload)
	game_ui.add_field_log(_format_player_receipt(payload))


func _on_agent_world_action(event: Dictionary) -> void:
	var payload := event.duplicate(true)
	payload["day"] = grid_manager.day

	if _event_log:
		_event_log.record_event("agent_world_action", payload)

	var value := int(payload.get("value", 0))
	if value > 0:
		money += value
		game_ui.set_money(money)
	if bool(payload.get("success", false)):
		_consume_crafted_cost(payload.get("crafted_cost", {}))
	_add_resources(payload.get("resources", {}))
	_update_work_order_from_agent_action(payload)
	_continue_resource_orders()

	for stamp in payload.get("stamps", []):
		sound_manager.play_stamp(str(stamp))

	var receipt := _format_agent_receipt(payload)
	if receipt != "":
		game_ui.add_field_log(receipt)
		if bool(payload.get("success", false)):
			game_ui.show_message(receipt)


func _on_craft_requested(recipe_id: String) -> void:
	_craft_recipe(recipe_id, "player")


func _on_work_order_requested(order_id: String) -> void:
	if not work_orders.has(order_id):
		game_ui.show_message("Unknown work order.")
		sound_manager.play_stamp("error_soft")
		return

	var order: Dictionary = work_orders[order_id]
	var status := str(order.get("status", "ready"))
	if status == "done":
		game_ui.show_message("%s is already complete." % str(order.get("label", "Work order")))
		sound_manager.play_stamp("ui_click")
		return
	if status in ["queued", "gathering"]:
		game_ui.show_message("%s is already assigned." % str(order.get("label", "Work order")))
		sound_manager.play_stamp("ui_click")
		return

	if not _can_order_target(order):
		game_ui.show_message(_targeting_error_message(str(order.get("action", "build_fence"))))
		sound_manager.play_stamp("error_soft")
		return

	var action_id := str(order.get("action", "build_fence"))
	if action_id != "build_fence":
		_queue_directive_order(order_id)
		return

	if _has_required_item_for_order(order):
		_queue_build_order(order_id)
		return

	if _can_craft_required_item_for_order(order):
		if _craft_recipe(str(order.get("required_item", "")), "crew"):
			_queue_build_order(order_id)
		return

	_queue_supply_for_order(order_id)


func _on_work_order_cancel_requested(order_id: String) -> void:
	if not work_orders.has(order_id):
		game_ui.show_message("Unknown work order.")
		sound_manager.play_stamp("error_soft")
		return

	var order: Dictionary = work_orders[order_id]
	var status := str(order.get("status", "ready"))
	if status in ["queued", "gathering"]:
		game_ui.show_message("%s is already with the crew." % str(order.get("label", "Work order")))
		sound_manager.play_stamp("error_soft")
		return

	_release_order_reservation(order)
	work_orders.erase(order_id)
	work_order_ids.erase(order_id)
	_refresh_inventory_and_orders()

	var label := str(order.get("label", "Work order"))
	if status == "done":
		game_ui.show_message("Cleared order: %s." % label)
		game_ui.add_field_log("Cleared completed order: %s." % label)
		_record_removed_work_order_event(order, "cleared")
	else:
		game_ui.show_message("Dropped order: %s." % label)
		game_ui.add_field_log("Dropped order: %s." % label)
		_record_removed_work_order_event(order, "dropped")
	sound_manager.play_stamp("erase_puff")


func _craft_recipe(recipe_id: String, source: String = "player") -> bool:
	if not RECIPES.has(recipe_id):
		game_ui.show_message("Unknown recipe.")
		sound_manager.play_stamp("error_soft")
		return false

	var recipe: Dictionary = RECIPES[recipe_id]
	var cost: Dictionary = recipe.get("cost", {})
	var label := str(recipe.get("label", recipe_id.replace("_", " ").capitalize()))

	if not _can_afford(cost):
		game_ui.show_message("%s needs %s." % [label, _format_cost(cost)])
		sound_manager.play_stamp("error_soft")
		return false

	for resource_id in cost.keys():
		resources[resource_id] = int(resources.get(resource_id, 0)) - int(cost[resource_id])
	crafted_items[recipe_id] = int(crafted_items.get(recipe_id, 0)) + 1
	_refresh_inventory_and_orders()

	var payload := {
		"day": grid_manager.day,
		"recipe_id": recipe_id,
		"label": label,
		"cost": cost.duplicate(true),
		"inventory": crafted_items.duplicate(true),
		"source": source
	}
	if _event_log:
		_event_log.record_event("craft_action", payload)

	var receipt := "Crafted %s from %s." % [label, _format_cost(cost)]
	if source.begins_with("crew"):
		receipt = "Crew prepped %s from %s." % [label, _format_cost(cost)]
	game_ui.add_field_log(receipt)
	if not source.ends_with("_quiet"):
		game_ui.show_message(receipt)
		sound_manager.play_stamp("place_soft")
		sound_manager.play_stamp("plant_pop")
	return true


func _queue_build_order(order_id: String, quiet: bool = false) -> bool:
	var order: Dictionary = work_orders[order_id]
	if _agent_manager == null or not bool(_agent_manager.call("has_available_agent")):
		if not quiet:
			game_ui.show_message("Crew is busy; order is waiting.")
			sound_manager.play_stamp("ui_click")
		_mark_order_waiting(order_id)
		return false

	var target_tile: Vector2i = order.get("target_tile", Vector2i.ZERO)
	if not _reserve_required_item_for_order(order):
		if not quiet:
			game_ui.show_message("%s needs a Fence Kit." % str(order.get("label", "Work order")))
			sound_manager.play_stamp("error_soft")
		return false

	order["status"] = "queued"
	work_orders[order_id] = order
	_refresh_work_orders()
	if not quiet:
		game_ui.show_message("Crew assigned: %s." % str(order.get("label", "Work order")))
		sound_manager.play_stamp("tool_select")
	game_ui.add_field_log("Work order queued: %s." % str(order.get("label", "Crew task")))
	_record_work_order_event(order_id, "queued")

	var assigned := bool(_agent_manager.call("assign_work_order", order.duplicate(true)))
	if not assigned:
		_release_order_reservation(order)
		_mark_order_waiting(order_id)
	return assigned


func _queue_directive_order(order_id: String, quiet: bool = false) -> bool:
	var order: Dictionary = work_orders[order_id]
	if _agent_manager == null or not bool(_agent_manager.call("has_available_agent")):
		if not quiet:
			game_ui.show_message("Crew is busy; order is waiting.")
			sound_manager.play_stamp("ui_click")
		_mark_order_waiting(order_id)
		return false

	var target_tile: Vector2i = order.get("target_tile", Vector2i.ZERO)
	var agent_action := str(order.get("agent_action", ""))
	if agent_action == "":
		if not quiet:
			game_ui.show_message("That order has no crew action.")
			sound_manager.play_stamp("error_soft")
		return false

	order["status"] = "queued"
	work_orders[order_id] = order
	_refresh_work_orders()
	if not quiet:
		game_ui.show_message("Crew assigned: %s." % str(order.get("label", "Work order")))
		sound_manager.play_stamp("tool_select")
	game_ui.add_field_log("Work order queued: %s." % str(order.get("label", "Crew task")))
	_record_work_order_event(order_id, "queued")

	var assigned := bool(_agent_manager.call("assign_directive", agent_action, target_tile, "work order: %s" % str(order.get("label", "crew task")), {
		"work_order_id": order_id
	}))
	if not assigned:
		_mark_order_waiting(order_id)
	return assigned


func _queue_supply_for_order(order_id: String, quiet: bool = false) -> bool:
	var order: Dictionary = work_orders[order_id]
	if _agent_manager == null or not bool(_agent_manager.call("has_available_agent")):
		if not quiet:
			game_ui.show_message("Crew is busy; order is waiting.")
			sound_manager.play_stamp("ui_click")
		_mark_order_waiting(order_id)
		return false

	var required_item := str(order.get("required_item", ""))
	var recipe: Dictionary = RECIPES.get(required_item, {})
	var missing := _missing_resources(recipe.get("cost", {}))
	var supply_action := ""
	var supply_target := Vector2i.ZERO
	var supply_label := ""

	if int(missing.get("fiber", 0)) > 0:
		supply_target = _nearest_supply_tile("fiber")
		supply_action = "clear_brush"
		supply_label = "fiber"
	elif int(missing.get("grain", 0)) > 0:
		supply_target = _nearest_supply_tile("grain")
		supply_action = "harvest_crop"
		supply_label = "grain"

	if supply_action == "" or grid_manager.get_tile(supply_target) == null:
		if not quiet:
			game_ui.show_message("Crew needs %s, but no source is ready." % _format_resource_list(missing))
			sound_manager.play_stamp("error_soft")
		return false
	
	order["status"] = "gathering"
	order["status_text"] = "Gathering %s" % supply_label.capitalize()
	work_orders[order_id] = order
	_refresh_work_orders()
	game_ui.add_field_log("Crew gathering %s for %s." % [supply_label, str(order.get("label", "work order"))])
	if not quiet:
		game_ui.show_message("Crew gathering %s." % supply_label)
		sound_manager.play_stamp("tool_select")
	_record_work_order_event(order_id, "gathering")

	var assigned := bool(_agent_manager.call("assign_directive", supply_action, supply_target, "gather %s for %s" % [supply_label, str(order.get("label", "work order"))], {
		"work_order_id": order_id
	}))
	if not assigned:
		_mark_order_waiting(order_id)
	return assigned


func _continue_resource_orders(quiet: bool = false) -> void:
	if _agent_manager == null or not bool(_agent_manager.call("has_available_agent")):
		return

	for order_id in work_order_ids:
		var order: Dictionary = work_orders.get(order_id, {})
		var status := str(order.get("status", ""))
		if status not in ["waiting", "gathering"]:
			continue
		if not _can_order_target(order):
			order["status"] = "ready"
			order["status_text"] = "Target changed"
			work_orders[order_id] = order
			_refresh_work_orders()
			continue

		if str(order.get("action", "build_fence")) != "build_fence":
			_queue_directive_order(order_id, quiet)
			continue

		if _has_required_item_for_order(order):
			_queue_build_order(order_id, quiet)
		elif _can_craft_required_item_for_order(order):
			if _craft_recipe(str(order.get("required_item", "")), "crew" if not quiet else "crew_quiet"):
				_queue_build_order(order_id, quiet)
		else:
			_queue_supply_for_order(order_id, quiet)


func _add_resources(gains) -> Dictionary:
	if typeof(gains) != TYPE_DICTIONARY:
		return {}

	var accepted: Dictionary = {}
	for resource_id in gains.keys():
		var amount := int(gains[resource_id])
		if amount <= 0:
			continue
		resources[resource_id] = int(resources.get(resource_id, 0)) + amount
		accepted[resource_id] = amount

	if not accepted.is_empty():
		_refresh_inventory_and_orders()
	return accepted


func _consume_crafted_cost(cost) -> Dictionary:
	if typeof(cost) != TYPE_DICTIONARY:
		return {}

	var consumed: Dictionary = {}
	for item_id in cost.keys():
		var amount := int(cost[item_id])
		if amount <= 0:
			continue
		var available := int(crafted_items.get(item_id, 0))
		var applied := mini(available, amount)
		if applied <= 0:
			continue
		crafted_items[item_id] = available - applied
		reserved_crafted_items[item_id] = maxi(0, int(reserved_crafted_items.get(item_id, 0)) - applied)
		consumed[item_id] = applied

	if not consumed.is_empty():
		_refresh_inventory_and_orders()
	return consumed


func _refresh_inventory_and_orders() -> void:
	game_ui.set_inventory(resources, _available_crafted_items_snapshot())
	_refresh_work_orders()


func _refresh_work_orders() -> void:
	_refresh_order_markers()
	game_ui.set_work_orders(_work_order_snapshots())


func _refresh_order_markers() -> void:
	if grid_manager == null:
		return

	for tile in grid_manager.tiles.values():
		if tile.has_method("set_order_marker"):
			tile.set_order_marker({})

	for order_id in work_order_ids:
		if not work_orders.has(order_id):
			continue
		var order := _work_order_snapshot(order_id)
		if order.is_empty() or str(order.get("status", "")) == "done":
			continue
		var target_tile: Vector2i = order.get("target_tile", Vector2i.ZERO)
		var tile = grid_manager.get_tile(target_tile)
		if tile != null and tile.has_method("set_order_marker"):
			tile.set_order_marker(order)


func _can_place_palette_item(item_id: String) -> bool:
	match item_id:
		"fence":
			return _available_crafted_item("fence_kit") > 0
	return true


func _available_crafted_items_snapshot() -> Dictionary:
	var snapshot: Dictionary = {}
	for item_id in crafted_items.keys():
		snapshot[item_id] = _available_crafted_item(str(item_id))
	return snapshot


func _available_crafted_item(item_id: String) -> int:
	return maxi(0, int(crafted_items.get(item_id, 0)) - int(reserved_crafted_items.get(item_id, 0)))


func _mark_order_waiting(order_id: String) -> void:
	if not work_orders.has(order_id):
		return
	var order: Dictionary = work_orders[order_id]
	if str(order.get("status", "")) == "done":
		return
	order["status"] = "waiting"
	order["status_text"] = "Waiting crew"
	work_orders[order_id] = order
	_refresh_work_orders()


func _reserve_required_item_for_order(order: Dictionary) -> bool:
	var required_item := str(order.get("required_item", ""))
	if required_item == "":
		return true
	if str(order.get("reserved_item", "")) == required_item:
		return true
	if _available_crafted_item(required_item) <= 0:
		return false

	reserved_crafted_items[required_item] = int(reserved_crafted_items.get(required_item, 0)) + 1
	order["reserved_item"] = required_item
	_refresh_inventory_and_orders()
	return true


func _release_order_reservation(order: Dictionary) -> void:
	var reserved_item := str(order.get("reserved_item", ""))
	if reserved_item == "":
		return
	reserved_crafted_items[reserved_item] = maxi(0, int(reserved_crafted_items.get(reserved_item, 0)) - 1)
	order.erase("reserved_item")
	if work_orders.has(str(order.get("id", ""))):
		work_orders[str(order.get("id", ""))] = order
	_refresh_inventory_and_orders()


func _can_afford(cost: Dictionary) -> bool:
	for resource_id in cost.keys():
		if int(resources.get(resource_id, 0)) < int(cost[resource_id]):
			return false
	return true


func _has_required_item_for_order(order: Dictionary) -> bool:
	var required_item := str(order.get("required_item", ""))
	if required_item == "":
		return true
	if str(order.get("reserved_item", "")) == required_item:
		return true
	return _available_crafted_item(required_item) > 0


func _can_craft_required_item_for_order(order: Dictionary) -> bool:
	var required_item := str(order.get("required_item", ""))
	if not RECIPES.has(required_item):
		return false
	return _can_afford(RECIPES[required_item].get("cost", {}))


func _can_build_order_target(order: Dictionary) -> bool:
	var target_tile: Vector2i = order.get("target_tile", Vector2i.ZERO)
	var tile = grid_manager.get_tile(target_tile)
	return tile != null and tile.can_apply_item("fence")


func _can_order_target(order: Dictionary) -> bool:
	return _can_target_crew_order(str(order.get("action", "build_fence")), order.get("target_tile", Vector2i.ZERO))


func _can_target_crew_order(action_id: String, grid_pos: Vector2i) -> bool:
	var tile = grid_manager.get_tile(grid_pos)
	if tile == null:
		return false

	match action_id:
		"build_fence":
			return tile.can_apply_item("fence")
		"clear_brush":
			return str(tile.decor_id) in ["tall_grass", "flower_patch"]
		"harvest_crop":
			return tile.crop != null and tile.crop.is_ready()
	return false


func _targeting_error_message(action_id: String) -> String:
	match action_id:
		"build_fence":
			return "Fence orders need an open tile."
		"clear_brush":
			return "Clear orders need flowers or tall grass."
		"harvest_crop":
			return "Harvest orders need a ready crop."
	return "That tile cannot take this order."


func _missing_resources(cost: Dictionary) -> Dictionary:
	var missing: Dictionary = {}
	for resource_id in cost.keys():
		var needed := int(cost[resource_id]) - int(resources.get(resource_id, 0))
		if needed > 0:
			missing[resource_id] = needed
	return missing


func _nearest_supply_tile(resource_id: String) -> Vector2i:
	var candidates: Array[Vector2i] = []
	for tile in grid_manager.tiles.values():
		match resource_id:
			"fiber":
				if str(tile.decor_id) in ["tall_grass", "flower_patch"]:
					candidates.append(tile.grid_pos)
			"grain":
				if tile.crop != null and tile.crop.is_ready():
					candidates.append(tile.grid_pos)

	if candidates.is_empty():
		return Vector2i(-1, -1)

	var origin := Vector2i(grid_manager.width / 2, grid_manager.height / 2)
	var best := candidates[0]
	var best_distance := origin.distance_squared_to(best)
	for candidate in candidates:
		var distance := origin.distance_squared_to(candidate)
		if distance < best_distance:
			best = candidate
			best_distance = distance
	return best


func _update_work_order_from_agent_action(event: Dictionary) -> void:
	var order_id := str(event.get("work_order_id", ""))
	if order_id == "" or not work_orders.has(order_id):
		return

	var order: Dictionary = work_orders[order_id]
	var action_id := str(order.get("action", "build_fence"))
	var completed_action := str(event.get("action", ""))
	var expected_action := str(order.get("agent_action", "build_fence_order"))
	if completed_action != expected_action:
		return

	var success := bool(event.get("success", false))
	if success:
		order.erase("reserved_item")
	else:
		_release_order_reservation(order)
	order["status"] = "done" if success else "ready"
	order.erase("status_text")
	work_orders[order_id] = order
	_refresh_work_orders()

	_record_work_order_event(order_id, str(order.get("status", "ready")))


func _record_work_order_event(order_id: String, status: String) -> void:
	if _event_log == null or not work_orders.has(order_id):
		return

	var order: Dictionary = work_orders[order_id]
	_event_log.record_event("work_order", {
		"day": grid_manager.day,
		"order_id": order_id,
		"label": str(order.get("label", "")),
		"status": status,
		"target_tile": order.get("target_tile", Vector2i.ZERO)
	})


func _record_removed_work_order_event(order: Dictionary, status: String) -> void:
	if _event_log == null:
		return

	_event_log.record_event("work_order", {
		"day": grid_manager.day,
		"order_id": str(order.get("id", "")),
		"label": str(order.get("label", "")),
		"status": status,
		"target_tile": order.get("target_tile", Vector2i.ZERO)
	})


func _work_order_snapshot(order_id: String) -> Dictionary:
	if not work_orders.has(order_id):
		return {}

	var order: Dictionary = work_orders[order_id].duplicate(true)
	var required_item := str(order.get("required_item", ""))
	var action_id := str(order.get("action", "build_fence"))
	order["has_required_item"] = required_item == "" or str(order.get("reserved_item", "")) == required_item or _available_crafted_item(required_item) > 0
	order["can_craft_item"] = _can_craft_required_item_for_order(order)
	order["can_progress"] = str(order.get("status", "ready")) == "ready" and _can_order_target(order)
	if str(order.get("status", "ready")) == "ready" and not bool(order["can_progress"]):
		order["status_text"] = "Target changed"
	elif str(order.get("status", "ready")) == "ready" and action_id == "build_fence" and not bool(order["has_required_item"]) and not bool(order["can_craft_item"]):
		var recipe: Dictionary = RECIPES.get(required_item, {})
		var missing := _missing_resources(recipe.get("cost", {}))
		if not missing.is_empty():
			order["status_text"] = "Needs %s" % _format_resource_list(missing)
	elif str(order.get("status", "ready")) == "ready" and action_id != "build_fence":
		order["status_text"] = "Ready"
	return order


func _work_order_snapshots() -> Array:
	var snapshots: Array = []
	var visible_ids := work_order_ids.duplicate()
	visible_ids.reverse()
	for order_id in visible_ids.slice(0, 3):
		snapshots.append(_work_order_snapshot(order_id))
	return snapshots


func _format_player_receipt(event: Dictionary) -> String:
	var action := str(event.get("action", "work"))
	var item_id := str(event.get("item_id", ""))
	var grid_pos: Vector2i = event.get("grid_pos", Vector2i.ZERO)
	var success := bool(event.get("success", false))

	var target := "(%s,%s)" % [grid_pos.x, grid_pos.y]
	if not success:
		return "Missed %s at %s: %s" % [action, target, str(event.get("message", "blocked"))]

	match action:
		"place":
			return "Placed %s at %s.%s%s" % [_pretty_item_name(item_id), target, _format_resource_suffix(event.get("resources", {})), _format_crafted_cost_suffix(event.get("crafted_cost", {}))]
		"pickaxe":
			return "Swung pickaxe at %s.%s" % [target, _format_resource_suffix(event.get("resources", {}))]
		"sickle":
			return "Cut or harvested at %s.%s" % [target, _format_resource_suffix(event.get("resources", {}))]
		"till":
			return "Tilled soil at %s." % target
		"plant":
			return "Planted corn at %s." % target
		"harvest":
			return "Harvested %s coins at %s.%s" % [int(event.get("value", 0)), target, _format_resource_suffix(event.get("resources", {}))]
		"erase":
			return "Cleared tile at %s." % target
	return "%s succeeded at %s." % [action.capitalize(), target]


func _format_day_summary(summary: Dictionary) -> String:
	var total := int(summary.get("total_player_actions", 0))
	var failed := int(summary.get("failed_player_actions", 0))
	var harvest_value := int(summary.get("harvest_value", 0))
	var agent_harvest_value := int(summary.get("agent_harvest_value", 0))
	var resources_gained: Dictionary = summary.get("resources_gained", {})
	var top_action := str(summary.get("top_action", "none"))
	var vibe: Dictionary = summary.get("vibe", {})
	var vibe_label := str(vibe.get("label", "mixed"))
	var vibe_score := int(vibe.get("score", 50))

	if total == 0:
		return "Day %s: neglectful, no farm work logged." % int(summary.get("day", 1))

	var line := "Day %s: %s vibe (%s), %s actions, %s missed" % [int(summary.get("day", 1)), vibe_label, vibe_score, total, failed]
	if harvest_value > 0:
		line += ", %s coins harvested" % harvest_value
	if agent_harvest_value > 0:
		line += ", crew added %s" % agent_harvest_value
	if not resources_gained.is_empty():
		line += ", gathered %s" % _format_resource_list(resources_gained)
	if top_action != "none":
		line += ", mostly %s" % top_action
	return line + "."


func _format_agent_receipt(event: Dictionary) -> String:
	var action := str(event.get("action", "work"))
	var name := str(event.get("agent_name", "Crew"))
	var grid_pos: Vector2i = event.get("grid_pos", Vector2i.ZERO)
	var target := "(%s,%s)" % [grid_pos.x, grid_pos.y]
	var success := bool(event.get("success", false))
	var subject := str(event.get("subject", "tile"))

	if not success:
		return "%s missed %s at %s." % [name, action.replace("_", " "), target]

	match action:
		"build_fence_order":
			return "%s built fence at %s.%s" % [name, target, _format_crafted_cost_suffix(event.get("crafted_cost", {}))]
		"harvest_crop":
			return "%s harvested %s coins at %s.%s" % [name, int(event.get("value", 0)), target, _format_resource_suffix(event.get("resources", {}))]
		"clear_brush":
			return "%s cleared %s at %s.%s" % [name, subject, target, _format_resource_suffix(event.get("resources", {}))]
		"inspect_structure":
			return "%s inspected %s at %s." % [name, subject, target]
		"inspect_ready_crop":
			return "%s checked %s at %s." % [name, subject, target]
		"inspect_soil":
			return "%s checked open soil at %s." % [name, target]
	return "%s completed %s at %s." % [name, action.replace("_", " "), target]


func _format_resource_suffix(gains) -> String:
	var text := _format_resource_list(gains)
	if text == "":
		return ""
	return " +%s" % text


func _format_crafted_cost_suffix(cost) -> String:
	var text := _format_crafted_cost_list(cost)
	if text == "":
		return ""
	return " -%s" % text


func _format_resource_list(gains) -> String:
	if typeof(gains) != TYPE_DICTIONARY:
		return ""

	var parts: Array[String] = []
	for resource_id in ["fiber", "grain", "stone"]:
		var amount := int(gains.get(resource_id, 0))
		if amount > 0:
			parts.append("%s %s" % [amount, _pretty_resource_name(resource_id)])
	return ", ".join(parts)


func _format_crafted_cost_list(cost) -> String:
	if typeof(cost) != TYPE_DICTIONARY:
		return ""

	var parts: Array[String] = []
	for item_id in ["fence_kit"]:
		var amount := int(cost.get(item_id, 0))
		if amount > 0:
			parts.append("%s %s" % [amount, _pretty_crafted_name(item_id)])
	return ", ".join(parts)


func _format_cost(cost: Dictionary) -> String:
	return _format_resource_list(cost)


func _pretty_resource_name(resource_id: String) -> String:
	match resource_id:
		"fiber":
			return "Fiber"
		"grain":
			return "Grain"
		"stone":
			return "Stone"
	return resource_id.capitalize()


func _pretty_crafted_name(item_id: String) -> String:
	match item_id:
		"fence_kit":
			return "Fence Kit"
	return item_id.replace("_", " ").capitalize()


func _pretty_item_name(item_id: String) -> String:
	return item_id.replace("_", " ")


func _set_shadows_enabled(is_enabled: bool) -> void:
	if _sun:
		_sun.shadow_enabled = is_enabled
	game_ui.show_message("Soft shadows on." if is_enabled else "Soft shadows off.")


func _set_ambient_occlusion_enabled(is_enabled: bool) -> void:
	if _environment:
		_environment.ssao_enabled = is_enabled
	game_ui.show_message("Ambient occlusion on." if is_enabled else "Ambient occlusion off.")
