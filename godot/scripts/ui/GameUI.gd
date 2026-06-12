class_name GameUI
extends CanvasLayer

signal tool_selected(tool_name: String)
signal item_selected(item_id: String)
signal advance_day_requested
signal grid_visibility_changed(is_visible: bool)
signal shadows_changed(is_enabled: bool)
signal ambient_occlusion_changed(is_enabled: bool)
signal sound_requested(stamp_name: String)
signal craft_requested(recipe_id: String)
signal work_order_requested(order_id: String)
signal work_order_cancel_requested(order_id: String)
signal work_order_tool_selected(action_id: String)
signal adversarial_encounter_requested(agent_id: String)
signal adversarial_response_selected(choice_id: String)
signal crafting_demand_target_requested(demand_id: String)
signal crafting_demand_requested(demand_id: String)
signal skill_forge_run_requested(template_id: String)
signal skill_forge_review_requested(template_id: String)
signal skill_forge_revision_requested(template_id: String)

const BuildPaletteScene := preload("res://scenes/ui/BuildPalette.tscn")

var _root: Control
var _tool_buttons: Dictionary = {}
var _active_tool: String = "till"
var _day_label: Label
var _money_label: Label
var _toast_label: Label
var _toast_tween: Tween
var _palette
var _crew_rows: Dictionary = {}
var _field_log_stack: VBoxContainer
var _field_log_entries: Array[String] = []
var _cursor_ghost: PanelContainer
var _cursor_ghost_label: Label
var _cursor_item_id: String = ""
var _resource_labels: Dictionary = {}
var _crafted_labels: Dictionary = {}
var _craft_buttons: Dictionary = {}
var _crafting_demand_rows: Dictionary = {}
var _crafting_demand_list_stack: VBoxContainer
var _crew_mission_rows: Dictionary = {}
var _crew_mission_list_stack: VBoxContainer
var _crew_pending_demand_details: Dictionary = {}
var _crew_pending_demand_labels: Dictionary = {}
var _crew_pending_demand_order_ids: Dictionary = {}
var _crew_pending_demand_signal_states: Dictionary = {}
var _crew_pending_demand_target_ids: Dictionary = {}
var _crew_snapshots_by_id: Dictionary = {}
var _work_order_rows: Dictionary = {}
var _work_order_action_buttons: Dictionary = {}
var _work_order_list_stack: VBoxContainer
var _active_work_order_tool: String = ""
var _skill_forge_template_buttons: Dictionary = {}
var _skill_forge_template_previews: Dictionary = {}
var _skill_forge_template_ids: Array[String] = []
var _skill_forge_template_button_row: HBoxContainer
var _active_skill_forge_template_id: String = ""
var _skill_forge_summary_label: Label
var _skill_forge_lesson_label: Label
var _skill_forge_meta_label: Label
var _skill_forge_trace_label: Label
var _skill_forge_route_label: Label
var _skill_forge_ref_label: Label
var _skill_forge_detail_label: Label
var _skill_forge_stage_label: Label
var _skill_forge_next_label: Label
var _skill_forge_receipt_label: Label
var _skill_forge_drift_label: Label
var _skill_forge_history_label: Label
var _skill_forge_result_label: Label
var _skill_forge_run_button: Button
var _skill_forge_review_button: Button
var _skill_forge_revision_button: Button
var _skill_forge_last_blocked_template_id: String = ""
var _skill_forge_history_entries: Array[String] = []
var _crew_status_label: Label
var _parley_button: Button
var _parley_prompt_active: bool = false
var _parley_pulse_phase: float = 0.0
var _encounter_panel: PanelContainer
var _encounter_title_label: Label
var _encounter_meter: ProgressBar
var _encounter_goal_label: Label
var _encounter_line_label: Label
var _encounter_choice_buttons: Array[Button] = []
var _encounter_choices: Array = []
var _ui_hit_regions: Array[Control] = []


func _ready() -> void:
	_build_ui()
	set_selected_tool("till")
	show_message("Till soil, plant corn, grow it, then harvest.")


func _process(delta: float) -> void:
	_update_parley_pulse(delta)
	if _cursor_ghost == null or not _cursor_ghost.visible:
		return

	_cursor_ghost.position = _root.get_local_mouse_position() + Vector2(18, 18)


func is_pointer_over_ui(mouse_position: Vector2 = Vector2(-1.0, -1.0)) -> bool:
	if mouse_position.x >= 0.0 and mouse_position.y >= 0.0:
		for region in _ui_hit_regions:
			if region != null and region.visible and region.get_global_rect().has_point(mouse_position):
				return true
		return false

	var hovered := get_viewport().gui_get_hovered_control()
	return hovered != null and hovered != _root


func set_selected_tool(tool_name: String) -> void:
	_active_tool = tool_name
	for key in _tool_buttons.keys():
		var button := _tool_buttons[key] as Button
		var active: bool = str(key) == _active_tool
		button.add_theme_color_override("font_color", Color("#2d3b1d") if active else Color("#4b4337"))
		button.add_theme_stylebox_override("normal", _tool_button_style(active))
		button.add_theme_stylebox_override("hover", _tool_button_style(true))
		button.add_theme_stylebox_override("pressed", _tool_button_style(true))


func set_selected_work_order_tool(action_id: String) -> void:
	_active_work_order_tool = action_id
	for key in _work_order_action_buttons.keys():
		var button := _work_order_action_buttons[key] as Button
		var active: bool = str(key) == _active_work_order_tool
		button.add_theme_stylebox_override("normal", _crew_order_button_style(active))
		button.add_theme_stylebox_override("hover", _crew_order_button_style(true))
		button.add_theme_stylebox_override("pressed", _crew_order_button_style(true))
		button.add_theme_color_override("font_color", Color("#23331a") if active else Color("#4b4337"))

	if action_id != "":
		_set_cursor_item("order_%s" % action_id)
	elif _cursor_item_id.begins_with("order_"):
		_set_cursor_item("")


func set_day(day: int) -> void:
	if _day_label:
		_day_label.text = "DAY %s / 10:00 AM" % day


func set_money(amount: int) -> void:
	if _money_label:
		_money_label.text = "%s COINS" % amount


func set_inventory(resources: Dictionary, crafted_items: Dictionary) -> void:
	if _resource_labels.has("fiber"):
		(_resource_labels["fiber"] as Label).text = "FBR %s" % int(resources.get("fiber", 0))
	if _resource_labels.has("grain"):
		(_resource_labels["grain"] as Label).text = "GRN %s" % int(resources.get("grain", 0))
	if _resource_labels.has("stone"):
		(_resource_labels["stone"] as Label).text = "STN %s" % int(resources.get("stone", 0))
	if _crafted_labels.has("fence_kit"):
		(_crafted_labels["fence_kit"] as Label).text = "KIT %s" % int(crafted_items.get("fence_kit", 0))
	if _crafted_labels.has("seed_bundle"):
		(_crafted_labels["seed_bundle"] as Label).text = "SBD %s" % int(crafted_items.get("seed_bundle", 0))
	if _crafted_labels.has("rush_kit"):
		(_crafted_labels["rush_kit"] as Label).text = "RSH %s" % int(crafted_items.get("rush_kit", 0))

	_set_craft_button_state("fence_kit", int(resources.get("fiber", 0)) >= 2 and int(resources.get("grain", 0)) >= 1)
	_set_craft_button_state("seed_bundle", int(resources.get("grain", 0)) >= 2)
	_set_craft_button_state("rush_kit", int(resources.get("fiber", 0)) >= 1 and int(resources.get("stone", 0)) >= 1)


func set_skill_forge_templates(previews: Array) -> void:
	_skill_forge_template_previews.clear()
	_skill_forge_template_ids.clear()
	var first_template_id := ""
	for preview in previews:
		if typeof(preview) != TYPE_DICTIONARY:
			continue
		var template_id := str(preview.get("id", "")).strip_edges()
		if template_id == "":
			continue
		if first_template_id == "":
			first_template_id = template_id
		_skill_forge_template_ids.append(template_id)
		_skill_forge_template_previews[template_id] = preview.duplicate(true)

	if first_template_id != "" and not _skill_forge_template_previews.has(_active_skill_forge_template_id):
		_active_skill_forge_template_id = first_template_id

	_rebuild_skill_forge_template_buttons()
	_refresh_skill_forge_panel()


func set_skill_forge_result(result: Dictionary) -> void:
	if _skill_forge_result_label == null:
		return
	if result.is_empty():
		_set_skill_forge_result_header("Ready", "", "", Color("#5f7f39"))
		_skill_forge_last_blocked_template_id = ""
		_skill_forge_history_entries.clear()
		_set_skill_forge_detail_line("")
		_set_skill_forge_route_line("")
		_set_skill_forge_ref_line("")
		_set_skill_forge_stage_line("", "")
		_set_skill_forge_next_line("")
		_set_skill_forge_receipt_line("")
		_set_skill_forge_drift_line("")
		_refresh_skill_forge_panel()
		return

	var status := str(result.get("status", "ready")).strip_edges()
	var run: Dictionary = result.get("run", {})
	var skill_name := str(run.get("skill_name", "Skill Run")).strip_edges()
	_record_skill_forge_history_from_result(result)
	var status_text := "Order Blocked" if _skill_forge_result_has_blocked_order(result) else _skill_forge_status_text(status)
	_set_skill_forge_result_header(status_text, skill_name, _skill_forge_result_tooltip(result), _skill_forge_result_status_color(result))
	if status == "blocked":
		_show_skill_forge_blocked_result(result)
	else:
		_skill_forge_last_blocked_template_id = ""
		_refresh_skill_forge_panel(false)
		_set_skill_forge_trace_from_result(result)


func set_skill_forge_work_receipt_trace(event: Dictionary, receipt_text: String) -> void:
	if _skill_forge_trace_label == null:
		return
	var skill_name := str(event.get("skill_name", "Skill Run")).strip_edges()
	if skill_name == "":
		skill_name = "Skill Run"
	_record_skill_forge_history_text("Agent Receipt %s" % skill_name)
	_skill_forge_trace_label.text = "Spec > Directive > Work Order > Agent Receipt"
	var receipt_route := "Spec > Crew Order > Agent Receipt"
	var trace_tooltip := "Forge trace for %s%s | Stage: Agent Receipt | Run Route: %s | Next Step: Review day summary | Run Receipt: %s%s" % [
		skill_name,
		_skill_forge_context_trace_suffix(
			str(event.get("agent_name", "")),
			event.get("grid_pos", Vector2i(-1, -1)),
			event.get("forge_source_context", {})
		) + _skill_forge_identity_trace_suffix(str(event.get("forge_run_id", "")), str(event.get("work_order_id", ""))),
		receipt_route,
		receipt_text,
		_skill_forge_history_tooltip_suffix()
	]
	_skill_forge_trace_label.tooltip_text = trace_tooltip
	_skill_forge_trace_label.add_theme_color_override("font_color", Color("#4f7a3a"))
	_set_skill_forge_result_header("Agent Receipt", skill_name, trace_tooltip, Color("#4f7a3a"))
	_set_skill_forge_detail_line(
		_skill_forge_run_detail_text(str(event.get("agent_name", "")), event.get("grid_pos", Vector2i(-1, -1)), event.get("forge_source_context", {})),
		trace_tooltip,
		Color("#4f7a3a")
	)
	_set_skill_forge_route_line(receipt_route, trace_tooltip, Color("#4f7a3a"))
	_set_skill_forge_ref_line(_skill_forge_ref_line_text(str(event.get("forge_run_id", "")), str(event.get("work_order_id", ""))), trace_tooltip, Color("#6f8568"))
	_set_skill_forge_stage_line("Agent Receipt", skill_name, trace_tooltip, Color("#4f7a3a"))
	_set_skill_forge_next_line("Review day summary", trace_tooltip, Color("#6f8568"))
	_set_skill_forge_receipt_line(receipt_text, trace_tooltip, Color("#4f7a3a"))
	_set_skill_forge_drift_line("")
	_refresh_skill_forge_history_label()


func set_skill_forge_work_order_trace(order: Dictionary, trace_status: String) -> void:
	if _skill_forge_trace_label == null:
		return
	var skill_name := str(order.get("skill_name", order.get("preference_label", "Skill Run"))).strip_edges()
	if skill_name == "":
		skill_name = "Skill Run"
	var order_label := str(order.get("label", "Crew task")).strip_edges()
	var status_text := trace_status.strip_edges()
	if status_text == "":
		status_text = "Crew Queued"
	var trace_detail := "work order stage"
	var next_step := _skill_forge_work_stage_next_text(status_text)
	var route_text := _skill_forge_work_stage_route_text(status_text)
	var receipt_text := _skill_forge_work_stage_receipt_text(status_text, order_label)
	_record_skill_forge_work_stage_history(order, status_text)
	_skill_forge_trace_label.text = "Spec > Directive > Work Order > %s" % status_text
	var trace_tooltip := "Forge trace for %s%s | Stage: %s | Run Route: %s" % [
		skill_name,
		_skill_forge_context_trace_suffix(
			str(order.get("agent_name", "")),
			order.get("target_tile", Vector2i(-1, -1)),
			order.get("source_context", {})
		) + _skill_forge_identity_trace_suffix(str(order.get("forge_run_id", "")), str(order.get("id", ""))),
		status_text,
		route_text
	]
	if next_step != "":
		trace_tooltip += " | Next Step: %s" % next_step
	if receipt_text != "":
		trace_tooltip += " | Run Receipt: %s" % receipt_text
	else:
		trace_tooltip += " | %s: %s" % [trace_detail, order_label]
	trace_tooltip += _skill_forge_history_tooltip_suffix()
	_skill_forge_trace_label.tooltip_text = trace_tooltip
	var stage_color := Color("#8a503e") if status_text == "Crew Waiting" else Color("#4f6f8f")
	_skill_forge_trace_label.add_theme_color_override("font_color", stage_color)
	_set_skill_forge_result_header(status_text, skill_name, trace_tooltip, stage_color)
	_set_skill_forge_detail_line(
		_skill_forge_run_detail_text(str(order.get("agent_name", "")), order.get("target_tile", Vector2i(-1, -1)), order.get("source_context", {})),
		trace_tooltip,
		stage_color
	)
	_set_skill_forge_route_line(route_text, trace_tooltip, stage_color)
	_set_skill_forge_ref_line(_skill_forge_ref_line_text(str(order.get("forge_run_id", "")), str(order.get("id", ""))), trace_tooltip, Color("#6f8568"))
	_set_skill_forge_stage_line(status_text, skill_name, trace_tooltip, stage_color)
	_set_skill_forge_next_line(_skill_forge_work_stage_next_text(status_text), trace_tooltip, Color("#6f8568"))
	_set_skill_forge_receipt_line(_skill_forge_work_stage_receipt_text(status_text, order_label), trace_tooltip, stage_color)
	_set_skill_forge_drift_line("")
	_refresh_skill_forge_history_label()


func set_work_order(order: Dictionary) -> void:
	set_work_orders([order])


func set_crafting_demands(demands: Array) -> void:
	if _crafting_demand_list_stack == null:
		return

	_crew_pending_demand_details = _pending_demand_details_from(demands)
	_crew_pending_demand_labels = _pending_demand_labels_from(demands)
	_crew_pending_demand_order_ids = _pending_demand_order_ids_from(demands)
	_crew_pending_demand_signal_states = _pending_demand_signal_states_from(demands)
	_crew_pending_demand_target_ids = _pending_demand_target_ids_from(demands)
	for child in _crafting_demand_list_stack.get_children():
		child.queue_free()
	_crafting_demand_rows.clear()

	if demands.is_empty():
		_add_empty_crafting_demand_row(_crafting_demand_list_stack)
		_refresh_crew_social_signals()
		return

	for demand in demands:
		if typeof(demand) != TYPE_DICTIONARY:
			continue
		_add_crafting_demand_row(_crafting_demand_list_stack, demand)
	_refresh_crew_social_signals()


func set_crew_missions(missions: Array) -> void:
	if _crew_mission_list_stack == null:
		return

	for child in _crew_mission_list_stack.get_children():
		child.queue_free()
	_crew_mission_rows.clear()

	if missions.is_empty():
		_add_empty_crew_mission_row(_crew_mission_list_stack)
		return

	for mission in missions:
		if typeof(mission) != TYPE_DICTIONARY:
			continue
		_add_crew_mission_row(_crew_mission_list_stack, mission)


func set_work_orders(orders: Array) -> void:
	if _work_order_list_stack == null:
		return

	for child in _work_order_list_stack.get_children():
		child.queue_free()
	_work_order_rows.clear()

	if orders.is_empty():
		_add_empty_work_order_row(_work_order_list_stack)
		return

	for order in orders:
		if typeof(order) != TYPE_DICTIONARY:
			continue
		_add_work_order_row(_work_order_list_stack, order)


func _update_work_order_row(order: Dictionary) -> void:
	if order.is_empty():
		return

	var order_id := str(order.get("id", ""))
	if not _work_order_rows.has(order_id):
		return

	var row: Dictionary = _work_order_rows[order_id]
	var label := str(order.get("label", "Work Order"))
	var status := str(order.get("status", "ready"))
	var action_id := str(order.get("action", "build_fence"))
	var has_required_item := bool(order.get("has_required_item", false))
	var can_craft_item := bool(order.get("can_craft_item", false))
	var can_progress := bool(order.get("can_progress", false))
	var incentive_status := str(order.get("incentive_status_text", ""))
	(row["label"] as Label).text = label
	row["intent"] = "send"

	var preference := row.get("preference", null) as Label
	if preference != null:
		preference.text = _work_order_preference_context_text(order)
		preference.visible = preference.text != ""
		preference.tooltip_text = _work_order_preference_tooltip(order)
		preference.add_theme_color_override("font_color", _work_order_preference_color(order))

	match status:
		"done":
			(row["status"] as Label).text = "Done"
			(row["button"] as Button).text = "Clear"
			(row["button"] as Button).disabled = false
			row["intent"] = "clear"
		"queued":
			(row["status"] as Label).text = "Crew"
			(row["button"] as Button).text = "Busy"
			(row["button"] as Button).disabled = true
		"waiting":
			(row["status"] as Label).text = str(order.get("status_text", "Waiting"))
			(row["button"] as Button).text = "Drop"
			(row["button"] as Button).disabled = false
			row["intent"] = "clear"
		"gathering":
			(row["status"] as Label).text = str(order.get("status_text", "Gather"))
			(row["button"] as Button).text = "Busy"
			(row["button"] as Button).disabled = true
		_:
			if not can_progress:
				(row["status"] as Label).text = str(order.get("status_text", "Blocked"))
				(row["button"] as Button).text = "Drop"
				(row["button"] as Button).disabled = false
				row["intent"] = "clear"
			elif action_id != "build_fence":
				(row["status"] as Label).text = str(order.get("status_text", "Ready"))
				(row["button"] as Button).text = "Send"
			else:
				if has_required_item:
					(row["status"] as Label).text = "Kit ready"
					(row["button"] as Button).text = "Send"
				elif can_craft_item:
					(row["status"] as Label).text = "Can craft"
					(row["button"] as Button).text = "Prep"
				else:
					(row["status"] as Label).text = str(order.get("status_text", "Needs mats"))
					(row["button"] as Button).text = "Ask"
				(row["button"] as Button).disabled = false

	if incentive_status != "":
		(row["status"] as Label).text = incentive_status

	var can_send := status == "ready" and can_progress and str(row.get("intent", "send")) == "send"
	var can_clear := str(row.get("intent", "send")) == "clear" and not (row["button"] as Button).disabled
	var button := row["button"] as Button
	button.add_theme_stylebox_override("normal", _remove_button_style(false) if can_clear else _craft_button_style(can_send))
	button.add_theme_stylebox_override("hover", _remove_button_style(true) if can_clear else _craft_button_style(true))
	button.add_theme_stylebox_override("pressed", _remove_button_style(true) if can_clear else _craft_button_style(true))
	button.add_theme_color_override("font_color", Color("#5c382c") if can_clear else (Color("#2d3b1d") if can_send else Color("#8c8274")))
	button.add_theme_color_override("font_disabled_color", Color("#8c8274"))


func set_selected_item(item_id: String) -> void:
	if _palette:
		_palette.set_selected_item(item_id)
	_set_cursor_item(item_id)


func show_message(message: String) -> void:
	if _toast_label == null:
		return
	_toast_label.text = message
	_toast_label.modulate.a = 1.0
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(2.2)
	_toast_tween.tween_property(_toast_label, "modulate:a", 0.0, 0.45)


func set_agent_snapshots(snapshots: Array) -> void:
	for snapshot in snapshots:
		var agent_id := str(snapshot.get("id", ""))
		if not _crew_rows.has(agent_id):
			continue

		_crew_snapshots_by_id[agent_id] = snapshot.duplicate(true)
		var row: Dictionary = _crew_rows[agent_id]
		var mood := float(snapshot.get("mood", 0.0))
		var energy := float(snapshot.get("energy", 0.0))
		var irritation := float(snapshot.get("irritation", 0.0))
		var expression := str(snapshot.get("expression", "neutral"))
		var action := _format_reaction_action(expression, _format_action(str(snapshot.get("action", "idle")), str(snapshot.get("phase", "idle"))))
		(row["mood"] as ProgressBar).value = mood
		(row["energy"] as ProgressBar).value = energy
		var action_label := row["action"] as Label
		action_label.text = action
		action_label.add_theme_color_override("font_color", Color("#9a4936") if irritation >= 55.0 else (Color("#7f6335") if irritation >= 28.0 else Color("#5e5548")))
		_apply_crew_social_signal(row, snapshot)
		(row["mood_value"] as Label).text = "%s" % roundi(mood)
		(row["card"] as PanelContainer).add_theme_stylebox_override("panel", _crew_row_style(mood))


func set_adversarial_session(session: Dictionary) -> void:
	if _encounter_panel == null:
		return

	var active := bool(session.get("active", false))
	_encounter_panel.visible = active
	if not active:
		_encounter_choices = []
		return

	var agent_name := str(session.get("agent_name", "Crew"))
	_encounter_title_label.text = "%s'S GRIEVANCE" % agent_name.to_upper()
	_encounter_meter.value = float(session.get("patience_meter", 0.0))
	_encounter_goal_label.text = _format_encounter_goal(session)
	_encounter_goal_label.tooltip_text = _encounter_goal_tooltip(session)
	_encounter_line_label.text = str(session.get("npc_line", ""))
	_encounter_choices = session.get("choices", [])

	for index in range(_encounter_choice_buttons.size()):
		var button := _encounter_choice_buttons[index]
		if index >= _encounter_choices.size():
			button.visible = false
			button.disabled = true
			continue

		var choice: Dictionary = _encounter_choices[index]
		button.visible = true
		button.disabled = false
		button.text = str(choice.get("label", "Choice"))
		button.tooltip_text = str(choice.get("claim", ""))


func set_adversarial_prompt(is_available: bool, reason: String = "") -> void:
	_parley_prompt_active = is_available
	_parley_pulse_phase = 0.0
	if _parley_button == null:
		return

	_parley_button.text = "Parley!" if is_available else "Parley"
	_parley_button.tooltip_text = reason if reason != "" else "Open the crew grievance meter"
	_parley_button.modulate = Color.WHITE
	_parley_button.add_theme_stylebox_override("normal", _parley_button_style(is_available, false))
	_parley_button.add_theme_stylebox_override("hover", _parley_button_style(is_available, true))
	_parley_button.add_theme_stylebox_override("pressed", _parley_button_style(is_available, true))


func set_crew_status(text: String, highlighted: bool = false) -> void:
	if _crew_status_label == null:
		return

	_crew_status_label.text = text
	_crew_status_label.add_theme_color_override("font_color", Color("#5d8a36") if highlighted else Color("#9b7433"))


func add_field_log(message: String) -> void:
	if _field_log_stack == null:
		return

	_field_log_entries.push_front(message)
	while _field_log_entries.size() > 4:
		_field_log_entries.pop_back()

	for child in _field_log_stack.get_children():
		child.queue_free()

	for entry in _field_log_entries:
		var label := Label.new()
		label.text = entry
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2(0, 24)
		label.add_theme_font_size_override("font_size", 11)
		label.add_theme_color_override("font_color", Color("#4b4337"))
		_field_log_stack.add_child(label)


func _build_ui() -> void:
	_root = Control.new()
	_root.name = "UIRoot"
	_root.anchor_right = 1.0
	_root.anchor_bottom = 1.0
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_build_title_card()
	_build_toolbar()
	_build_crew_panel()
	_build_palette()
	_build_settings_panel()
	_build_adversarial_panel()
	_build_toast()
	_build_cursor_ghost()


func _build_title_card() -> void:
	var panel := PanelContainer.new()
	panel.name = "TitleCard"
	panel.anchor_left = 0.022
	panel.anchor_top = 0.026
	panel.anchor_right = 0.295
	panel.anchor_bottom = 0.118
	panel.add_theme_stylebox_override("panel", _panel_style(14, 1))
	_root.add_child(panel)
	_register_ui_hit_region(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)

	var icon_panel := PanelContainer.new()
	icon_panel.custom_minimum_size = Vector2(58, 58)
	icon_panel.add_theme_stylebox_override("panel", _soft_box(Color("#f4dda0"), 12, 1))
	row.add_child(icon_panel)

	var icon := Label.new()
	icon.text = "AV"
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon.add_theme_font_size_override("font_size", 21)
	icon.add_theme_color_override("font_color", Color("#332918"))
	icon_panel.add_child(icon)

	var text_stack := VBoxContainer.new()
	text_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	text_stack.add_theme_constant_override("separation", 0)
	row.add_child(text_stack)

	var title := Label.new()
	title.text = "AgentVille"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color("#201d18"))
	text_stack.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Voxel Farm Editor"
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", Color("#756f64"))
	text_stack.add_child(subtitle)


func _build_toolbar() -> void:
	var panel := PanelContainer.new()
	panel.name = "Toolbar"
	panel.anchor_left = 0.022
	panel.anchor_top = 0.20
	panel.anchor_right = 0.095
	panel.anchor_bottom = 0.67
	panel.add_theme_stylebox_override("panel", _panel_style(16, 1))
	_root.add_child(panel)
	_register_ui_hit_region(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 9)
	margin.add_theme_constant_override("margin_right", 9)
	margin.add_theme_constant_override("margin_top", 9)
	margin.add_theme_constant_override("margin_bottom", 9)
	panel.add_child(margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	margin.add_child(stack)

	var rail_label := Label.new()
	rail_label.text = "TOOLS"
	rail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rail_label.add_theme_font_size_override("font_size", 12)
	rail_label.add_theme_color_override("font_color", Color("#8a806f"))
	stack.add_child(rail_label)

	_add_tool_button(stack, "place", "BOX\nPlace", "Place the selected build item")
	_add_tool_button(stack, "till", "SOIL\nTill", "Till soil")
	_add_tool_button(stack, "plant", "CORN\nPlant", "Plant corn")
	_add_tool_button(stack, "harvest", "CROP\nPick", "Harvest grown crops")
	_add_tool_button(stack, "erase", "CLR\nErase", "Clear a tile")
	_add_tool_button(stack, "pan", "PAN\nView", "Pan the camera")


func _add_tool_button(parent: VBoxContainer, tool_name: String, label: String, tooltip: String) -> void:
	var button := Button.new()
	button.text = label
	button.tooltip_text = tooltip
	button.custom_minimum_size = Vector2(86, 54)
	button.focus_mode = Control.FOCUS_NONE
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", Color("#3c352b"))
	button.add_theme_stylebox_override("normal", _tool_button_style(false))
	button.add_theme_stylebox_override("hover", _tool_button_style(true))
	button.add_theme_stylebox_override("pressed", _tool_button_style(true))
	button.pressed.connect(_on_tool_button_pressed.bind(tool_name))
	parent.add_child(button)
	_tool_buttons[tool_name] = button


func _build_palette() -> void:
	_palette = BuildPaletteScene.instantiate()
	_palette.name = "BuildPalette"
	_palette.anchor_left = 0.20
	_palette.anchor_top = 0.795
	_palette.anchor_right = 0.71
	_palette.anchor_bottom = 0.975
	_palette.item_selected.connect(_on_item_selected)
	_root.add_child(_palette)
	_register_ui_hit_region(_palette)


func _build_crew_panel() -> void:
	var panel := PanelContainer.new()
	panel.name = "CrewPanel"
	panel.anchor_left = 0.79
	panel.anchor_top = 0.075
	panel.anchor_right = 0.98
	panel.anchor_bottom = 0.505
	panel.add_theme_stylebox_override("panel", _panel_style(16, 1))
	_root.add_child(panel)
	_register_ui_hit_region(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	margin.add_child(stack)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	stack.add_child(header)

	var title := Label.new()
	title.text = "CREW"
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color("#8a806f"))
	header.add_child(title)

	_parley_button = Button.new()
	_parley_button.text = "Parley"
	_parley_button.tooltip_text = "Open the crew grievance meter"
	_parley_button.custom_minimum_size = Vector2(58, 22)
	_parley_button.focus_mode = Control.FOCUS_NONE
	_parley_button.add_theme_font_size_override("font_size", 11)
	_parley_button.add_theme_color_override("font_color", Color("#4b4337"))
	_parley_button.add_theme_stylebox_override("normal", _parley_button_style(false, false))
	_parley_button.add_theme_stylebox_override("hover", _parley_button_style(false, true))
	_parley_button.add_theme_stylebox_override("pressed", _parley_button_style(false, true))
	_parley_button.pressed.connect(func() -> void:
		sound_requested.emit("ui_click")
		adversarial_encounter_requested.emit("")
	)
	header.add_child(_parley_button)

	_crew_status_label = Label.new()
	_crew_status_label.text = "watching"
	_crew_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_crew_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_crew_status_label.add_theme_font_size_override("font_size", 12)
	_crew_status_label.add_theme_color_override("font_color", Color("#9b7433"))
	header.add_child(_crew_status_label)

	_add_crew_row(stack, "bert", "Bert", "grizzled", Color("#5c7f9f"))
	_add_crew_row(stack, "marigold", "Marigold", "hopeful", Color("#7faf62"))
	_add_crew_row(stack, "chuck", "Chuck", "chaotic", Color("#9b6fb6"))

	var mission_label := Label.new()
	mission_label.text = "MISSIONS"
	mission_label.add_theme_font_size_override("font_size", 12)
	mission_label.add_theme_color_override("font_color", Color("#8a806f"))
	stack.add_child(mission_label)

	_crew_mission_list_stack = VBoxContainer.new()
	_crew_mission_list_stack.add_theme_constant_override("separation", 3)
	stack.add_child(_crew_mission_list_stack)
	_add_empty_crew_mission_row(_crew_mission_list_stack)

	var log_label := Label.new()
	log_label.text = "FIELD LOG"
	log_label.add_theme_font_size_override("font_size", 12)
	log_label.add_theme_color_override("font_color", Color("#8a806f"))
	stack.add_child(log_label)

	_field_log_stack = VBoxContainer.new()
	_field_log_stack.add_theme_constant_override("separation", 4)
	stack.add_child(_field_log_stack)
	add_field_log("Crew clocked in. Nobody has unionized yet.")


func _add_crew_row(parent: VBoxContainer, agent_id: String, agent_name: String, trait_name: String, color: Color) -> void:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 54)
	card.add_theme_stylebox_override("panel", _crew_row_style(50.0))
	parent.add_child(card)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 9)
	margin.add_theme_constant_override("margin_right", 9)
	margin.add_theme_constant_override("margin_top", 7)
	margin.add_theme_constant_override("margin_bottom", 7)
	card.add_child(margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 4)
	margin.add_child(stack)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 7)
	stack.add_child(top)

	var pip := PanelContainer.new()
	pip.custom_minimum_size = Vector2(12, 12)
	pip.add_theme_stylebox_override("panel", _soft_box(color, 6, 1))
	top.add_child(pip)

	var name_label := Label.new()
	name_label.text = agent_name
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", Color("#2f2a22"))
	top.add_child(name_label)

	var trait_label := Label.new()
	trait_label.text = trait_name
	trait_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	trait_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	trait_label.add_theme_font_size_override("font_size", 12)
	trait_label.add_theme_color_override("font_color", Color("#8a806f"))
	top.add_child(trait_label)

	var action_label := Label.new()
	action_label.text = "Idle"
	action_label.add_theme_font_size_override("font_size", 12)
	action_label.add_theme_color_override("font_color", Color("#5e5548"))
	stack.add_child(action_label)

	var social_label := Label.new()
	social_label.text = ""
	social_label.visible = false
	social_label.mouse_filter = Control.MOUSE_FILTER_PASS
	social_label.add_theme_font_size_override("font_size", 10)
	social_label.add_theme_color_override("font_color", Color("#5f7f39"))
	social_label.gui_input.connect(func(event: InputEvent) -> void:
		_on_crew_social_signal_input(agent_id, event)
	)
	stack.add_child(social_label)

	var bars := HBoxContainer.new()
	bars.add_theme_constant_override("separation", 6)
	stack.add_child(bars)

	var mood_bar := _make_tiny_bar(Color("#8fba5a"))
	bars.add_child(mood_bar)

	var energy_bar := _make_tiny_bar(Color("#e0b94d"))
	bars.add_child(energy_bar)

	var mood_value := Label.new()
	mood_value.text = "--"
	mood_value.custom_minimum_size = Vector2(26, 0)
	mood_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	mood_value.add_theme_font_size_override("font_size", 11)
	mood_value.add_theme_color_override("font_color", Color("#7a6f60"))
	bars.add_child(mood_value)

	_crew_rows[agent_id] = {
		"card": card,
		"mood": mood_bar,
		"energy": energy_bar,
		"action": action_label,
		"social": social_label,
		"mood_value": mood_value
	}


func _make_tiny_bar(fill_color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = 100
	bar.value = 50
	bar.show_percentage = false
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.custom_minimum_size = Vector2(0, 7)
	bar.add_theme_stylebox_override("background", _soft_box(Color("#eee8d9"), 4, 0))
	bar.add_theme_stylebox_override("fill", _soft_box(fill_color, 4, 0))
	return bar


func _build_settings_panel() -> void:
	var panel := PanelContainer.new()
	panel.name = "SettingsPanel"
	panel.anchor_left = 0.79
	panel.anchor_top = 0.515
	panel.anchor_right = 0.98
	panel.anchor_bottom = 0.99
	panel.add_theme_stylebox_override("panel", _panel_style(16, 1))
	_root.add_child(panel)
	_register_ui_hit_region(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 2)
	margin.add_child(stack)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 8)
	stack.add_child(top_row)

	_day_label = Label.new()
	_day_label.text = "DAY 1 / 10:00 AM"
	_day_label.add_theme_font_size_override("font_size", 19)
	_day_label.add_theme_color_override("font_color", Color("#201d18"))
	top_row.add_child(_day_label)

	_money_label = Label.new()
	_money_label.text = "42 COINS"
	_money_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_money_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_money_label.add_theme_font_size_override("font_size", 16)
	_money_label.add_theme_color_override("font_color", Color("#9b7433"))
	top_row.add_child(_money_label)

	var progress := ProgressBar.new()
	progress.min_value = 0
	progress.max_value = 100
	progress.value = 38
	progress.show_percentage = false
	progress.custom_minimum_size = Vector2(0, 8)
	progress.add_theme_stylebox_override("background", _soft_box(Color("#eee8d9"), 7, 1))
	progress.add_theme_stylebox_override("fill", _soft_box(Color("#f2c94c"), 7, 0))
	stack.add_child(progress)

	_build_inventory_strip(stack)
	_build_craft_controls(stack)
	_build_crafting_demand_controls(stack)
	_build_work_order_controls(stack)
	_build_skill_forge_controls(stack)

	var mode_label := Label.new()
	mode_label.text = "VIEW"
	mode_label.add_theme_font_size_override("font_size", 12)
	mode_label.add_theme_color_override("font_color", Color("#8a806f"))
	stack.add_child(mode_label)

	stack.add_child(_make_toggle("AO", true, ambient_occlusion_changed))
	stack.add_child(_make_toggle("Grid", true, grid_visibility_changed))
	stack.add_child(_make_toggle("Shadows", true, shadows_changed))

	var end_day := Button.new()
	end_day.text = "End Day"
	end_day.custom_minimum_size = Vector2(0, 28)
	end_day.focus_mode = Control.FOCUS_NONE
	end_day.tooltip_text = "Advance crop growth"
	end_day.add_theme_font_size_override("font_size", 16)
	end_day.add_theme_color_override("font_color", Color("#2c2619"))
	end_day.add_theme_stylebox_override("normal", _big_button_style(false))
	end_day.add_theme_stylebox_override("hover", _big_button_style(true))
	end_day.add_theme_stylebox_override("pressed", _big_button_style(true))
	end_day.pressed.connect(func() -> void: advance_day_requested.emit())
	stack.add_child(end_day)


func _build_inventory_strip(parent: VBoxContainer) -> void:
	var label := Label.new()
	label.text = "STASH"
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color("#8a806f"))
	parent.add_child(label)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	parent.add_child(row)

	row.add_child(_make_inventory_pill("fiber", "FBR 0", Color("#dfeecf"), false))
	row.add_child(_make_inventory_pill("grain", "GRN 0", Color("#fff1bd"), false))
	row.add_child(_make_inventory_pill("stone", "STN 0", Color("#e1e2d9"), false))
	row.add_child(_make_inventory_pill("fence_kit", "KIT 0", Color("#e8f0ff"), true))
	row.add_child(_make_inventory_pill("seed_bundle", "SBD 0", Color("#e8f6cf"), true))
	row.add_child(_make_inventory_pill("rush_kit", "RSH 0", Color("#f0e5ff"), true))


func _build_craft_controls(parent: VBoxContainer) -> void:
	_add_craft_button(parent, "fence_kit", "Fence Kit  2 FBR + 1 GRN", "Crafts one fence kit from gathered fiber and grain")
	_add_craft_button(parent, "seed_bundle", "Seed Bundle  2 GRN", "Crafts one seed bundle for crew supply demands")
	_add_craft_button(parent, "rush_kit", "Rush Kit  1 FBR + 1 STN", "Crafts one rush kit for Chuck's obstacle-clearing demands")


func _add_craft_button(parent: VBoxContainer, recipe_id: String, label: String, tooltip: String) -> void:
	var button := Button.new()
	button.text = label
	button.tooltip_text = tooltip
	button.custom_minimum_size = Vector2(0, 20)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 11)
	button.add_theme_color_override("font_color", Color("#998e7d"))
	button.add_theme_color_override("font_disabled_color", Color("#8c8274"))
	button.add_theme_stylebox_override("normal", _craft_button_style(false))
	button.add_theme_stylebox_override("hover", _craft_button_style(true))
	button.add_theme_stylebox_override("pressed", _craft_button_style(true))
	button.pressed.connect(func() -> void:
		sound_requested.emit("ui_click")
		craft_requested.emit(recipe_id)
	)
	parent.add_child(button)
	_craft_buttons[recipe_id] = button


func _set_craft_button_state(recipe_id: String, can_craft: bool) -> void:
	if not _craft_buttons.has(recipe_id):
		return

	var button := _craft_buttons[recipe_id] as Button
	button.disabled = not can_craft
	button.add_theme_stylebox_override("normal", _craft_button_style(can_craft))
	button.add_theme_stylebox_override("hover", _craft_button_style(true))
	button.add_theme_stylebox_override("pressed", _craft_button_style(true))
	button.add_theme_color_override("font_color", Color("#2d3b1d") if can_craft else Color("#998e7d"))
	button.add_theme_color_override("font_disabled_color", Color("#8c8274"))


func _build_crafting_demand_controls(parent: VBoxContainer) -> void:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 44)
	card.add_theme_stylebox_override("panel", _soft_box(Color("#fff4e8"), 10, 1))
	parent.add_child(card)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_bottom", 5)
	card.add_child(margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 2)
	margin.add_child(stack)

	var title := Label.new()
	title.text = "CREW DEMANDS"
	title.add_theme_font_size_override("font_size", 10)
	title.add_theme_color_override("font_color", Color("#8a806f"))
	stack.add_child(title)

	_crafting_demand_list_stack = VBoxContainer.new()
	_crafting_demand_list_stack.add_theme_constant_override("separation", 2)
	stack.add_child(_crafting_demand_list_stack)
	_add_empty_crafting_demand_row(_crafting_demand_list_stack)


func _build_work_order_controls(parent: VBoxContainer) -> void:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 92)
	card.add_theme_stylebox_override("panel", _soft_box(Color("#fff7df"), 10, 1))
	parent.add_child(card)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_bottom", 5)
	card.add_child(margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 2)
	margin.add_child(stack)

	var title := Label.new()
	title.text = "CREW ORDERS"
	title.add_theme_font_size_override("font_size", 10)
	title.add_theme_color_override("font_color", Color("#8a806f"))
	stack.add_child(title)

	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 5)
	stack.add_child(action_row)

	_add_work_order_action_button(action_row, "build_fence", "FNC\nFence", "Mark a tile for crew-built fence")
	_add_work_order_action_button(action_row, "clear_brush", "CLR\nClear", "Mark brush for the crew to clear")
	_add_work_order_action_button(action_row, "harvest_crop", "HRV\nPick", "Mark a ready crop for the crew to harvest")

	_work_order_list_stack = VBoxContainer.new()
	_work_order_list_stack.add_theme_constant_override("separation", 2)
	stack.add_child(_work_order_list_stack)
	_add_empty_work_order_row(_work_order_list_stack)


func _build_skill_forge_controls(parent: VBoxContainer) -> void:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 184)
	card.add_theme_stylebox_override("panel", _soft_box(Color("#eef7ee"), 10, 1))
	parent.add_child(card)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_bottom", 5)
	card.add_child(margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 2)
	margin.add_child(stack)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	stack.add_child(header)

	var title := Label.new()
	title.text = "SKILL FORGE"
	title.add_theme_font_size_override("font_size", 10)
	title.add_theme_color_override("font_color", Color("#6f8568"))
	header.add_child(title)

	_skill_forge_result_label = Label.new()
	_skill_forge_result_label.text = "Ready"
	_skill_forge_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_skill_forge_result_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_skill_forge_result_label.clip_text = true
	_skill_forge_result_label.add_theme_font_size_override("font_size", 9)
	_skill_forge_result_label.add_theme_color_override("font_color", Color("#5f7f39"))
	header.add_child(_skill_forge_result_label)

	_skill_forge_template_button_row = HBoxContainer.new()
	_skill_forge_template_button_row.add_theme_constant_override("separation", 5)
	stack.add_child(_skill_forge_template_button_row)

	_skill_forge_summary_label = Label.new()
	_skill_forge_summary_label.text = "Load a starter skill spec."
	_skill_forge_summary_label.custom_minimum_size = Vector2(0, 16)
	_skill_forge_summary_label.clip_text = true
	_skill_forge_summary_label.add_theme_font_size_override("font_size", 9)
	_skill_forge_summary_label.add_theme_color_override("font_color", Color("#3f4a37"))
	stack.add_child(_skill_forge_summary_label)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 6)
	stack.add_child(bottom)

	_skill_forge_meta_label = Label.new()
	_skill_forge_meta_label.text = "Manual | 0 steps | check"
	_skill_forge_meta_label.clip_text = true
	_skill_forge_meta_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_skill_forge_meta_label.add_theme_font_size_override("font_size", 9)
	_skill_forge_meta_label.add_theme_color_override("font_color", Color("#6f8568"))
	bottom.add_child(_skill_forge_meta_label)

	_skill_forge_lesson_label = Label.new()
	_skill_forge_lesson_label.text = ""
	_skill_forge_lesson_label.visible = true
	_skill_forge_lesson_label.clip_text = true
	_skill_forge_lesson_label.add_theme_font_size_override("font_size", 9)
	_skill_forge_lesson_label.add_theme_color_override("font_color", Color("#6f8568"))
	stack.add_child(_skill_forge_lesson_label)

	_skill_forge_trace_label = Label.new()
	_skill_forge_trace_label.text = "Spec > Receipt"
	_skill_forge_trace_label.clip_text = true
	_skill_forge_trace_label.add_theme_font_size_override("font_size", 9)
	_skill_forge_trace_label.add_theme_color_override("font_color", Color("#4f6f8f"))
	stack.add_child(_skill_forge_trace_label)

	_skill_forge_route_label = Label.new()
	_skill_forge_route_label.text = ""
	_skill_forge_route_label.visible = false
	_skill_forge_route_label.clip_text = true
	_skill_forge_route_label.add_theme_font_size_override("font_size", 8)
	_skill_forge_route_label.add_theme_color_override("font_color", Color("#4f6f8f"))
	stack.add_child(_skill_forge_route_label)

	_skill_forge_ref_label = Label.new()
	_skill_forge_ref_label.text = ""
	_skill_forge_ref_label.visible = false
	_skill_forge_ref_label.clip_text = true
	_skill_forge_ref_label.add_theme_font_size_override("font_size", 8)
	_skill_forge_ref_label.add_theme_color_override("font_color", Color("#6f8568"))
	stack.add_child(_skill_forge_ref_label)

	_skill_forge_detail_label = Label.new()
	_skill_forge_detail_label.text = ""
	_skill_forge_detail_label.visible = false
	_skill_forge_detail_label.clip_text = true
	_skill_forge_detail_label.add_theme_font_size_override("font_size", 8)
	_skill_forge_detail_label.add_theme_color_override("font_color", Color("#4f6f8f"))
	stack.add_child(_skill_forge_detail_label)

	_skill_forge_stage_label = Label.new()
	_skill_forge_stage_label.text = ""
	_skill_forge_stage_label.visible = false
	_skill_forge_stage_label.clip_text = true
	_skill_forge_stage_label.add_theme_font_size_override("font_size", 8)
	_skill_forge_stage_label.add_theme_color_override("font_color", Color("#4f6f8f"))
	stack.add_child(_skill_forge_stage_label)

	_skill_forge_next_label = Label.new()
	_skill_forge_next_label.text = ""
	_skill_forge_next_label.visible = false
	_skill_forge_next_label.clip_text = true
	_skill_forge_next_label.add_theme_font_size_override("font_size", 8)
	_skill_forge_next_label.add_theme_color_override("font_color", Color("#6f8568"))
	stack.add_child(_skill_forge_next_label)

	_skill_forge_receipt_label = Label.new()
	_skill_forge_receipt_label.text = ""
	_skill_forge_receipt_label.visible = false
	_skill_forge_receipt_label.clip_text = true
	_skill_forge_receipt_label.add_theme_font_size_override("font_size", 8)
	_skill_forge_receipt_label.add_theme_color_override("font_color", Color("#6f8568"))
	stack.add_child(_skill_forge_receipt_label)

	_skill_forge_drift_label = Label.new()
	_skill_forge_drift_label.text = ""
	_skill_forge_drift_label.visible = false
	_skill_forge_drift_label.clip_text = true
	_skill_forge_drift_label.add_theme_font_size_override("font_size", 8)
	_skill_forge_drift_label.add_theme_color_override("font_color", Color("#8a503e"))
	stack.add_child(_skill_forge_drift_label)

	_skill_forge_history_label = Label.new()
	_skill_forge_history_label.text = ""
	_skill_forge_history_label.visible = false
	_skill_forge_history_label.clip_text = true
	_skill_forge_history_label.add_theme_font_size_override("font_size", 8)
	_skill_forge_history_label.add_theme_color_override("font_color", Color("#6f8568"))
	stack.add_child(_skill_forge_history_label)

	_skill_forge_run_button = Button.new()
	_skill_forge_run_button.text = "Run"
	_skill_forge_run_button.custom_minimum_size = Vector2(56, 19)
	_skill_forge_run_button.focus_mode = Control.FOCUS_NONE
	_skill_forge_run_button.add_theme_font_size_override("font_size", 10)
	_skill_forge_run_button.add_theme_color_override("font_color", Color("#2d3b1d"))
	_skill_forge_run_button.add_theme_stylebox_override("normal", _craft_button_style(true))
	_skill_forge_run_button.add_theme_stylebox_override("hover", _craft_button_style(true))
	_skill_forge_run_button.add_theme_stylebox_override("pressed", _craft_button_style(true))
	_skill_forge_run_button.pressed.connect(_on_skill_forge_run_pressed)
	bottom.add_child(_skill_forge_run_button)

	_skill_forge_review_button = Button.new()
	_skill_forge_review_button.text = "Check"
	_skill_forge_review_button.custom_minimum_size = Vector2(52, 19)
	_skill_forge_review_button.focus_mode = Control.FOCUS_NONE
	_skill_forge_review_button.add_theme_font_size_override("font_size", 10)
	_skill_forge_review_button.add_theme_color_override("font_color", Color("#4b4337"))
	_skill_forge_review_button.add_theme_stylebox_override("normal", _craft_button_style(true))
	_skill_forge_review_button.add_theme_stylebox_override("hover", _craft_button_style(true))
	_skill_forge_review_button.add_theme_stylebox_override("pressed", _craft_button_style(true))
	_skill_forge_review_button.pressed.connect(_on_skill_forge_review_pressed)
	bottom.add_child(_skill_forge_review_button)

	_skill_forge_revision_button = Button.new()
	_skill_forge_revision_button.text = "Fix"
	_skill_forge_revision_button.custom_minimum_size = Vector2(42, 19)
	_skill_forge_revision_button.focus_mode = Control.FOCUS_NONE
	_skill_forge_revision_button.disabled = true
	_skill_forge_revision_button.add_theme_font_size_override("font_size", 10)
	_skill_forge_revision_button.add_theme_color_override("font_color", Color("#8c8274"))
	_skill_forge_revision_button.add_theme_color_override("font_disabled_color", Color("#8c8274"))
	_skill_forge_revision_button.add_theme_stylebox_override("normal", _craft_button_style(false))
	_skill_forge_revision_button.add_theme_stylebox_override("hover", _craft_button_style(true))
	_skill_forge_revision_button.add_theme_stylebox_override("pressed", _craft_button_style(true))
	_skill_forge_revision_button.pressed.connect(_on_skill_forge_revision_pressed)
	bottom.add_child(_skill_forge_revision_button)

	_refresh_skill_forge_panel()


func _rebuild_skill_forge_template_buttons() -> void:
	if _skill_forge_template_button_row == null:
		return

	for child in _skill_forge_template_button_row.get_children():
		child.queue_free()
	_skill_forge_template_buttons.clear()

	for template_id in _skill_forge_template_ids:
		if not _skill_forge_template_previews.has(template_id):
			continue
		var preview: Dictionary = _skill_forge_template_previews[template_id]
		var button := Button.new()
		button.text = _skill_forge_button_text(preview)
		button.tooltip_text = _skill_forge_template_tooltip(preview)
		button.custom_minimum_size = Vector2(0, 22)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size", 10)
		button.pressed.connect(_on_skill_forge_template_pressed.bind(str(template_id)))
		_skill_forge_template_button_row.add_child(button)
		_skill_forge_template_buttons[template_id] = button


func _refresh_skill_forge_panel(show_preview_header: bool = true) -> void:
	var has_active := _active_skill_forge_template_id != "" and _skill_forge_template_previews.has(_active_skill_forge_template_id)
	for template_id in _skill_forge_template_buttons.keys():
		var button := _skill_forge_template_buttons[template_id] as Button
		var active := str(template_id) == _active_skill_forge_template_id
		button.add_theme_stylebox_override("normal", _crew_order_button_style(active))
		button.add_theme_stylebox_override("hover", _crew_order_button_style(true))
		button.add_theme_stylebox_override("pressed", _crew_order_button_style(true))
		button.add_theme_color_override("font_color", Color("#23331a") if active else Color("#4b4337"))

	if _skill_forge_run_button:
		_skill_forge_run_button.disabled = not has_active
		_skill_forge_run_button.add_theme_color_override("font_color", Color("#2d3b1d") if has_active else Color("#8c8274"))
		_skill_forge_run_button.add_theme_color_override("font_disabled_color", Color("#8c8274"))
	if _skill_forge_review_button:
		_skill_forge_review_button.disabled = not has_active
		_skill_forge_review_button.add_theme_color_override("font_color", Color("#4b4337") if has_active else Color("#8c8274"))
		_skill_forge_review_button.add_theme_color_override("font_disabled_color", Color("#8c8274"))
	_set_skill_forge_revision_button_enabled(has_active and _skill_forge_last_blocked_template_id == _active_skill_forge_template_id)
	_refresh_skill_forge_action_tooltips(has_active)

	if not has_active:
		if show_preview_header:
			_set_skill_forge_result_header("Ready", "", "", Color("#5f7f39"))
		if _skill_forge_summary_label:
			_skill_forge_summary_label.text = "No starter templates loaded."
		if _skill_forge_meta_label:
			_skill_forge_meta_label.text = "Manual | 0 steps | check"
		if _skill_forge_lesson_label:
			_skill_forge_lesson_label.text = ""
		if _skill_forge_trace_label:
			_skill_forge_trace_label.text = "Spec > Receipt"
			_skill_forge_trace_label.tooltip_text = ""
		_set_skill_forge_detail_line("")
		_set_skill_forge_route_line("")
		_set_skill_forge_ref_line("")
		_set_skill_forge_stage_line("", "")
		_set_skill_forge_next_line("")
		_set_skill_forge_receipt_line("")
		_set_skill_forge_drift_line("")
		_refresh_skill_forge_history_label()
		return

	var preview: Dictionary = _skill_forge_template_previews[_active_skill_forge_template_id]
	var preview_tooltip := _skill_forge_preview_trace_tooltip(preview)
	if show_preview_header:
		_set_skill_forge_result_header("Spec Preview", str(preview.get("name", "Skill Run")), preview_tooltip, Color("#4f6f8f"))
	if _skill_forge_summary_label:
		_skill_forge_summary_label.text = "Trigger %s | Context %s" % [
			str(preview.get("trigger_type", "manual")),
			str(preview.get("context_label", preview.get("context", "selected_tile")))
		]
	if _skill_forge_lesson_label:
		_skill_forge_lesson_label.text = "Tools %s | Steps %s" % [
			str(preview.get("tools_label", "")),
			str(preview.get("step_label", ""))
		]
	if _skill_forge_meta_label:
		_skill_forge_meta_label.text = "Check %s | Receipt %s" % [
			str(preview.get("check_label", preview.get("success_check", "check"))),
			str(preview.get("receipt_label", "receipt"))
		]
	if _skill_forge_trace_label:
		_skill_forge_trace_label.text = _skill_forge_preview_trace_text(preview)
		_skill_forge_trace_label.tooltip_text = preview_tooltip
		_skill_forge_trace_label.add_theme_color_override("font_color", Color("#4f6f8f"))
	_set_skill_forge_detail_line("")
	_set_skill_forge_route_line(_skill_forge_preview_route_line_text(preview), preview_tooltip, Color("#4f6f8f"))
	_set_skill_forge_ref_line("")
	_set_skill_forge_stage_line("Spec Preview", str(preview.get("name", "Skill Run")), preview_tooltip, Color("#4f6f8f"))
	_set_skill_forge_next_line(_skill_forge_preview_next_text(preview), preview_tooltip, Color("#6f8568"))
	_set_skill_forge_receipt_line("")
	_set_skill_forge_drift_line("")
	_refresh_skill_forge_history_label()


func _skill_forge_button_text(preview: Dictionary) -> String:
	var name := str(preview.get("name", "Skill")).strip_edges()
	match name:
		"Tend Crops":
			return "TND\nCrops"
		"Clear Patch":
			return "CLR\nPatch"
	return name


func _skill_forge_template_tooltip(preview: Dictionary) -> String:
	var parts: Array[String] = []
	var lesson := str(preview.get("lesson", preview.get("summary", ""))).strip_edges()
	if lesson != "":
		parts.append(lesson)
	parts.append("Stage: Starter Spec -> Spec Preview")
	var trace_text := _skill_forge_preview_trace_text(preview)
	if trace_text != "":
		parts.append("Preview: %s" % trace_text)
	return " | ".join(parts)


func _skill_forge_preview_trace_tooltip(preview: Dictionary) -> String:
	var parts: Array[String] = [
		"Preview trace for %s" % str(preview.get("name", "Skill Run")),
		"Stage: Spec Preview"
	]
	var tools_label := str(preview.get("tools_label", "")).strip_edges()
	if tools_label != "":
		parts.append("spec tools %s" % tools_label)
	var route_text := _skill_forge_preview_route_text(_skill_forge_final_tool_label(tools_label))
	if route_text != "":
		parts.append("route %s" % route_text)
	var check_label := str(preview.get("check_label", preview.get("success_check", ""))).strip_edges()
	if check_label != "":
		parts.append("check %s" % check_label)
	var receipt_label := str(preview.get("receipt_label", "")).strip_edges()
	if receipt_label != "":
		parts.append("receipt %s" % receipt_label)
	return " | ".join(parts) + _skill_forge_history_tooltip_suffix()


func _on_skill_forge_template_pressed(template_id: String) -> void:
	if not _skill_forge_template_previews.has(template_id):
		return
	_active_skill_forge_template_id = template_id
	_skill_forge_last_blocked_template_id = ""
	sound_requested.emit("ui_click")
	_refresh_skill_forge_panel()


func _on_skill_forge_run_pressed() -> void:
	if _active_skill_forge_template_id == "" or not _skill_forge_template_previews.has(_active_skill_forge_template_id):
		return
	sound_requested.emit("ui_click")
	skill_forge_run_requested.emit(_active_skill_forge_template_id)


func _on_skill_forge_review_pressed() -> void:
	if _active_skill_forge_template_id == "" or not _skill_forge_template_previews.has(_active_skill_forge_template_id):
		return
	sound_requested.emit("ui_click")
	skill_forge_review_requested.emit(_active_skill_forge_template_id)


func _on_skill_forge_revision_pressed() -> void:
	if _skill_forge_last_blocked_template_id == "":
		return
	sound_requested.emit("ui_click")
	skill_forge_revision_requested.emit(_skill_forge_last_blocked_template_id)


func _show_skill_forge_blocked_result(result: Dictionary) -> void:
	var run: Dictionary = result.get("run", {})
	_skill_forge_last_blocked_template_id = str(run.get("skill_id", _active_skill_forge_template_id)).strip_edges()
	if _skill_forge_last_blocked_template_id == "":
		_skill_forge_last_blocked_template_id = _active_skill_forge_template_id

	if _skill_forge_summary_label:
		_skill_forge_summary_label.text = _skill_forge_first_issue_text(result)
	if _skill_forge_meta_label:
		_skill_forge_meta_label.text = _skill_forge_revision_suggestion_text(result)
	_set_skill_forge_trace_from_result(result)
	_set_skill_forge_revision_button_enabled(_skill_forge_last_blocked_template_id == _active_skill_forge_template_id)


func _set_skill_forge_revision_button_enabled(is_enabled: bool) -> void:
	if _skill_forge_revision_button == null:
		return
	var has_active := _active_skill_forge_template_id != "" and _skill_forge_template_previews.has(_active_skill_forge_template_id)
	_skill_forge_revision_button.disabled = not is_enabled
	_skill_forge_revision_button.add_theme_stylebox_override("normal", _craft_button_style(is_enabled))
	_skill_forge_revision_button.add_theme_stylebox_override("hover", _craft_button_style(true))
	_skill_forge_revision_button.add_theme_stylebox_override("pressed", _craft_button_style(true))
	_skill_forge_revision_button.add_theme_color_override("font_color", Color("#2d3b1d") if is_enabled else Color("#8c8274"))
	_skill_forge_revision_button.add_theme_color_override("font_disabled_color", Color("#8c8274"))
	_skill_forge_revision_button.tooltip_text = _skill_forge_revision_tooltip(has_active, is_enabled)


func _refresh_skill_forge_action_tooltips(has_active: bool) -> void:
	if _skill_forge_run_button:
		if has_active:
			_skill_forge_run_button.tooltip_text = "Run the selected starter spec through the local harness | Stage: Spec Preview -> Harness Receipt"
		else:
			_skill_forge_run_button.tooltip_text = "Load a starter spec before running the harness"
	if _skill_forge_review_button:
		if has_active:
			_skill_forge_review_button.tooltip_text = "Check a flawed draft against the local validator | Stage: Spec Preview -> Spec Blocked"
		else:
			_skill_forge_review_button.tooltip_text = "Load a starter spec before checking a draft"


func _skill_forge_revision_tooltip(has_active: bool, is_enabled: bool) -> String:
	if is_enabled:
		return "Apply the suggested starter-spec revision | Stage: Spec Blocked -> Spec Fixed"
	if has_active:
		return "Check a blocked spec to unlock Fix | Stage: Spec Preview"
	return "Load a starter spec before applying a fix"


func _set_skill_forge_result_header(status_text: String, skill_name: String, tooltip_text: String = "", color: Color = Color("#5f7f39")) -> void:
	if _skill_forge_result_label == null:
		return
	status_text = status_text.strip_edges()
	skill_name = skill_name.strip_edges()
	if status_text == "":
		status_text = "Ready"
	if skill_name != "":
		_skill_forge_result_label.text = "%s: %s" % [status_text, skill_name]
	else:
		_skill_forge_result_label.text = status_text
	_skill_forge_result_label.tooltip_text = tooltip_text
	_skill_forge_result_label.add_theme_color_override("font_color", color)


func _skill_forge_first_issue_text(result: Dictionary) -> String:
	var validation: Dictionary = result.get("validation", {})
	var errors = validation.get("errors", [])
	if typeof(errors) == TYPE_ARRAY and not errors.is_empty():
		var first_error = errors[0]
		if typeof(first_error) == TYPE_DICTIONARY:
			return str(first_error.get("message", "Revise the spec and try again."))
	return "Revise the spec and try again."


func _skill_forge_revision_suggestion_text(result: Dictionary) -> String:
	var run: Dictionary = result.get("run", {})
	var suggestion := str(run.get("failure_suggestion", "")).strip_edges()
	if suggestion == "":
		suggestion = "Revise the spec and try again."
	return "Fix: %s" % suggestion


func _skill_forge_status_text(status: String) -> String:
	match status:
		"started":
			return "Started"
		"passed":
			return "Passed"
		"failed":
			return "Failed"
		"blocked":
			return "Blocked"
	return "Ready"


func _skill_forge_status_color(status: String) -> Color:
	match status:
		"passed":
			return Color("#4f7a3a")
		"failed", "blocked":
			return Color("#8a503e")
		"started":
			return Color("#4f6f8f")
	return Color("#5f7f39")


func _skill_forge_result_status_color(result: Dictionary) -> Color:
	if _skill_forge_result_has_blocked_order(result):
		return Color("#8a503e")
	return _skill_forge_status_color(str(result.get("status", "")).strip_edges())


func _skill_forge_result_tooltip(result: Dictionary) -> String:
	var status := str(result.get("status", "")).strip_edges()
	var run: Dictionary = result.get("run", {})
	var detail := str(run.get("result_detail", "")).strip_edges()
	var drift := str(run.get("drift", {}).get("level", "steady")).strip_edges()
	var suggestion := str(run.get("failure_suggestion", "")).strip_edges()
	var blocked_reason := str(result.get("drafted_order_blocked_reason", "")).strip_edges()
	var blocked_detail := str(result.get("drafted_order_blocked_detail", "")).strip_edges()
	var stage := _skill_forge_result_history_stage(result)
	var text := "Drift: %s" % drift
	if stage != "":
		text += " | Stage: %s" % stage
	var route_text := _skill_forge_result_route_line_text(result)
	if route_text != "":
		text += " | Run Route: %s" % route_text
	var trace_text := _skill_forge_result_trace_text(result)
	if trace_text != "":
		text += " | Trace: %s" % trace_text
	var next_step := _skill_forge_result_next_line_text(result)
	if next_step != "":
		text += " | Next Step: %s" % next_step
	if detail != "":
		text += " | %s" % detail
	if blocked_detail != "":
		text += " | Order blocked: %s" % blocked_detail
	elif blocked_reason != "":
		text += " | Order blocked: %s" % blocked_reason
	if status in ["failed", "blocked"] and suggestion != "":
		text += " | Fix: %s" % suggestion
	text += _skill_forge_identity_trace_suffix(str(run.get("id", "")), str(result.get("drafted_order_id", "")))
	text += _skill_forge_history_tooltip_suffix()
	return text


func _skill_forge_preview_trace_text(preview: Dictionary) -> String:
	var tools_label := str(preview.get("tools_label", "")).strip_edges()
	var final_tool := _skill_forge_final_tool_label(tools_label)
	if final_tool == "":
		return "Spec > Receipt"
	var route_text := _skill_forge_preview_route_text(final_tool)
	if route_text == "":
		return "Spec > %s" % final_tool
	return "Spec > %s > %s" % [final_tool, route_text]


func _skill_forge_preview_next_text(preview: Dictionary) -> String:
	var final_tool := _skill_forge_final_tool_label(str(preview.get("tools_label", "")).strip_edges())
	match _skill_forge_preview_route_text(final_tool):
		"Crew Order":
			return "Run to crew order or Check"
		"Forge Receipt":
			return "Run for Forge receipt or Check"
	return "Run or Check"


func _skill_forge_preview_route_text(final_tool: String) -> String:
	match final_tool.strip_edges():
		"build_fence", "clear_brush", "harvest_crop":
			return "Crew Order"
		"tend_crop":
			return "Forge Receipt"
	return ""


func _skill_forge_preview_route_line_text(preview: Dictionary) -> String:
	var final_tool := _skill_forge_final_tool_label(str(preview.get("tools_label", "")).strip_edges())
	match _skill_forge_preview_route_text(final_tool):
		"Crew Order":
			return "Spec > Crew Order"
		"Forge Receipt":
			return "Spec > Forge Receipt"
	if final_tool != "":
		return "Spec > %s" % final_tool
	return "Spec"


func _set_skill_forge_trace_from_result(result: Dictionary) -> void:
	if _skill_forge_trace_label == null:
		return
	var trace_tooltip := _skill_forge_result_trace_tooltip(result)
	_skill_forge_trace_label.text = _skill_forge_result_trace_text(result)
	_skill_forge_trace_label.tooltip_text = trace_tooltip
	var trace_color := _skill_forge_result_trace_color(result)
	_skill_forge_trace_label.add_theme_color_override("font_color", trace_color)
	var run: Dictionary = result.get("run", {})
	_set_skill_forge_detail_line(
		_skill_forge_run_detail_text(str(run.get("agent_name", "")), run.get("target_tile", Vector2i(-1, -1)), run.get("source_context", {})),
		trace_tooltip,
		trace_color
	)
	_set_skill_forge_route_line(_skill_forge_result_route_line_text(result), trace_tooltip, trace_color)
	_set_skill_forge_ref_line(_skill_forge_ref_line_text(str(run.get("id", "")), str(result.get("drafted_order_id", ""))), trace_tooltip, Color("#6f8568"))
	_set_skill_forge_stage_line(
		_skill_forge_result_stage_line_text(result),
		str(run.get("skill_name", "Skill Run")),
		trace_tooltip,
		trace_color
	)
	_set_skill_forge_next_line(_skill_forge_result_next_line_text(result), trace_tooltip, Color("#6f8568"))
	_set_skill_forge_receipt_line(_skill_forge_result_receipt_line_text(result), trace_tooltip, trace_color)
	_set_skill_forge_drift_line(_skill_forge_result_drift_line_text(result), trace_tooltip, Color("#8a503e"))
	_refresh_skill_forge_history_label()


func _skill_forge_result_trace_text(result: Dictionary) -> String:
	var status := str(result.get("status", "")).strip_edges()
	var directive: Dictionary = result.get("directive", {})
	if directive.is_empty():
		return "Spec > Blocked Receipt" if status == "blocked" else "Spec > Receipt"

	var directive_kind := str(directive.get("kind", "")).strip_edges()
	var has_order := str(result.get("drafted_order_id", "")).strip_edges() != ""
	if directive_kind == "work_order_directive":
		if has_order:
			return "Spec > Directive > Work Order > Harness Receipt" if status in ["passed", "failed"] else "Spec > Directive > Work Order"
		return "Spec > Directive > Order Blocked"
	return "Spec > Directive > Forge Receipt"


func _skill_forge_result_route_line_text(result: Dictionary) -> String:
	var status := str(result.get("status", "")).strip_edges()
	var directive: Dictionary = result.get("directive", {})
	if directive.is_empty():
		return "Spec > Blocked Receipt" if status == "blocked" else "Spec > Receipt"
	if _skill_forge_result_has_blocked_order(result):
		return "Spec > Order Blocked"

	var directive_kind := str(directive.get("kind", "")).strip_edges()
	var has_order := str(result.get("drafted_order_id", "")).strip_edges() != ""
	if directive_kind == "work_order_directive":
		if has_order:
			return "Spec > Crew Order > Harness Receipt" if status in ["passed", "failed"] else "Spec > Crew Order"
		return "Spec > Order Blocked"
	if directive_kind == "skill_directive":
		return "Spec > Forge Receipt"
	return "Spec > Directive"


func _skill_forge_result_trace_tooltip(result: Dictionary) -> String:
	var run: Dictionary = result.get("run", {})
	var directive: Dictionary = result.get("directive", {})
	var skill_name := str(run.get("skill_name", "Skill Run")).strip_edges()
	var action := str(directive.get("action", run.get("action", ""))).strip_edges()
	var directive_kind := str(directive.get("kind", "")).strip_edges()
	var order_label := str(result.get("drafted_order_label", "")).strip_edges()
	var blocked_reason := str(result.get("drafted_order_blocked_reason", "")).strip_edges()
	var blocked_detail := str(result.get("drafted_order_blocked_detail", "")).strip_edges()
	var detail := str(run.get("result_detail", "")).strip_edges()
	var text := "Forge trace for %s" % (skill_name if skill_name != "" else "Skill Run")
	text += _skill_forge_context_trace_suffix(
		str(run.get("agent_name", "")),
		run.get("target_tile", Vector2i(-1, -1)),
		run.get("source_context", {})
	)
	text += _skill_forge_identity_trace_suffix(str(run.get("id", "")), str(result.get("drafted_order_id", "")))
	var stage := _skill_forge_result_history_stage(result)
	if stage != "":
		text += " | Stage: %s" % stage
	var route_text := _skill_forge_result_route_line_text(result)
	if route_text != "":
		text += " | Run Route: %s" % route_text
	var next_step := _skill_forge_result_next_line_text(result)
	if next_step != "":
		text += " | Next Step: %s" % next_step
	if directive_kind != "":
		text += " | Directive: %s" % directive_kind
	if action != "":
		text += " | Tool: %s" % action
	if directive_kind == "skill_directive":
		text += " | receipt-only until this action has a crew-order path"
	if order_label != "":
		text += " | work order %s" % order_label
	if blocked_detail != "":
		text += " | order blocked: %s" % blocked_detail
	elif blocked_reason != "":
		text += " | order blocked: %s" % blocked_reason
	if detail != "":
		text += " | Run Receipt: %s" % detail
	text += _skill_forge_history_tooltip_suffix()
	return text


func _skill_forge_result_trace_color(result: Dictionary) -> Color:
	if _skill_forge_result_has_blocked_order(result):
		return Color("#8a503e")
	match str(result.get("status", "")).strip_edges():
		"blocked", "failed":
			return Color("#8a503e")
		"passed":
			return Color("#4f7a3a")
	return Color("#4f6f8f")


func _skill_forge_result_has_blocked_order(result: Dictionary) -> bool:
	return str(result.get("drafted_order_blocked_reason", "")).strip_edges() != "" or str(result.get("drafted_order_blocked_detail", "")).strip_edges() != ""


func _skill_forge_final_tool_label(tools_label: String) -> String:
	if tools_label == "":
		return ""
	var parts := tools_label.split(" -> ", false)
	if parts.is_empty():
		return tools_label
	return str(parts[parts.size() - 1]).strip_edges()


func _skill_forge_context_trace_suffix(agent_name: String, target_value, source_context) -> String:
	var parts: Array[String] = []
	agent_name = agent_name.strip_edges()
	if agent_name != "":
		parts.append("agent %s" % agent_name)

	var target_text := _skill_forge_trace_tile_text(target_value)
	if target_text != "":
		parts.append("target %s" % target_text)

	var source_text := _skill_forge_source_context_text(source_context)
	if source_text != "":
		parts.append("source %s" % source_text)

	if parts.is_empty():
		return ""
	return " | Run Context: %s" % " | ".join(parts)


func _skill_forge_identity_trace_suffix(run_id: String, order_id: String = "") -> String:
	var parts: Array[String] = []
	run_id = run_id.strip_edges()
	order_id = order_id.strip_edges()
	if run_id != "":
		parts.append("run %s" % run_id)
	if order_id != "":
		parts.append("order %s" % order_id)
	if parts.is_empty():
		return ""
	return " | Run Ref: %s" % " | ".join(parts)


func _skill_forge_ref_line_text(run_id: String, order_id: String = "") -> String:
	var parts: Array[String] = []
	run_id = run_id.strip_edges()
	order_id = order_id.strip_edges()
	if run_id != "":
		parts.append("run %s" % run_id)
	if order_id != "":
		parts.append("order %s" % order_id)
	return " | ".join(parts)


func _skill_forge_trace_tile_text(value) -> String:
	var tile := Vector2i(-1, -1)
	match typeof(value):
		TYPE_VECTOR2I:
			tile = value
		TYPE_ARRAY:
			if value.size() >= 2:
				tile = Vector2i(int(value[0]), int(value[1]))
		TYPE_DICTIONARY:
			tile = Vector2i(int(value.get("x", -1)), int(value.get("y", -1)))
	if tile == Vector2i(-1, -1):
		return ""
	return "%s,%s" % [tile.x, tile.y]


func _skill_forge_source_context_text(source_context) -> String:
	if typeof(source_context) != TYPE_DICTIONARY:
		return ""
	var source := str(source_context.get("source", "")).strip_edges()
	var label := str(source_context.get("label", "")).strip_edges()
	if label != "":
		return label if source == "" or source == "skill_forge" else "%s: %s" % [source.replace("_", " ").capitalize(), label]
	return source.replace("_", " ").capitalize()


func _skill_forge_run_detail_text(agent_name: String, target_value, source_context) -> String:
	var primary_parts: Array[String] = []
	agent_name = agent_name.strip_edges()
	if agent_name != "":
		primary_parts.append("agent %s" % agent_name)

	var target_text := _skill_forge_trace_tile_text(target_value)
	if target_text != "":
		primary_parts.append("target %s" % target_text)

	var source_text := _skill_forge_source_context_text(source_context)
	if source_text != "":
		primary_parts.append("source %s" % source_text)
	return " | ".join(primary_parts)


func _record_skill_forge_history_from_result(result: Dictionary) -> void:
	var status := str(result.get("status", "")).strip_edges()
	var has_blocked_order := _skill_forge_result_has_blocked_order(result)
	if status not in ["passed", "failed", "blocked"] and not has_blocked_order:
		return

	var run: Dictionary = result.get("run", {})
	var skill_name := str(run.get("skill_name", "Skill Run")).strip_edges()
	if skill_name == "":
		skill_name = "Skill Run"
	var detail := str(run.get("result_detail", "")).strip_edges()
	if has_blocked_order:
		detail = str(result.get("drafted_order_blocked_detail", result.get("drafted_order_blocked_reason", ""))).strip_edges()
	elif detail == "" and status == "blocked":
		detail = _skill_forge_first_issue_text(result)

	var text := "Order Blocked %s" % skill_name if has_blocked_order else "%s %s" % [_skill_forge_status_text(status), skill_name]
	var history_stage := _skill_forge_result_history_stage(result)
	if history_stage != "" and not has_blocked_order:
		text += " (%s)" % history_stage
	if status == "blocked":
		var drift_level := str(run.get("drift", {}).get("level", "")).strip_edges()
		if drift_level != "" and drift_level != "steady":
			text += " [Drift %s]" % drift_level
	if detail != "":
		text += ": %s" % detail
	if status in ["blocked", "failed"]:
		var suggestion := str(run.get("failure_suggestion", "")).strip_edges()
		if suggestion != "":
			text += " Fix: %s" % suggestion
	_record_skill_forge_history_text(text)


func _skill_forge_result_history_stage(result: Dictionary) -> String:
	if _skill_forge_result_has_blocked_order(result):
		return "Order Blocked"

	var status := str(result.get("status", "")).strip_edges()
	var directive: Dictionary = result.get("directive", {})
	if directive.is_empty():
		return "Spec Blocked" if status == "blocked" else ""

	var directive_kind := str(directive.get("kind", "")).strip_edges()
	if directive_kind == "work_order_directive" and str(result.get("drafted_order_id", "")).strip_edges() != "":
		return "Harness Receipt" if status in ["passed", "failed"] else "Work Order"
	if directive_kind == "skill_directive":
		return "Forge Receipt"
	return "Forge Receipt" if directive_kind != "" else ""


func _skill_forge_result_stage_line_text(result: Dictionary) -> String:
	var stage := _skill_forge_result_history_stage(result)
	if stage != "":
		return stage
	return _skill_forge_status_text(str(result.get("status", "")).strip_edges())


func _skill_forge_result_next_line_text(result: Dictionary) -> String:
	if _skill_forge_result_has_blocked_order(result):
		return "Pick valid target"

	var status := str(result.get("status", "")).strip_edges()
	if status == "blocked":
		return "Use Fix"
	if status == "failed":
		return "Revise and rerun"
	if status == "started":
		return "Harness Receipt"

	var directive: Dictionary = result.get("directive", {})
	var directive_kind := str(directive.get("kind", "")).strip_edges()
	if status == "passed" and directive_kind == "work_order_directive" and str(result.get("drafted_order_id", "")).strip_edges() != "":
		return "Send crew order"
	if status == "passed" and directive_kind == "skill_directive":
		return "Field Log receipt"
	return ""


func _skill_forge_result_receipt_line_text(result: Dictionary) -> String:
	if _skill_forge_result_has_blocked_order(result):
		return str(result.get("drafted_order_blocked_detail", result.get("drafted_order_blocked_reason", ""))).strip_edges()

	var status := str(result.get("status", "")).strip_edges()
	var run: Dictionary = result.get("run", {})
	var detail := str(run.get("result_detail", "")).strip_edges()
	if detail != "":
		return detail
	if status == "blocked":
		return _skill_forge_first_issue_text(result)
	if status == "started":
		return "harness started"
	return ""


func _skill_forge_result_drift_line_text(result: Dictionary) -> String:
	var run: Dictionary = result.get("run", {})
	var drift_level := str(run.get("drift", {}).get("level", "")).strip_edges()
	if drift_level == "" or drift_level == "steady":
		return ""
	var suggestion := str(run.get("failure_suggestion", "")).strip_edges()
	if suggestion != "":
		return "%s | Fix: %s" % [drift_level, suggestion]
	return drift_level


func _skill_forge_work_stage_next_text(status_text: String) -> String:
	match status_text.strip_edges():
		"Crew Queued":
			return "Wait for agent receipt"
		"Crew Waiting":
			return "Wait for free crew"
	return ""


func _skill_forge_work_stage_route_text(status_text: String) -> String:
	match status_text.strip_edges():
		"Crew Queued":
			return "Spec > Crew Order > Crew Queued"
		"Crew Waiting":
			return "Spec > Crew Order > Crew Waiting"
	return "Spec > Crew Order"


func _skill_forge_work_stage_receipt_text(status_text: String, order_label: String) -> String:
	order_label = order_label.strip_edges()
	match status_text.strip_edges():
		"Crew Queued":
			return "Forge order queued; awaiting agent receipt: %s" % order_label if order_label != "" else "Forge order queued; awaiting agent receipt"
		"Crew Waiting":
			return "Forge order waiting; no free crew yet: %s" % order_label if order_label != "" else "Forge order waiting; no free crew yet"
	return ""


func _record_skill_forge_work_stage_history(order: Dictionary, status_text: String) -> void:
	status_text = status_text.strip_edges()
	if status_text not in ["Crew Queued", "Crew Waiting"]:
		return
	var skill_name := str(order.get("skill_name", order.get("preference_label", "Skill Run"))).strip_edges()
	if skill_name == "":
		skill_name = "Skill Run"
	_record_skill_forge_history_text("%s %s" % [status_text, skill_name])


func _record_skill_forge_history_text(text: String) -> void:
	text = text.strip_edges()
	if text == "":
		return
	if not _skill_forge_history_entries.is_empty() and _skill_forge_history_entries[0] == text:
		return
	_skill_forge_history_entries.push_front(text)
	while _skill_forge_history_entries.size() > 3:
		_skill_forge_history_entries.pop_back()
	_refresh_skill_forge_history_label()


func _refresh_skill_forge_history_label() -> void:
	if _skill_forge_history_label == null:
		return
	var text := _skill_forge_visible_history_text()
	_skill_forge_history_label.text = text
	_skill_forge_history_label.visible = text != ""
	_skill_forge_history_label.tooltip_text = _skill_forge_full_history_text()


func _set_skill_forge_stage_line(stage_text: String, detail_text: String, tooltip_text: String = "", color: Color = Color("#4f6f8f")) -> void:
	if _skill_forge_stage_label == null:
		return
	stage_text = stage_text.strip_edges()
	detail_text = detail_text.strip_edges()
	if stage_text == "":
		_skill_forge_stage_label.text = ""
		_skill_forge_stage_label.visible = false
		_skill_forge_stage_label.tooltip_text = ""
		return
	var text := "Stage: %s" % stage_text
	if detail_text != "":
		text += " | %s" % detail_text
	_skill_forge_stage_label.text = text
	_skill_forge_stage_label.visible = true
	_skill_forge_stage_label.tooltip_text = tooltip_text
	_skill_forge_stage_label.add_theme_color_override("font_color", color)


func _set_skill_forge_detail_line(detail_text: String, tooltip_text: String = "", color: Color = Color("#4f6f8f")) -> void:
	if _skill_forge_detail_label == null:
		return
	detail_text = detail_text.strip_edges()
	if detail_text == "":
		_skill_forge_detail_label.text = ""
		_skill_forge_detail_label.visible = false
		_skill_forge_detail_label.tooltip_text = ""
		return
	_skill_forge_detail_label.text = "Run Context: %s" % detail_text
	_skill_forge_detail_label.visible = true
	_skill_forge_detail_label.tooltip_text = tooltip_text
	_skill_forge_detail_label.add_theme_color_override("font_color", color)


func _set_skill_forge_route_line(route_text: String, tooltip_text: String = "", color: Color = Color("#4f6f8f")) -> void:
	if _skill_forge_route_label == null:
		return
	route_text = route_text.strip_edges()
	if route_text == "":
		_skill_forge_route_label.text = ""
		_skill_forge_route_label.visible = false
		_skill_forge_route_label.tooltip_text = ""
		return
	_skill_forge_route_label.text = "Run Route: %s" % route_text
	_skill_forge_route_label.visible = true
	_skill_forge_route_label.tooltip_text = tooltip_text
	_skill_forge_route_label.add_theme_color_override("font_color", color)


func _set_skill_forge_ref_line(ref_text: String, tooltip_text: String = "", color: Color = Color("#6f8568")) -> void:
	if _skill_forge_ref_label == null:
		return
	ref_text = ref_text.strip_edges()
	if ref_text == "":
		_skill_forge_ref_label.text = ""
		_skill_forge_ref_label.visible = false
		_skill_forge_ref_label.tooltip_text = ""
		return
	_skill_forge_ref_label.text = "Run Ref: %s" % ref_text
	_skill_forge_ref_label.visible = true
	_skill_forge_ref_label.tooltip_text = tooltip_text
	_skill_forge_ref_label.add_theme_color_override("font_color", color)


func _set_skill_forge_next_line(next_step_text: String, tooltip_text: String = "", color: Color = Color("#6f8568")) -> void:
	if _skill_forge_next_label == null:
		return
	next_step_text = next_step_text.strip_edges()
	if next_step_text == "":
		_skill_forge_next_label.text = ""
		_skill_forge_next_label.visible = false
		_skill_forge_next_label.tooltip_text = ""
		return
	_skill_forge_next_label.text = "Next Step: %s" % next_step_text
	_skill_forge_next_label.visible = true
	_skill_forge_next_label.tooltip_text = tooltip_text
	_skill_forge_next_label.add_theme_color_override("font_color", color)


func _set_skill_forge_receipt_line(receipt_text: String, tooltip_text: String = "", color: Color = Color("#6f8568")) -> void:
	if _skill_forge_receipt_label == null:
		return
	receipt_text = _skill_forge_compact_receipt_text(receipt_text)
	if receipt_text == "":
		_skill_forge_receipt_label.text = ""
		_skill_forge_receipt_label.visible = false
		_skill_forge_receipt_label.tooltip_text = ""
		return
	_skill_forge_receipt_label.text = "Run Receipt: %s" % receipt_text
	_skill_forge_receipt_label.visible = true
	_skill_forge_receipt_label.tooltip_text = tooltip_text
	_skill_forge_receipt_label.add_theme_color_override("font_color", color)


func _skill_forge_compact_receipt_text(receipt_text: String) -> String:
	receipt_text = receipt_text.strip_edges()
	if receipt_text.ends_with("."):
		receipt_text = receipt_text.substr(0, receipt_text.length() - 1)
	if receipt_text.length() > 72:
		return "%s..." % receipt_text.substr(0, 69)
	return receipt_text


func _set_skill_forge_drift_line(drift_text: String, tooltip_text: String = "", color: Color = Color("#8a503e")) -> void:
	if _skill_forge_drift_label == null:
		return
	drift_text = drift_text.strip_edges()
	if drift_text == "":
		_skill_forge_drift_label.text = ""
		_skill_forge_drift_label.visible = false
		_skill_forge_drift_label.tooltip_text = ""
		return
	_skill_forge_drift_label.text = "Forge Drift: %s" % drift_text
	_skill_forge_drift_label.visible = true
	_skill_forge_drift_label.tooltip_text = tooltip_text
	_skill_forge_drift_label.add_theme_color_override("font_color", color)


func _skill_forge_visible_history_text() -> String:
	if _skill_forge_history_entries.is_empty():
		return ""
	var entries: Array[String] = []
	for entry in _skill_forge_history_entries:
		entries.append(str(entry))
	entries.reverse()

	var shared_skill := ""
	var has_mixed_or_unknown_skill := false
	for entry in entries:
		var skill_name := _skill_forge_history_skill_name(str(entry))
		if skill_name == "":
			has_mixed_or_unknown_skill = true
			break
		if shared_skill == "":
			shared_skill = skill_name
		elif shared_skill != skill_name:
			has_mixed_or_unknown_skill = true
			break

	var compact_entries: Array[String] = []
	for entry in entries:
		var compact_entry := _skill_forge_compact_history_entry(str(entry))
		if not has_mixed_or_unknown_skill and shared_skill != "":
			compact_entry = _skill_forge_compact_history_step(str(entry))
		if compact_entry != "":
			compact_entries.append(compact_entry)
	if compact_entries.is_empty():
		return ""
	if not has_mixed_or_unknown_skill and shared_skill != "":
		return "Run Trail: %s: %s" % [shared_skill, " > ".join(compact_entries)]
	return "Run Trail: %s" % " > ".join(compact_entries)


func _skill_forge_full_history_text() -> String:
	if _skill_forge_history_entries.is_empty():
		return ""
	var entries := _skill_forge_chronological_history_entries()
	var latest_detail := str(entries[entries.size() - 1]).strip_edges()
	if latest_detail == "":
		return "Run History: %s" % " ; ".join(entries)
	return "Current Run Detail: %s | Run History: %s" % [latest_detail, " ; ".join(entries)]


func _skill_forge_compact_history_entry(text: String) -> String:
	text = text.strip_edges()
	var detail_index := text.find(":")
	if detail_index != -1:
		text = text.substr(0, detail_index).strip_edges()
	return text


func _skill_forge_history_skill_name(text: String) -> String:
	text = text.strip_edges()
	for prefix in ["Order Blocked ", "Crew Queued ", "Crew Waiting ", "Agent Receipt ", "Passed ", "Failed ", "Blocked "]:
		var prefix_text := str(prefix)
		if text.begins_with(prefix_text):
			return _skill_forge_history_head(text.substr(prefix_text.length()))
	return ""


func _skill_forge_compact_history_step(text: String) -> String:
	text = text.strip_edges()
	for prefix in ["Order Blocked ", "Crew Queued ", "Crew Waiting ", "Agent Receipt "]:
		var prefix_text := str(prefix)
		if text.begins_with(prefix_text):
			return prefix_text.strip_edges()
	for prefix in ["Passed ", "Failed ", "Blocked "]:
		var prefix_text := str(prefix)
		if text.begins_with(prefix_text):
			var status_text := prefix_text.strip_edges()
			var stage_text := _skill_forge_parenthetical_history_stage(text)
			if stage_text != "":
				return "%s (%s)" % [status_text, stage_text]
			return status_text
	return _skill_forge_compact_history_entry(text)


func _skill_forge_history_head(text: String) -> String:
	text = text.strip_edges()
	var end_index := text.length()
	for marker in [" (", " [", ":"]:
		var marker_index := text.find(marker)
		if marker_index != -1 and marker_index < end_index:
			end_index = marker_index
	return text.substr(0, end_index).strip_edges()


func _skill_forge_parenthetical_history_stage(text: String) -> String:
	var start_index := text.find("(")
	if start_index == -1:
		return ""
	var end_index := text.find(")", start_index)
	if end_index == -1 or end_index <= start_index:
		return ""
	return text.substr(start_index + 1, end_index - start_index - 1).strip_edges()


func _skill_forge_history_tooltip_suffix() -> String:
	if _skill_forge_history_entries.is_empty():
		return ""
	return " | %s" % _skill_forge_full_history_text()


func _skill_forge_chronological_history_entries() -> Array[String]:
	var entries: Array[String] = []
	for entry in _skill_forge_history_entries:
		entries.append(str(entry))
	entries.reverse()
	return entries


func _add_work_order_action_button(parent: HBoxContainer, action_id: String, label: String, tooltip: String) -> void:
	var button := Button.new()
	button.text = label
	button.tooltip_text = tooltip
	button.custom_minimum_size = Vector2(0, 30)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.add_theme_font_size_override("font_size", 10)
	button.add_theme_color_override("font_color", Color("#4b4337"))
	button.add_theme_stylebox_override("normal", _crew_order_button_style(false))
	button.add_theme_stylebox_override("hover", _crew_order_button_style(true))
	button.add_theme_stylebox_override("pressed", _crew_order_button_style(true))
	button.pressed.connect(func() -> void:
		var next_action := "" if _active_work_order_tool == action_id else action_id
		work_order_tool_selected.emit(next_action)
	)
	parent.add_child(button)
	_work_order_action_buttons[action_id] = button


func _add_empty_work_order_row(parent: VBoxContainer) -> void:
	var label := Label.new()
	label.text = "No marked jobs"
	label.custom_minimum_size = Vector2(0, 18)
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color("#8a806f"))
	parent.add_child(label)


func _add_empty_crafting_demand_row(parent: VBoxContainer) -> void:
	var label := Label.new()
	label.text = "No crew demands"
	label.custom_minimum_size = Vector2(0, 18)
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color("#8a806f"))
	parent.add_child(label)


func _add_empty_crew_mission_row(parent: VBoxContainer) -> void:
	var label := Label.new()
	label.text = "No missions"
	label.custom_minimum_size = Vector2(0, 16)
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color("#8a806f"))
	parent.add_child(label)


func _add_crew_mission_row(parent: VBoxContainer, mission: Dictionary) -> void:
	var mission_id := str(mission.get("id", ""))
	var row_panel := PanelContainer.new()
	row_panel.custom_minimum_size = Vector2(0, 38)
	row_panel.add_theme_stylebox_override("panel", _crew_mission_row_style(mission))
	_configure_crew_mission_row_target(row_panel, str(mission.get("current_demand_id", "")), str(mission.get("current_order_id", "")))
	row_panel.gui_input.connect(func(event: InputEvent) -> void:
		_on_crew_mission_row_input(mission_id, event)
	)
	parent.add_child(row_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_bottom", 5)
	row_panel.add_child(margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 1)
	margin.add_child(stack)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	stack.add_child(top)

	var label := Label.new()
	label.text = str(mission.get("label", "Crew Mission"))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color("#3f372d"))
	top.add_child(label)

	var status := Label.new()
	status.text = str(mission.get("status_text", "Step"))
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status.add_theme_font_size_override("font_size", 10)
	status.add_theme_color_override("font_color", _crew_mission_status_color(mission))
	top.add_child(status)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 6)
	stack.add_child(bottom)

	var agent := Label.new()
	agent.text = str(mission.get("agent_name", "Crew"))
	agent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	agent.custom_minimum_size = Vector2(62, 0)
	agent.add_theme_font_size_override("font_size", 9)
	agent.add_theme_color_override("font_color", Color("#7a6f60"))
	bottom.add_child(agent)

	var context := Label.new()
	context.text = _mission_preference_context_text(mission)
	context.visible = context.text != ""
	context.mouse_filter = Control.MOUSE_FILTER_IGNORE
	context.custom_minimum_size = Vector2(52, 0)
	context.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	context.add_theme_font_size_override("font_size", 9)
	context.add_theme_color_override("font_color", _mission_preference_color(mission))
	context.tooltip_text = _mission_preference_tooltip(mission)
	bottom.add_child(context)

	var step := Label.new()
	step.text = str(mission.get("current_step_label", ""))
	step.mouse_filter = Control.MOUSE_FILTER_IGNORE
	step.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	step.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	step.add_theme_font_size_override("font_size", 9)
	step.add_theme_color_override("font_color", Color("#5f6478"))
	bottom.add_child(step)

	_crew_mission_rows[mission_id] = {
		"panel": row_panel,
		"label": label,
		"agent": agent,
		"context": context,
		"status": status,
		"step": step
	}


func _configure_crew_mission_row_target(row_panel: PanelContainer, demand_id: String, order_id: String = "") -> void:
	row_panel.set_meta("mission_demand_id", demand_id)
	row_panel.set_meta("mission_order_id", order_id)
	if demand_id == "":
		row_panel.tooltip_text = ""
		row_panel.mouse_default_cursor_shape = Control.CURSOR_ARROW
		row_panel.mouse_filter = Control.MOUSE_FILTER_PASS
		return
	row_panel.tooltip_text = "Focus step and send order" if order_id != "" else "Focus mission step"
	row_panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	row_panel.mouse_filter = Control.MOUSE_FILTER_STOP


func _add_crafting_demand_row(parent: VBoxContainer, demand: Dictionary) -> void:
	var demand_id := str(demand.get("id", ""))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	parent.add_child(row)

	var label := Label.new()
	label.text = str(demand.get("label", "Crew Demand"))
	label.custom_minimum_size = Vector2(88, 0)
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color("#3f372d"))
	row.add_child(label)

	var status := Label.new()
	status.text = str(demand.get("status_text", "Needs kit"))
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.add_theme_font_size_override("font_size", 10)
	status.add_theme_color_override("font_color", Color("#746b5f"))
	row.add_child(status)

	var preference := Label.new()
	preference.text = _demand_preference_context_text(demand)
	preference.visible = preference.text != ""
	preference.custom_minimum_size = Vector2(44, 0)
	preference.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	preference.add_theme_font_size_override("font_size", 9)
	preference.add_theme_color_override("font_color", Color("#7b5aa6") if str(demand.get("preference_source", "")) == "truce" else Color("#5f7f39"))
	preference.tooltip_text = _demand_preference_tooltip(demand)
	row.add_child(preference)

	var mission := Label.new()
	mission.text = _demand_mission_context_text(demand)
	mission.visible = mission.text != ""
	mission.custom_minimum_size = Vector2(52, 0)
	mission.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	mission.add_theme_font_size_override("font_size", 9)
	mission.add_theme_color_override("font_color", Color("#6b6aa8"))
	mission.tooltip_text = _demand_mission_tooltip(demand)
	row.add_child(mission)

	var reward := Label.new()
	reward.text = str(demand.get("reward_text", ""))
	reward.visible = reward.text != ""
	reward.custom_minimum_size = Vector2(70, 0)
	reward.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	reward.add_theme_font_size_override("font_size", 9)
	reward.add_theme_color_override("font_color", Color("#5f7f39"))
	row.add_child(reward)

	var action_button: Button = null
	if typeof(demand.get("target_tile", null)) == TYPE_VECTOR2I:
		action_button = Button.new()
		action_button.text = "Go"
		action_button.tooltip_text = "Focus demand target"
		action_button.custom_minimum_size = Vector2(36, 19)
		action_button.focus_mode = Control.FOCUS_NONE
		action_button.add_theme_font_size_override("font_size", 10)
		action_button.add_theme_color_override("font_color", Color("#5d4938"))
		action_button.add_theme_stylebox_override("normal", _craft_button_style(true))
		action_button.add_theme_stylebox_override("hover", _craft_button_style(true))
		action_button.add_theme_stylebox_override("pressed", _craft_button_style(true))
		action_button.pressed.connect(func() -> void:
			sound_requested.emit("ui_click")
			crafting_demand_target_requested.emit(demand_id)
		)
		row.add_child(action_button)
	elif str(demand.get("kind", "deliver_item")) == "deliver_item":
		var demand_status := str(demand.get("status", "open"))
		var can_give := bool(demand.get("has_required_item", false))
		var can_prep := bool(demand.get("can_craft_required_item", false))
		var can_act := demand_status == "open" and (can_give or can_prep)
		var missing_text := str(demand.get("missing_resource_text", ""))
		action_button = Button.new()
		if demand_status != "open":
			action_button.text = "Done"
			action_button.tooltip_text = "Demand handled"
		elif can_give:
			action_button.text = "Give"
			action_button.tooltip_text = "Deliver supply"
		elif can_prep:
			action_button.text = "Prep"
			action_button.tooltip_text = "Prepare and deliver supply"
		else:
			action_button.text = "Wait"
			action_button.tooltip_text = "Needs %s" % missing_text if missing_text != "" else "Missing supply ingredients"
			status.tooltip_text = action_button.tooltip_text
		action_button.custom_minimum_size = Vector2(44, 19)
		action_button.focus_mode = Control.FOCUS_NONE
		action_button.disabled = not can_act
		action_button.add_theme_font_size_override("font_size", 10)
		action_button.add_theme_color_override("font_color", Color("#2d3b1d") if can_act else Color("#8c8274"))
		action_button.add_theme_color_override("font_disabled_color", Color("#8c8274"))
		action_button.add_theme_stylebox_override("normal", _craft_button_style(can_act))
		action_button.add_theme_stylebox_override("hover", _craft_button_style(true))
		action_button.add_theme_stylebox_override("pressed", _craft_button_style(true))
		action_button.pressed.connect(func() -> void:
			sound_requested.emit("ui_click")
			crafting_demand_requested.emit(demand_id)
		)
		row.add_child(action_button)

	_crafting_demand_rows[demand_id] = {
		"label": label,
		"status": status,
		"preference": preference,
		"mission": mission,
		"reward": reward,
		"button": action_button
	}


func _demand_preference_context_text(demand: Dictionary) -> String:
	match str(demand.get("preference_source", "")):
		"remembered_help":
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
	return ""


func _mission_preference_context_text(mission: Dictionary) -> String:
	match str(mission.get("preference_source", "")):
		"remembered_help":
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
	return ""


func _mission_preference_tooltip(mission: Dictionary) -> String:
	var label := str(mission.get("preference_label", "")).strip_edges()
	match str(mission.get("preference_source", "")):
		"remembered_help":
			return "Remembered help: %s" % label if label != "" else "Influenced by remembered help"
		"truce":
			return "Active truce: %s" % label if label != "" else "Influenced by an active truce"
		"repeated_help":
			return "Repeated help: %s" % label if label != "" else "Influenced by repeated help"
		"completed_order":
			return "Completed crew order: %s" % label if label != "" else "Influenced by a completed crew order"
		"completed_mission":
			return "Mission momentum: %s" % label if label != "" else "Influenced by mission momentum"
		"ignored_ask":
			return "Ignored ask: %s" % label if label != "" else "Influenced by an ignored ask"
		"held_truce":
			return "Held truce: %s" % label if label != "" else "Influenced by a held truce"
	return ""


func _mission_preference_color(mission: Dictionary) -> Color:
	match str(mission.get("preference_source", "")):
		"truce", "held_truce":
			return Color("#7b5aa6")
		"ignored_ask":
			return Color("#8a503e")
		"completed_order", "completed_mission":
			return Color("#4f6f8f")
	return Color("#5f7f39")


func _demand_preference_tooltip(demand: Dictionary) -> String:
	var label := str(demand.get("preference_label", "")).strip_edges()
	var origin_suffix := _preference_origin_tooltip_suffix(demand)
	match str(demand.get("preference_source", "")):
		"remembered_help":
			return _with_origin_suffix("Remembered help: %s" % label if label != "" else "Influenced by remembered help", origin_suffix)
		"truce":
			return _with_origin_suffix("Active truce: %s" % label if label != "" else "Influenced by an active truce", origin_suffix)
		"repeated_help":
			return _with_origin_suffix("Repeated help: %s" % label if label != "" else "Influenced by repeated help", origin_suffix)
		"completed_order":
			return _with_origin_suffix("Completed crew order: %s" % label if label != "" else "Influenced by a completed crew order", origin_suffix)
		"completed_mission":
			return _with_origin_suffix("Mission momentum: %s" % label if label != "" else "Influenced by mission momentum", origin_suffix)
		"ignored_ask":
			return _with_origin_suffix("Ignored ask: %s" % label if label != "" else "Influenced by an ignored ask", origin_suffix)
		"held_truce":
			return _with_origin_suffix("Held truce: %s" % label if label != "" else "Influenced by a held truce", origin_suffix)
	return str(demand.get("reason", ""))


func _preference_origin_tooltip_suffix(source: Dictionary) -> String:
	var origin_context := _mission_momentum_origin_context_text(
		str(source.get("preference_origin_source", "")),
		str(source.get("preference_origin_label", ""))
	)
	if origin_context == "":
		return ""
	return "from %s" % origin_context


func _with_origin_suffix(base_text: String, origin_suffix: String) -> String:
	if origin_suffix == "":
		return base_text
	return "%s (%s)" % [base_text, origin_suffix]


func _demand_mission_context_text(demand: Dictionary) -> String:
	if str(demand.get("mission_id", "")).strip_edges() == "":
		return ""
	var progress := _demand_mission_progress_fraction(demand)
	if progress == "":
		return "Mission"
	return "Step %s" % progress


func _demand_mission_tooltip(demand: Dictionary) -> String:
	var mission_label := str(demand.get("mission_label", "")).strip_edges()
	var step_label := str(demand.get("mission_step_label", "")).strip_edges()
	var context_text := _demand_mission_context_text(demand)
	if mission_label == "" and step_label == "":
		return context_text
	if mission_label == "":
		return "%s: %s" % [context_text, step_label]
	if step_label == "":
		return "%s: %s" % [mission_label, context_text]
	return "%s: %s - %s" % [mission_label, context_text, step_label]


func _demand_mission_progress_fraction(demand: Dictionary) -> String:
	if str(demand.get("mission_id", "")).strip_edges() == "":
		return ""
	var total_steps := int(demand.get("mission_total_steps", 0))
	var step_index := int(demand.get("mission_step_index", -1))
	if total_steps <= 0 or step_index < 0:
		return ""
	return "%s/%s" % [step_index + 1, total_steps]


func _work_order_preference_context_text(order: Dictionary) -> String:
	match _work_order_preference_source(order):
		"remembered_help", "memory":
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
		"skill_forge":
			return "Forge"
	return ""


func _work_order_preference_tooltip(order: Dictionary) -> String:
	var label := _work_order_preference_label(order)
	var origin_suffix := _preference_origin_tooltip_suffix(order)
	match _work_order_preference_source(order):
		"remembered_help", "memory":
			return _with_origin_suffix("Remembered help: %s" % label if label != "" else "Influenced by remembered help", origin_suffix)
		"truce":
			return _with_origin_suffix("Active truce: %s" % label if label != "" else "Influenced by an active truce", origin_suffix)
		"repeated_help":
			return _with_origin_suffix("Repeated help: %s" % label if label != "" else "Influenced by repeated help", origin_suffix)
		"completed_order":
			return _with_origin_suffix("Completed crew order: %s" % label if label != "" else "Influenced by a completed crew order", origin_suffix)
		"completed_mission":
			return _with_origin_suffix("Mission momentum: %s" % label if label != "" else "Influenced by mission momentum", origin_suffix)
		"ignored_ask":
			return _with_origin_suffix("Ignored ask: %s" % label if label != "" else "Influenced by an ignored ask", origin_suffix)
		"held_truce":
			return _with_origin_suffix("Held truce: %s" % label if label != "" else "Influenced by a held truce", origin_suffix)
		"skill_forge":
			var tooltip := "Skill Forge: %s" % label if label != "" else "Drafted by Skill Forge"
			tooltip += _skill_forge_identity_trace_suffix(str(order.get("forge_run_id", "")), str(order.get("id", "")))
			var context := _skill_forge_run_detail_text(str(order.get("agent_name", "")), order.get("target_tile", Vector2i(-1, -1)), order.get("source_context", {}))
			if context != "":
				tooltip += " | Run Context: %s" % context
			var directive := str(order.get("directive_kind", "")).strip_edges()
			if directive != "":
				tooltip += " | Directive: %s" % directive
			var tool := str(order.get("action", order.get("agent_action", ""))).strip_edges()
			if tool != "":
				tooltip += " | Tool: %s" % tool
			var route := _skill_forge_work_order_route_tooltip(order)
			if route != "":
				tooltip += " | Run Route: %s" % route
			var stage := _skill_forge_work_order_stage_label(order)
			if stage != "":
				tooltip += " | Stage: %s" % stage
			var current_detail := _skill_forge_work_order_current_detail_tooltip(order)
			if current_detail != "":
				tooltip += " | Current Run Detail: %s" % current_detail
			var next_step := _skill_forge_work_order_next_tooltip(order)
			if next_step != "":
				tooltip += " | Next Step: %s" % next_step
			var receipt := _skill_forge_work_order_receipt_tooltip(order)
			if receipt != "":
				tooltip += " | Run Receipt: %s" % receipt
			return tooltip
	return ""


func _skill_forge_work_order_stage_label(order: Dictionary) -> String:
	match str(order.get("status", "ready")).strip_edges():
		"ready":
			return "Work Order Ready"
		"queued":
			return "Crew Queued"
		"waiting":
			return "Crew Waiting"
		"gathering":
			return "Crew Gathering"
		"done":
			return "Agent Receipt"
	return str(order.get("status_text", "")).strip_edges()


func _skill_forge_work_order_route_tooltip(order: Dictionary) -> String:
	match str(order.get("status", "ready")).strip_edges():
		"ready":
			return "Spec > Crew Order"
		"queued":
			return "Spec > Crew Order > Crew Queued"
		"waiting":
			return "Spec > Crew Order > Crew Waiting"
		"gathering":
			return "Spec > Crew Order > Crew Gathering"
		"done":
			return "Spec > Crew Order > Agent Receipt"
	return "Spec > Crew Order"


func _skill_forge_work_order_next_tooltip(order: Dictionary) -> String:
	match str(order.get("status", "ready")).strip_edges():
		"ready":
			return "Send crew order"
		"queued", "gathering":
			return "Wait for agent receipt"
		"waiting":
			return "Wait for free crew"
		"done":
			return "Review day summary"
	return ""


func _skill_forge_work_order_current_detail_tooltip(order: Dictionary) -> String:
	var stage := _skill_forge_work_order_stage_label(order)
	if stage == "":
		return ""
	var order_label := str(order.get("skill_name", order.get("preference_label", order.get("label", "")))).strip_edges()
	if order_label == "":
		return stage
	return "%s %s" % [stage, order_label]


func _skill_forge_work_order_receipt_tooltip(order: Dictionary) -> String:
	var order_label := str(order.get("skill_name", order.get("preference_label", order.get("label", "")))).strip_edges()
	match str(order.get("status", "ready")).strip_edges():
		"queued":
			return _skill_forge_work_stage_receipt_text("Crew Queued", order_label)
		"waiting":
			return _skill_forge_work_stage_receipt_text("Crew Waiting", order_label)
	return ""


func _work_order_preference_color(order: Dictionary) -> Color:
	match _work_order_preference_source(order):
		"truce", "held_truce":
			return Color("#7b5aa6")
		"ignored_ask":
			return Color("#8a503e")
		"completed_order", "completed_mission", "skill_forge":
			return Color("#4f6f8f")
	return Color("#5f7f39")


func _work_order_preference_source(order: Dictionary) -> String:
	var source := str(order.get("preference_source", "")).strip_edges()
	if source == "":
		source = str(order.get("social_preference_source", "")).strip_edges()
	return source


func _work_order_preference_label(order: Dictionary) -> String:
	var label := str(order.get("preference_label", "")).strip_edges()
	if label == "":
		label = str(order.get("social_preference_label", "")).strip_edges()
	return label


func _add_work_order_row(parent: VBoxContainer, order: Dictionary) -> void:
	var order_id := str(order.get("id", ""))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	parent.add_child(row)

	var label := Label.new()
	label.text = str(order.get("label", "Work Order"))
	label.custom_minimum_size = Vector2(82, 0)
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color("#3f372d"))
	row.add_child(label)

	var status := Label.new()
	status.text = "Needs mats"
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.add_theme_font_size_override("font_size", 10)
	status.add_theme_color_override("font_color", Color("#746b5f"))
	row.add_child(status)

	var preference := Label.new()
	preference.text = _work_order_preference_context_text(order)
	preference.visible = preference.text != ""
	preference.custom_minimum_size = Vector2(54, 0)
	preference.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	preference.add_theme_font_size_override("font_size", 9)
	preference.add_theme_color_override("font_color", _work_order_preference_color(order))
	preference.tooltip_text = _work_order_preference_tooltip(order)
	row.add_child(preference)

	var button := Button.new()
	button.text = "Ask"
	button.custom_minimum_size = Vector2(56, 19)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 10)
	button.add_theme_color_override("font_color", Color("#8c8274"))
	button.add_theme_color_override("font_disabled_color", Color("#8c8274"))
	button.add_theme_stylebox_override("normal", _craft_button_style(false))
	button.add_theme_stylebox_override("hover", _craft_button_style(true))
	button.add_theme_stylebox_override("pressed", _craft_button_style(true))
	button.pressed.connect(func() -> void:
		sound_requested.emit("ui_click")
		_on_work_order_row_button_pressed(order_id)
	)
	row.add_child(button)

	_work_order_rows[order_id] = {
		"label": label,
		"status": status,
		"preference": preference,
		"button": button,
		"intent": "send"
	}
	_update_work_order_row(order)


func _build_adversarial_panel() -> void:
	_encounter_panel = PanelContainer.new()
	_encounter_panel.name = "AdversarialEncounterPanel"
	_encounter_panel.anchor_left = 0.31
	_encounter_panel.anchor_top = 0.145
	_encounter_panel.anchor_right = 0.74
	_encounter_panel.anchor_bottom = 0.345
	_encounter_panel.visible = false
	_encounter_panel.add_theme_stylebox_override("panel", _encounter_panel_style())
	_root.add_child(_encounter_panel)
	_register_ui_hit_region(_encounter_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 13)
	margin.add_theme_constant_override("margin_right", 13)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	_encounter_panel.add_child(margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 6)
	margin.add_child(stack)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	stack.add_child(header)

	_encounter_title_label = Label.new()
	_encounter_title_label.text = "CREW GRIEVANCE"
	_encounter_title_label.add_theme_font_size_override("font_size", 13)
	_encounter_title_label.add_theme_color_override("font_color", Color("#5a342b"))
	header.add_child(_encounter_title_label)

	_encounter_meter = ProgressBar.new()
	_encounter_meter.min_value = 0
	_encounter_meter.max_value = 100
	_encounter_meter.value = 60
	_encounter_meter.show_percentage = false
	_encounter_meter.custom_minimum_size = Vector2(142, 8)
	_encounter_meter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_encounter_meter.add_theme_stylebox_override("background", _soft_box(Color("#f1e2d4"), 6, 0))
	_encounter_meter.add_theme_stylebox_override("fill", _soft_box(Color("#de8559"), 6, 0))
	header.add_child(_encounter_meter)

	_encounter_goal_label = Label.new()
	_encounter_goal_label.text = "Patience"
	_encounter_goal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_encounter_goal_label.add_theme_font_size_override("font_size", 11)
	_encounter_goal_label.add_theme_color_override("font_color", Color("#7b604e"))
	stack.add_child(_encounter_goal_label)

	_encounter_line_label = Label.new()
	_encounter_line_label.text = ""
	_encounter_line_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_encounter_line_label.custom_minimum_size = Vector2(0, 40)
	_encounter_line_label.add_theme_font_size_override("font_size", 13)
	_encounter_line_label.add_theme_color_override("font_color", Color("#2f2922"))
	stack.add_child(_encounter_line_label)

	var choices := HBoxContainer.new()
	choices.add_theme_constant_override("separation", 7)
	stack.add_child(choices)
	for index in range(4):
		var button := Button.new()
		button.text = "Choice"
		button.custom_minimum_size = Vector2(0, 30)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size", 13)
		button.add_theme_color_override("font_color", Color("#3f372d"))
		button.add_theme_stylebox_override("normal", _encounter_choice_style(false))
		button.add_theme_stylebox_override("hover", _encounter_choice_style(true))
		button.add_theme_stylebox_override("pressed", _encounter_choice_style(true))
		button.pressed.connect(_on_encounter_choice_pressed.bind(index))
		choices.add_child(button)
		_encounter_choice_buttons.append(button)


func _on_work_order_row_button_pressed(order_id: String) -> void:
	if not _work_order_rows.has(order_id):
		return
	var row: Dictionary = _work_order_rows[order_id]
	if str(row.get("intent", "send")) == "clear":
		work_order_cancel_requested.emit(order_id)
		return
	work_order_requested.emit(order_id)


func _on_encounter_choice_pressed(index: int) -> void:
	if index < 0 or index >= _encounter_choices.size():
		return
	var choice: Dictionary = _encounter_choices[index]
	var choice_id := str(choice.get("id", ""))
	if choice_id == "":
		return
	sound_requested.emit("ui_click")
	adversarial_response_selected.emit(choice_id)


func _update_parley_pulse(delta: float) -> void:
	if _parley_button == null or not _parley_prompt_active:
		return

	_parley_pulse_phase += delta * 5.5
	var pulse := 0.5 + sin(_parley_pulse_phase) * 0.5
	_parley_button.modulate = Color(1.0, 0.90 + pulse * 0.10, 0.82 + pulse * 0.18, 1.0)


func _make_inventory_pill(id: String, text: String, color: Color, is_crafted: bool) -> PanelContainer:
	var pill := PanelContainer.new()
	pill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pill.custom_minimum_size = Vector2(0, 21)
	pill.add_theme_stylebox_override("panel", _soft_box(color, 8, 1))

	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color("#3f372d"))
	pill.add_child(label)

	if is_crafted:
		_crafted_labels[id] = label
	else:
		_resource_labels[id] = label
	return pill


func _build_toast() -> void:
	var toast_panel := PanelContainer.new()
	toast_panel.name = "ToastPanel"
	toast_panel.anchor_left = 0.38
	toast_panel.anchor_top = 0.705
	toast_panel.anchor_right = 0.64
	toast_panel.anchor_bottom = 0.752
	toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_panel.add_theme_stylebox_override("panel", _soft_box(Color("#fffdf8"), 13, 1))
	_root.add_child(toast_panel)

	_toast_label = Label.new()
	_toast_label.name = "Toast"
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_toast_label.add_theme_font_size_override("font_size", 18)
	_toast_label.add_theme_color_override("font_color", Color("#2b2924"))
	toast_panel.add_child(_toast_label)


func _register_ui_hit_region(control: Control) -> void:
	if control != null and not _ui_hit_regions.has(control):
		_ui_hit_regions.append(control)


func _make_toggle(label: String, default_value: bool, signal_ref: Signal) -> Button:
	var button := Button.new()
	button.toggle_mode = true
	button.button_pressed = default_value
	button.custom_minimum_size = Vector2(0, 24)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", Color("#373127"))
	button.add_theme_color_override("font_hover_color", Color("#2d3b1d"))
	button.add_theme_color_override("font_pressed_color", Color("#2d3b1d"))
	button.add_theme_color_override("font_hover_pressed_color", Color("#2d3b1d"))
	_update_toggle_text(button, label)
	button.add_theme_stylebox_override("normal", _toggle_style(default_value))
	button.add_theme_stylebox_override("pressed", _toggle_style(true))
	button.add_theme_stylebox_override("hover", _toggle_style(true))
	button.toggled.connect(func(is_on: bool) -> void:
		_update_toggle_text(button, label)
		button.add_theme_stylebox_override("normal", _toggle_style(is_on))
		sound_requested.emit("ui_click")
		signal_ref.emit(is_on)
	)
	return button


func _on_tool_button_pressed(tool_name: String) -> void:
	set_selected_tool(tool_name)
	sound_requested.emit("tool_select")
	tool_selected.emit(tool_name)


func _on_item_selected(item_id: String) -> void:
	set_selected_tool("place")
	_set_cursor_item(item_id)
	sound_requested.emit("ui_click")
	item_selected.emit(item_id)


func _update_toggle_text(button: Button, label: String) -> void:
	button.text = "%s  %s" % [label, "ON" if button.button_pressed else "OFF"]


func _format_reaction_action(expression: String, fallback: String) -> String:
	match expression:
		"side_eye":
			return "-_- Side-eye"
		"annoyed":
			return ">_> Annoyed"
		"angry":
			return "-_-! Judging"
		"pleased":
			return "^_^ Pleased"
	return fallback


func _format_social_signal(helped_today: int, recent_help_label: String) -> String:
	var suffix := ": %s" % recent_help_label if recent_help_label != "" else ""
	if helped_today > 1:
		return "Helped today x%s%s" % [helped_today, suffix]
	return "Helped today%s" % suffix


func _format_spent_favor_signal(favor_spent_today: int, recent_spent_favor_label: String) -> String:
	var suffix := ": %s" % recent_spent_favor_label if recent_spent_favor_label != "" else ""
	if favor_spent_today > 1:
		return "Favor spent x%s%s" % [favor_spent_today, suffix]
	return "Favor spent%s" % suffix


func _format_memory_signal(remembered_help_label: String) -> String:
	if remembered_help_label == "":
		return "Remembers help"
	return "Remembers: %s" % remembered_help_label


func _format_discussed_memory_signal(memory_discussed_today: int, recent_discussed_memory_label: String) -> String:
	var suffix := ": %s" % recent_discussed_memory_label if recent_discussed_memory_label != "" else ""
	if memory_discussed_today > 1:
		return "Discussed x%s%s" % [memory_discussed_today, suffix]
	return "Discussed%s" % suffix


func _format_truce_signal(truce_label: String, truce_absorbed_today: int = 0) -> String:
	var prefix := "Truce held" if truce_absorbed_today > 0 else "Truce"
	if truce_label == "":
		return prefix
	return "%s: %s" % [prefix, truce_label]


func _format_active_social_preference_signal(source: String, label: String, origin_source: String = "", origin_label: String = "") -> String:
	var prefix := _active_social_preference_signal_prefix(source)
	var text := prefix
	if label == "":
		text = prefix
	else:
		text = "%s: %s" % [prefix, label]
	var origin_detail := _format_social_preference_origin_detail(source, label, origin_source, origin_label)
	if origin_detail != "":
		text += " (%s)" % origin_detail
	return text


func _format_social_preference_origin_detail(source: String, label: String, origin_source: String, origin_label: String) -> String:
	source = source.strip_edges()
	label = label.strip_edges()
	origin_source = origin_source.strip_edges()
	origin_label = origin_label.strip_edges()
	if origin_source == "" or origin_label == "":
		return ""
	if origin_source == source and origin_label == label:
		return ""
	return "%s: %s" % [_active_social_preference_origin_prefix(origin_source), origin_label]


func _active_social_preference_origin_prefix(source: String) -> String:
	match source:
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


func _active_social_preference_signal_prefix(source: String) -> String:
	match source:
		"truce":
			return "Truce work"
		"repeated_help":
			return "Streak work"
		"completed_order":
			return "Follow-up work"
		"completed_mission":
			return "Momentum work"
		"ignored_ask":
			return "Pressure work"
		"held_truce":
			return "Held work"
	return "Memory work"


func _format_daily_intention_signal(
	label: String,
	intention_id: String = "",
	memory_consequence_label: String = "",
	memory_consequence_origin_source: String = "",
	memory_consequence_origin_label: String = ""
) -> String:
	var clean_label := label.strip_edges()
	if intention_id == "mission_momentum":
		var mission_label := memory_consequence_label.strip_edges()
		if mission_label == "":
			mission_label = clean_label
		if mission_label == "":
			return "Mission momentum"
		var signal_text := "Mission momentum: %s" % mission_label
		var origin_context := _mission_momentum_origin_context_text(memory_consequence_origin_source, memory_consequence_origin_label)
		if origin_context != "":
			signal_text += " [%s]" % origin_context
		return signal_text
	if clean_label == "":
		return "Plan"
	return "Plan: %s" % clean_label


func _mission_momentum_origin_context_text(source: String, label: String) -> String:
	var source_text := _readable_preference_source(source)
	var clean_label := label.strip_edges()
	if source_text == "":
		return clean_label
	if clean_label == "":
		return source_text
	return "%s: %s" % [source_text, clean_label]


func _readable_preference_source(source: String) -> String:
	match source.strip_edges():
		"remembered_help", "memory":
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
	return ""


func _format_pending_demand_signal(demand_label: String, signal_state: String = "wants", detail: String = "") -> String:
	match signal_state:
		"mission":
			var suffix := " %s" % detail if detail != "" else ""
			return "Mission%s: %s" % [suffix, demand_label]
		"memory":
			return "Memory: %s" % demand_label
		"truce":
			return "Truce: %s" % demand_label
		"streak":
			return "Streak: %s" % demand_label
		"follow_up":
			return "Follow-up: %s" % demand_label
		"mission_memory":
			return "Momentum: %s" % demand_label
		"pressure":
			return "Pressure: %s" % demand_label
		"held":
			return "Held: %s" % demand_label
		"bonus":
			var suffix := " %s" % detail if detail != "" else ""
			return "Bonus: %s%s" % [demand_label, suffix]
		"escalated":
			return "Escalated: %s" % demand_label
		"sent":
			return "Sent: %s" % demand_label
		"waiting":
			return "Waiting: %s" % demand_label
		"queued":
			return "Queued: %s" % demand_label
	return "Wants: %s" % demand_label


func _pending_demand_details_from(demands: Array) -> Dictionary:
	var details := {}
	for demand in demands:
		if typeof(demand) != TYPE_DICTIONARY:
			continue
		if str(demand.get("status", "")) != "open":
			continue
		var agent_id := str(demand.get("agent_id", ""))
		if agent_id == "" or details.has(agent_id):
			continue
		var mission_progress := _demand_mission_progress_fraction(demand)
		if mission_progress != "":
			details[agent_id] = mission_progress
		else:
			details[agent_id] = _clean_pending_demand_status_detail(str(demand.get("status_text", "")))
	return details


func _pending_demand_labels_from(demands: Array) -> Dictionary:
	var labels := {}
	for demand in demands:
		if typeof(demand) != TYPE_DICTIONARY:
			continue
		if str(demand.get("status", "")) != "open":
			continue
		var agent_id := str(demand.get("agent_id", ""))
		if agent_id == "" or labels.has(agent_id):
			continue
		var mission_label := str(demand.get("mission_label", "")).strip_edges()
		if str(demand.get("mission_id", "")).strip_edges() != "" and mission_label != "":
			labels[agent_id] = mission_label
		else:
			labels[agent_id] = str(demand.get("label", "Crew Demand"))
	return labels


func _pending_demand_order_ids_from(demands: Array) -> Dictionary:
	var order_ids := {}
	for demand in demands:
		if typeof(demand) != TYPE_DICTIONARY:
			continue
		if str(demand.get("status", "")) != "open":
			continue
		var agent_id := str(demand.get("agent_id", ""))
		if agent_id == "" or order_ids.has(agent_id):
			continue
		var order_id := str(demand.get("authored_order_id", ""))
		if order_id != "":
			order_ids[agent_id] = order_id
	return order_ids


func _pending_demand_signal_states_from(demands: Array) -> Dictionary:
	var states := {}
	for demand in demands:
		if typeof(demand) != TYPE_DICTIONARY:
			continue
		if str(demand.get("status", "")) != "open":
			continue
		var agent_id := str(demand.get("agent_id", ""))
		if agent_id == "" or states.has(agent_id):
			continue
		var status_detail := _clean_pending_demand_status_detail(str(demand.get("status_text", "")))
		if status_detail.begins_with("+"):
			states[agent_id] = "bonus"
		elif status_detail == "Escalated":
			states[agent_id] = "escalated"
		elif status_detail == "Sent":
			states[agent_id] = "sent"
		elif status_detail.begins_with("Waiting"):
			states[agent_id] = "waiting"
		elif str(demand.get("authored_order_id", "")) != "":
			states[agent_id] = "queued"
		elif str(demand.get("mission_id", "")).strip_edges() != "":
			states[agent_id] = "mission"
		elif str(demand.get("preference_source", "")) == "remembered_help":
			states[agent_id] = "memory"
		elif str(demand.get("preference_source", "")) == "truce":
			states[agent_id] = "truce"
		elif str(demand.get("preference_source", "")) == "repeated_help":
			states[agent_id] = "streak"
		elif str(demand.get("preference_source", "")) == "completed_order":
			states[agent_id] = "follow_up"
		elif str(demand.get("preference_source", "")) == "completed_mission":
			states[agent_id] = "mission_memory"
		elif str(demand.get("preference_source", "")) == "ignored_ask":
			states[agent_id] = "pressure"
		elif str(demand.get("preference_source", "")) == "held_truce":
			states[agent_id] = "held"
		else:
			states[agent_id] = "wants"
	return states


func _clean_pending_demand_status_detail(status_text: String) -> String:
	var detail := status_text.strip_edges()
	var digit_count := 0
	while digit_count < detail.length():
		var code := detail.unicode_at(digit_count)
		if code < 48 or code > 57:
			break
		digit_count += 1
	if digit_count > 0 and detail.substr(digit_count, 2) == "d ":
		detail = detail.substr(digit_count + 2).strip_edges()
	return detail


func _pending_demand_target_ids_from(demands: Array) -> Dictionary:
	var target_ids := {}
	var seen_agents := {}
	for demand in demands:
		if typeof(demand) != TYPE_DICTIONARY:
			continue
		if str(demand.get("status", "")) != "open":
			continue
		var agent_id := str(demand.get("agent_id", ""))
		if agent_id == "" or seen_agents.has(agent_id):
			continue
		seen_agents[agent_id] = true
		if typeof(demand.get("target_tile", null)) == TYPE_VECTOR2I:
			var demand_id := str(demand.get("id", ""))
			if demand_id != "":
				target_ids[agent_id] = demand_id
	return target_ids


func _refresh_crew_social_signals() -> void:
	for agent_id in _crew_rows.keys():
		var row: Dictionary = _crew_rows[agent_id]
		var snapshot: Dictionary = _crew_snapshots_by_id.get(str(agent_id), {"id": str(agent_id)})
		_apply_crew_social_signal(row, snapshot)


func _apply_crew_social_signal(row: Dictionary, snapshot: Dictionary) -> void:
	var agent_id := str(snapshot.get("id", ""))
	var helped_today := int(snapshot.get("helped_today", 0))
	var recent_help_label := str(snapshot.get("recent_help_label", ""))
	var favor_spent_today := int(snapshot.get("favor_spent_today", 0))
	var recent_spent_favor_label := str(snapshot.get("recent_spent_favor_label", ""))
	var memory_discussed_today := int(snapshot.get("memory_discussed_today", 0))
	var recent_discussed_memory_label := str(snapshot.get("recent_discussed_memory_label", ""))
	var truce_days := int(snapshot.get("truce_days", 0))
	var truce_label := str(snapshot.get("truce_label", ""))
	var truce_absorbed_today := int(snapshot.get("truce_absorbed_today", 0))
	var active_social_preference_source := str(snapshot.get("active_social_preference_source", ""))
	var active_social_preference_label := str(snapshot.get("active_social_preference_label", ""))
	var active_social_preference_origin_source := str(snapshot.get("active_social_preference_origin_source", ""))
	var active_social_preference_origin_label := str(snapshot.get("active_social_preference_origin_label", ""))
	var pending_demand_detail := str(_crew_pending_demand_details.get(agent_id, ""))
	var pending_demand_label := str(_crew_pending_demand_labels.get(agent_id, ""))
	var pending_demand_order_id := str(_crew_pending_demand_order_ids.get(agent_id, ""))
	var pending_demand_signal_state := str(_crew_pending_demand_signal_states.get(agent_id, "wants"))
	var pending_demand_target_id := str(_crew_pending_demand_target_ids.get(agent_id, ""))
	var pending_mission_active := pending_demand_label != "" and pending_demand_signal_state == "mission"
	var remembered_help_label := str(snapshot.get("remembered_help_label", ""))
	var memory_consequence_label := str(snapshot.get("memory_consequence_label", ""))
	var memory_consequence_origin_source := str(snapshot.get("memory_consequence_origin_source", ""))
	var memory_consequence_origin_label := str(snapshot.get("memory_consequence_origin_label", ""))
	var daily_intention_id := str(snapshot.get("daily_intention_id", ""))
	var daily_intention_label := str(snapshot.get("daily_intention_label", ""))
	var social_label := row["social"] as Label
	if pending_mission_active and helped_today > 0:
		social_label.visible = true
		social_label.text = _format_pending_demand_signal(pending_demand_label, pending_demand_signal_state, pending_demand_detail)
		_configure_crew_social_target(social_label, pending_demand_target_id, pending_demand_order_id)
	elif helped_today > 0:
		social_label.visible = true
		social_label.text = _format_social_signal(helped_today, recent_help_label)
		_configure_crew_social_target(social_label, "", "")
	elif favor_spent_today > 0:
		social_label.visible = true
		social_label.text = _format_spent_favor_signal(favor_spent_today, recent_spent_favor_label)
		_configure_crew_social_target(social_label, "", "")
	elif truce_absorbed_today > 0:
		social_label.visible = true
		social_label.text = _format_truce_signal(truce_label, truce_absorbed_today)
		_configure_crew_social_target(social_label, "", "")
	elif active_social_preference_source != "" and active_social_preference_label != "":
		social_label.visible = true
		social_label.text = _format_active_social_preference_signal(active_social_preference_source, active_social_preference_label, active_social_preference_origin_source, active_social_preference_origin_label)
		_configure_crew_social_target(social_label, "", "")
	elif pending_demand_label != "":
		social_label.visible = true
		social_label.text = _format_pending_demand_signal(pending_demand_label, pending_demand_signal_state, pending_demand_detail)
		_configure_crew_social_target(social_label, pending_demand_target_id, pending_demand_order_id)
	elif memory_discussed_today > 0:
		social_label.visible = true
		social_label.text = _format_discussed_memory_signal(memory_discussed_today, recent_discussed_memory_label)
		_configure_crew_social_target(social_label, "", "", agent_id, recent_discussed_memory_label)
	elif truce_days > 0:
		social_label.visible = true
		social_label.text = _format_truce_signal(truce_label)
		_configure_crew_social_target(social_label, "", "")
	elif daily_intention_id == "mission_momentum":
		social_label.visible = true
		social_label.text = _format_daily_intention_signal(
			daily_intention_label,
			daily_intention_id,
			memory_consequence_label,
			memory_consequence_origin_source,
			memory_consequence_origin_label
		)
		_configure_crew_social_target(social_label, "", "")
	elif remembered_help_label != "":
		social_label.visible = true
		social_label.text = _format_memory_signal(remembered_help_label)
		_configure_crew_social_target(social_label, "", "")
	elif daily_intention_label != "":
		social_label.visible = true
		social_label.text = _format_daily_intention_signal(
			daily_intention_label,
			daily_intention_id,
			memory_consequence_label,
			memory_consequence_origin_source,
			memory_consequence_origin_label
		)
		_configure_crew_social_target(social_label, "", "")
	else:
		social_label.visible = false
		social_label.text = ""
		_configure_crew_social_target(social_label, "", "")


func _configure_crew_social_target(social_label: Label, demand_id: String, order_id: String = "", memory_agent_id: String = "", memory_label: String = "") -> void:
	social_label.set_meta("crew_demand_id", demand_id)
	social_label.set_meta("crew_order_id", order_id)
	social_label.set_meta("crew_memory_agent_id", memory_agent_id)
	social_label.set_meta("crew_memory_label", memory_label)
	if demand_id == "" and memory_label == "":
		social_label.tooltip_text = ""
		social_label.mouse_default_cursor_shape = Control.CURSOR_ARROW
		social_label.mouse_filter = Control.MOUSE_FILTER_PASS
		return
	if memory_label != "":
		social_label.tooltip_text = "Replay discussed memory"
		social_label.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		social_label.mouse_filter = Control.MOUSE_FILTER_STOP
		return
	social_label.tooltip_text = "Focus target and send order" if order_id != "" else "Focus demand target"
	social_label.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	social_label.mouse_filter = Control.MOUSE_FILTER_STOP


func _on_crew_social_signal_input(agent_id: String, event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	var row: Dictionary = _crew_rows.get(agent_id, {})
	if not row.has("social"):
		return
	var social_label := row["social"] as Label
	if social_label == null or not social_label.visible:
		return
	var demand_id := str(social_label.get_meta("crew_demand_id", ""))
	var memory_label := str(social_label.get_meta("crew_memory_label", ""))
	if demand_id == "" and memory_label == "":
		return
	sound_requested.emit("ui_click")
	if memory_label != "":
		var agent_name := _crew_name_for(str(social_label.get_meta("crew_memory_agent_id", agent_id)))
		var message := "Memory discussed: %s remembered %s." % [agent_name, memory_label]
		add_field_log(message)
		show_message(message)
		var memory_viewport := get_viewport()
		if memory_viewport != null:
			memory_viewport.set_input_as_handled()
		return
	crafting_demand_target_requested.emit(demand_id)
	var order_id := str(social_label.get_meta("crew_order_id", ""))
	if order_id != "":
		work_order_requested.emit(order_id)
	var viewport := get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()


func _on_crew_mission_row_input(mission_id: String, event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	var row: Dictionary = _crew_mission_rows.get(mission_id, {})
	if not row.has("panel"):
		return
	var row_panel := row["panel"] as PanelContainer
	if row_panel == null:
		return
	var demand_id := str(row_panel.get_meta("mission_demand_id", ""))
	if demand_id == "":
		return
	sound_requested.emit("ui_click")
	crafting_demand_target_requested.emit(demand_id)
	var order_id := str(row_panel.get_meta("mission_order_id", ""))
	if order_id != "":
		work_order_requested.emit(order_id)
	var viewport := get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()


func _crew_name_for(agent_id: String) -> String:
	var snapshot: Dictionary = _crew_snapshots_by_id.get(agent_id, {})
	return str(snapshot.get("name", agent_id.capitalize()))


func _format_encounter_goal(session: Dictionary) -> String:
	var patience := roundi(float(session.get("patience_meter", 0.0)))
	var turns := int(session.get("max_turns", 3)) - int(session.get("turn_count", 0))
	var social_credit_bonus := roundi(float(session.get("social_credit_bonus", 0.0)))
	if social_credit_bonus > 0:
		return "Patience %s | Favor +%s | Turns %s" % [patience, social_credit_bonus, turns]
	if str(session.get("remembered_help_label", "")) != "":
		return "Patience %s | Memory | Turns %s" % [patience, turns]
	return "Patience %s | Turns %s" % [patience, turns]


func _encounter_goal_tooltip(session: Dictionary) -> String:
	var social_credit_label := str(session.get("social_credit_label", ""))
	if social_credit_label != "":
		return social_credit_label
	var remembered_help_label := str(session.get("remembered_help_label", ""))
	if remembered_help_label != "":
		return "Remembered help: %s" % remembered_help_label
	return ""


func _format_action(action: String, phase: String = "idle") -> String:
	if phase == "walking":
		match action:
			"harvest_crop":
				return "Heading to crops"
			"clear_brush":
				return "Heading to brush"
			"inspect_structure":
				return "Checking a build"
			"inspect_ready_crop":
				return "Checking crops"
			"inspect_soil":
				return "Checking soil"
			"build_fence_order":
				return "Heading to order"
			_:
				return "Walking the farm"

	match action:
		"build_fence_order":
			return "Building fence"
		"harvest_crop":
			return "Harvesting crop"
		"clear_brush":
			return "Clearing brush"
		"inspect_structure":
			return "Inspecting build"
		"inspect_ready_crop":
			return "Inspecting ready crops"
		"inspect_soil":
			return "Checking open soil"
		"approve":
			return "Approving your work"
		"side_eye":
			return "Judging the operation"
		"rest":
			return "Taking five"
		"wander":
			return "Patrolling the rows"
		_:
			return action.capitalize()


func _build_cursor_ghost() -> void:
	_cursor_ghost = PanelContainer.new()
	_cursor_ghost.name = "CursorItemGhost"
	_cursor_ghost.visible = false
	_cursor_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cursor_ghost.custom_minimum_size = Vector2(58, 48)
	_cursor_ghost.add_theme_stylebox_override("panel", _cursor_ghost_style())
	_root.add_child(_cursor_ghost)

	_cursor_ghost_label = Label.new()
	_cursor_ghost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cursor_ghost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_cursor_ghost_label.add_theme_font_size_override("font_size", 12)
	_cursor_ghost_label.add_theme_color_override("font_color", Color("#2f2a22"))
	_cursor_ghost.add_child(_cursor_ghost_label)


func _set_cursor_item(item_id: String) -> void:
	_cursor_item_id = item_id
	if _cursor_ghost == null or _cursor_ghost_label == null:
		return

	_cursor_ghost_label.text = "%s\n%s" % [_item_icon(item_id), _item_short_name(item_id)]
	_cursor_ghost.visible = item_id != ""
	_cursor_ghost.position = _root.get_local_mouse_position() + Vector2(18, 18)


func _item_icon(item_id: String) -> String:
	match item_id:
		"order_build_fence":
			return "FNC"
		"order_clear_brush":
			return "CLR"
		"order_harvest_crop":
			return "HRV"
		"grass_block":
			return "GRS"
		"dirt_road":
			return "RD"
		"soil":
			return "SOIL"
		"corn_seed":
			return "CRN"
		"wheat_seed":
			return "WHT"
		"tall_grass":
			return "TGR"
		"flower_patch":
			return "FLR"
		"rock":
			return "RCK"
		"fence":
			return "FNC"
		"wooden_sign":
			return "SGN"
		"barn":
			return "BRN"
		"silo":
			return "SLO"
		"well":
			return "WEL"
		"pickaxe":
			return "PCK"
		"sickle":
			return "SCK"
	return "ITM"


func _item_short_name(item_id: String) -> String:
	match item_id:
		"order_build_fence":
			return "Crew"
		"order_clear_brush":
			return "Crew"
		"order_harvest_crop":
			return "Crew"
		"grass_block":
			return "Grass"
		"dirt_road":
			return "Road"
		"corn_seed":
			return "Corn"
		"wheat_seed":
			return "Wheat"
		"tall_grass":
			return "Grass"
		"flower_patch":
			return "Flower"
		"wooden_sign":
			return "Sign"
		"pickaxe":
			return "Break"
		"sickle":
			return "Cut"
	return item_id.replace("_", " ").capitalize()


func _panel_style(radius: int, border: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.992, 0.965, 0.94)
	style.border_color = Color("#6e5b3e")
	style.set_border_width_all(border)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(0, 0, 0, 0.15)
	style.shadow_size = 12
	style.shadow_offset = Vector2(0, 6)
	return style


func _crew_row_style(mood: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#fffaf0") if mood >= 45.0 else Color("#f7ece2")
	style.border_color = Color("#d3c4aa") if mood >= 45.0 else Color("#d6a17b")
	style.set_border_width_all(1)
	style.set_corner_radius_all(11)
	return style


func _crew_mission_row_style(mission: Dictionary) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	var is_done := str(mission.get("status", "")) == "done"
	style.bg_color = Color("#eef5ea") if is_done else Color("#f0f1fb")
	style.border_color = Color("#a4bd8d") if is_done else Color("#a8a9d6")
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	return style


func _crew_mission_status_color(mission: Dictionary) -> Color:
	if str(mission.get("status", "")) == "done":
		return Color("#5f7f39")
	return Color("#6469a6")


func _cursor_ghost_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.965, 0.82, 0.86)
	style.border_color = Color("#9e7a2a")
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.shadow_color = Color(0, 0, 0, 0.14)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 4)
	return style


func _tool_button_style(active: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#eef4e4") if active else Color(1, 1, 1, 0)
	style.border_color = Color("#7b914d") if active else Color(0, 0, 0, 0)
	style.set_border_width_all(1 if active else 0)
	style.set_corner_radius_all(12)
	return style


func _big_button_style(active: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#efca59") if active else Color("#fff0bd")
	style.border_color = Color("#9e7a2a")
	style.set_border_width_all(1)
	style.set_corner_radius_all(11)
	style.shadow_color = Color(0, 0, 0, 0.10)
	style.shadow_size = 4
	style.shadow_offset = Vector2(0, 2)
	return style


func _craft_button_style(active: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#e8f3da") if active else Color("#f2eee5")
	style.border_color = Color("#84a05d") if active else Color("#c9bca6")
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	return style


func _remove_button_style(active: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#f7e6d9") if active else Color("#f4eee7")
	style.border_color = Color("#b68466") if active else Color("#d0b8a4")
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	return style


func _crew_order_button_style(active: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#e2f1d8") if active else Color("#fffaf0")
	style.border_color = Color("#769352") if active else Color("#d1bea0")
	style.set_border_width_all(1)
	style.set_corner_radius_all(9)
	return style


func _encounter_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.965, 0.90, 0.96)
	style.border_color = Color("#9b654c")
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.shadow_color = Color(0, 0, 0, 0.16)
	style.shadow_size = 14
	style.shadow_offset = Vector2(0, 7)
	return style


func _encounter_choice_style(active: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#ffe4c8") if active else Color("#fff6e9")
	style.border_color = Color("#b87956") if active else Color("#d0aa8b")
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	return style


func _parley_button_style(prompted: bool, active: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	if prompted:
		style.bg_color = Color("#ffe4c8") if active else Color("#fff0d8")
		style.border_color = Color("#b87956")
	else:
		style.bg_color = Color("#e2f1d8") if active else Color("#fffaf0")
		style.border_color = Color("#769352") if active else Color("#d1bea0")
	style.set_border_width_all(1)
	style.set_corner_radius_all(9)
	return style


func _toggle_style(active: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#eef5e5") if active else Color("#f4efe5")
	style.border_color = Color("#94a96b") if active else Color("#c9bca6")
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	return style


func _soft_box(color: Color, radius: int, border: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color("#7b694e")
	style.set_border_width_all(border)
	style.set_corner_radius_all(radius)
	return style
