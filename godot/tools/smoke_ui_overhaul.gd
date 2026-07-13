extends SceneTree

const VIEWPORT_SIZES := [Vector2i(1600, 900), Vector2i(1280, 720)]
const TAB_IDS := ["farm", "crew", "agent", "world"]
const CATEGORY_ITEMS := {
	"Terrain": ["grass_block", "dirt_road", "soil"],
	"Crops": ["corn_seed", "wheat_seed"],
	"Nature": ["tall_grass", "tree", "flower_patch", "rock"],
	"Decor": ["fence", "wooden_sign"],
	"Structures": ["barn", "silo", "well"],
	"Tools": ["pickaxe", "sickle"]
}

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for index in range(VIEWPORT_SIZES.size()):
		await _test_resolution(VIEWPORT_SIZES[index], index == 0)
		if _failed:
			return
	if not _failed:
		quit()


func _test_resolution(viewport_size: Vector2i, run_deep_contract: bool) -> void:
	root.content_scale_size = viewport_size
	root.size = viewport_size
	await process_frame

	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	await process_frame

	var game_ui = scene.get_node("GameUI")
	var ui_root := game_ui.get_node("UIRoot") as Control
	var title := ui_root.get_node("TitleCard") as Control
	var dock := ui_root.get_node("CommandDock") as Control
	var crew := ui_root.get_node("CrewPanel") as Control
	var status := ui_root.get_node("StatusPanel") as Control
	var workbench := ui_root.get_node("CodeWorkbench") as Control
	var editor := workbench.find_child("AgentCodeEditor", true, false) as CodeEdit
	var compiler_panel := workbench.find_child("CompilerOutputPanel", true, false) as Control

	_assert_major_layout(viewport_size, [title, dock, crew, status, workbench], editor, compiler_panel)
	if _failed:
		return
	await _assert_command_tabs(game_ui, dock)
	if _failed:
		return

	if run_deep_contract:
		await _assert_command_and_icon_contract(scene, game_ui, dock, crew, status)
		if _failed:
			return
		await _assert_palette_contract(scene, game_ui)
		if _failed:
			return
		await _assert_editor_contract(scene, game_ui, editor)
		if _failed:
			return
		await _assert_pointer_contract(scene, game_ui, [title, dock, crew, status, workbench], editor, viewport_size)
		if _failed:
			return

	scene.queue_free()
	await process_frame
	await process_frame


func _assert_major_layout(
	viewport_size: Vector2i,
	panels: Array,
	editor: CodeEdit,
	compiler_panel: Control
) -> void:
	var viewport_rect := Rect2(Vector2.ZERO, Vector2(viewport_size)).grow(1.0)
	for panel in panels:
		var control := panel as Control
		if control == null or not viewport_rect.encloses(control.get_global_rect()):
			_fail("UI panel escaped the %sx%s viewport: %s rect=%s" % [viewport_size.x, viewport_size.y, control.name if control else "missing", control.get_global_rect() if control else Rect2()])
			return

	var title := panels[0] as Control
	var dock := panels[1] as Control
	var crew := panels[2] as Control
	var status := panels[3] as Control
	var workbench := panels[4] as Control
	var pairs := [
		[title, dock],
		[dock, workbench],
		[workbench, crew],
		[workbench, status],
		[crew, status]
	]
	for pair in pairs:
		var first := pair[0] as Control
		var second := pair[1] as Control
		if _rects_overlap(first.get_global_rect(), second.get_global_rect()):
			_fail("UI panels overlap at %sx%s: %s %s and %s %s" % [viewport_size.x, viewport_size.y, first.name, first.get_global_rect(), second.name, second.get_global_rect()])
			return

	if editor == null or compiler_panel == null:
		_fail("Agent workbench did not create both editor and compiler output regions.")
		return
	if not workbench.get_global_rect().grow(1.0).encloses(editor.get_global_rect()):
		_fail("Agent editor escaped the workbench at %sx%s." % [viewport_size.x, viewport_size.y])
		return
	if not workbench.get_global_rect().grow(1.0).encloses(compiler_panel.get_global_rect()):
		_fail("Compiler output escaped the workbench at %sx%s." % [viewport_size.x, viewport_size.y])


func _assert_command_tabs(game_ui, dock: Control) -> void:
	var tabs: Dictionary = game_ui.get("_command_tab_buttons")
	var pages: Dictionary = game_ui.get("_command_tab_pages")
	if tabs.size() != TAB_IDS.size() or pages.size() != TAB_IDS.size():
		_fail("Command dock did not expose exactly FARM, CREW, AGENT, and WORLD tabs.")
		return

	var scroll := dock.find_child("CommandScroll", true, false) as ScrollContainer
	var page_host := dock.find_child("CommandPageHost", true, false) as Control
	if scroll == null or page_host == null:
		_fail("Command dock lost its responsive scroll/page host structure.")
		return

	for tab_id in TAB_IDS:
		if not tabs.has(tab_id) or not pages.has(tab_id):
			_fail("Command dock is missing the %s tab or page." % tab_id)
			return
		var tab := tabs[tab_id] as Button
		_assert_voxel_icon(tab, {"farm": "grass_block", "crew": "order_build_fence", "agent": "skill_tend_crop", "world": "view_grid"}[tab_id])
		if _failed:
			return
		tab.pressed.emit()
		await process_frame
		if str(game_ui.get("_active_command_tab")) != tab_id:
			_fail("Command tab did not activate: %s" % tab_id)
			return
		for page_id in TAB_IDS:
			var page := pages[page_id] as Control
			if page.is_visible_in_tree() != (page_id == tab_id):
				_fail("Command page visibility drifted while selecting %s." % tab_id)
				return
		var active_page := pages[tab_id] as Control
		if active_page.get_combined_minimum_size().x > scroll.size.x + 1.0:
			_fail("Command page %s is wider than its scroll viewport: min=%s available=%s" % [tab_id, active_page.get_combined_minimum_size().x, scroll.size.x])
			return


func _assert_command_and_icon_contract(scene: Node, game_ui, dock: Control, crew: Control, status: Control) -> void:
	var tool_icons := {
		"place": "place", "till": "till", "plant": "plant",
		"harvest": "harvest", "erase": "erase", "pan": "pan"
	}
	_assert_button_registry(game_ui.get("_tool_buttons"), tool_icons, dock, "field mode")
	if _failed:
		return

	var order_icons := {
		"build_fence": "order_build_fence", "clear_brush": "order_clear_brush",
		"harvest_crop": "order_harvest_crop", "plant_seed": "order_plant_seed",
		"tend_crop": "order_tend_crop"
	}
	_assert_button_registry(game_ui.get("_work_order_action_buttons"), order_icons, dock, "crew target")
	if _failed:
		return

	var craft_icons := {
		"fence_kit": "craft_fence_kit", "seed_bundle": "craft_seed_bundle", "rush_kit": "craft_rush_kit"
	}
	_assert_button_registry(game_ui.get("_craft_buttons"), craft_icons, dock, "craft")
	if _failed:
		return

	var skill_icons := {
		"tend_crops_starter": "skill_tend_crop", "plant_seed_starter": "skill_plant_seed",
		"clear_patch_starter": "skill_clear_patch", "harvest_crops_starter": "skill_harvest_crop",
		"build_fence_starter": "skill_build_fence"
	}
	_assert_button_registry(game_ui.get("_skill_forge_template_buttons"), skill_icons, dock, "agent recipe")
	if _failed:
		return

	var single_buttons := [
		[game_ui.get("_skill_forge_run_button"), "end_day", "Run"],
		[game_ui.get("_skill_forge_review_button"), "view_grid", "Check"],
		[game_ui.get("_skill_forge_revision_button"), "erase", "Fix"],
		[game_ui.get("_parley_button"), "parley", "Parley"],
		[dock.find_child("AmbientOcclusionToggle", true, false), "view_ao", "AO"],
		[dock.find_child("GridToggle", true, false), "view_grid", "Grid"],
		[dock.find_child("ShadowsToggle", true, false), "view_shadows", "Shadows"],
		[dock.find_child("CameraZoomIn", true, false), "zoom_in", "Zoom In"],
		[dock.find_child("CameraZoomOut", true, false), "zoom_out", "Zoom Out"],
		[dock.find_child("CameraRecenter", true, false), "recenter", "Center Camera"],
		[dock.find_child("EndDayButton", true, false), "end_day", "End Day"]
	]
	for entry in single_buttons:
		var button := entry[0] as Button
		if button == null or not dock.is_ancestor_of(button):
			_fail("Persistent %s command was not consolidated into CommandDock." % entry[2])
			return
		_assert_voxel_icon(button, str(entry[1]))
		if _failed:
			return

	var crew_rows: Dictionary = game_ui.get("_crew_rows")
	var signal_icons := {"bert": "order_build_fence", "marigold": "order_tend_crop", "chuck": "order_clear_brush"}
	for agent_id in signal_icons.keys():
		if not crew_rows.has(agent_id):
			_fail("Crew status registry is missing %s." % agent_id)
			return
		var crew_row: Dictionary = crew_rows[agent_id]
		var signal_label := crew_row.get("social", null) as Label
		var status_label := crew_row.get("social_status", null) as Label
		var signal_card := dock.find_child("CrewSignal_%s" % agent_id, true, false) as Control
		if signal_label == null or signal_card == null or not signal_card.is_ancestor_of(signal_label):
			_fail("Clickable %s crew signal was not consolidated into CommandDock." % agent_id)
			return
		_assert_control_voxel_icon(signal_card, str(signal_icons[agent_id]))
		if _failed:
			return
		if status_label == null or not crew.is_ancestor_of(status_label) or status_label.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			_fail("Right-side %s crew signal is not a read-only status mirror." % agent_id)
			return

	game_ui.set_crafting_demands([{
		"id": "smoke_demand", "label": "Seed Request", "kind": "deliver_item",
		"status": "open", "status_text": "Needs seed", "required_item": "seed_bundle",
		"has_required_item": false, "can_craft_required_item": true,
		"preference_source": "truce", "preference_label": "Seed peace", "reward_text": "+2 trust"
	}])
	game_ui.set_work_orders([{
		"id": "smoke_order", "label": "Fence Line", "action": "build_fence",
		"status": "ready", "status_text": "Ready", "can_progress": true,
		"has_required_item": false, "can_craft_item": true
	}])
	game_ui.set_crew_missions([{
		"id": "smoke_mission", "label": "Growth Run", "status": "active",
		"status_text": "Step", "agent_name": "Marigold", "current_step_label": "Tend crops",
		"current_demand_id": "smoke_demand", "current_order_id": "smoke_order"
	}])
	await process_frame
	var demand_rows: Dictionary = game_ui.get("_crafting_demand_rows")
	var work_rows: Dictionary = game_ui.get("_work_order_rows")
	var demand_button := (demand_rows["smoke_demand"] as Dictionary).get("button") as Button
	var work_button := (work_rows["smoke_order"] as Dictionary).get("button") as Button
	for entry in [[demand_button, "craft_seed_bundle", "demand"], [work_button, "order_build_fence", "work order"]]:
		var button := entry[0] as Button
		if button == null or not dock.is_ancestor_of(button):
			_fail("Dynamic %s command was not placed in the CREW dock." % entry[2])
			return
		_assert_voxel_icon(button, str(entry[1]))
		if _failed:
			return
	var mission_rows: Dictionary = game_ui.get("_crew_mission_rows")
	var mission_panel := (mission_rows["smoke_mission"] as Dictionary).get("panel") as PanelContainer
	if mission_panel == null or not dock.is_ancestor_of(mission_panel):
		_fail("Clickable mission tracker row was not consolidated into CommandDock.")
		return
	_assert_control_voxel_icon(mission_panel, "order_tend_crop")
	if _failed:
		return

	if not crew.find_children("*", "Button", true, false).is_empty():
		_fail("Crew status panel still contains command buttons.")
		return
	if not status.find_children("*", "Button", true, false).is_empty():
		_fail("Status-only field desk still contains command buttons.")
		return


func _assert_palette_contract(scene: Node, game_ui) -> void:
	var palette = game_ui.get("_palette")
	if palette == null:
		_fail("Command dock did not embed the voxel catalog.")
		return
	var expected_ids: Array = []
	for category in CATEGORY_ITEMS.keys():
		expected_ids.append_array(CATEGORY_ITEMS[category])
	var actual_ids: Array = palette.all_item_ids()
	expected_ids.sort()
	actual_ids.sort()
	if actual_ids != expected_ids:
		_fail("Voxel catalog item set changed. expected=%s actual=%s" % [expected_ids, actual_ids])
		return

	var category_buttons: Dictionary = palette.get("_tab_buttons")
	for category in CATEGORY_ITEMS.keys():
		if not category_buttons.has(category):
			_fail("Voxel catalog is missing the %s category." % category)
			return
		_assert_voxel_icon(category_buttons[category] as Button, {
			"Terrain": "grass_block", "Crops": "corn_seed", "Nature": "tree",
			"Decor": "fence", "Structures": "barn", "Tools": "pickaxe"
		}[category])
		if _failed:
			return
		palette.call("_select_category", category)
		await process_frame
		var item_buttons: Dictionary = palette.active_item_buttons()
		var expected_category_items: Array = CATEGORY_ITEMS[category]
		if item_buttons.size() != expected_category_items.size():
			_fail("Voxel catalog category %s rendered the wrong item count." % category)
			return
		for item_id in expected_category_items:
			if not item_buttons.has(item_id):
				_fail("Voxel catalog category %s is missing %s." % [category, item_id])
				return
			_assert_voxel_icon(item_buttons[item_id] as Button, item_id)
			if _failed:
				return

	palette.call("_select_category", "Nature")
	await process_frame
	var rock_button := (palette.active_item_buttons() as Dictionary)["rock"] as Button
	rock_button.pressed.emit()
	await process_frame
	var placement_tool = scene.get_node("PlacementTool")
	if str(placement_tool.get("selected_item_id")) != "rock" or int(placement_tool.get("current_tool")) != 0:
		_fail("Voxel catalog click did not select Rock and enter Place mode.")


func _assert_editor_contract(scene: Node, game_ui, editor: CodeEdit) -> void:
	var runtime_label := game_ui.get("_workbench_runtime_label") as Label
	var compiler_output := game_ui.get("_compiler_output") as RichTextLabel
	var compile_button := game_ui.get("_workbench_compile_button") as Button
	if editor == null or not editor.editable or not editor.gutters_draw_line_numbers or editor.syntax_highlighter == null:
		_fail("Agent workbench editor is not an editable, line-numbered, highlighted CodeEdit.")
		return
	if runtime_label == null or not runtime_label.text.contains("READY") or not runtime_label.text.contains("LOCAL COMPILER"):
		_fail("Agent workbench did not expose its live local compiler state.")
		return
	if compile_button == null or compile_button.text != "COMPILE" or not compile_button.tooltip_text.contains("Cmd/Ctrl+Enter"):
		_fail("Agent workbench did not expose its compile control and shortcut.")
		return
	if compiler_output == null or not compiler_output.text.contains("COMPILER TRACE") or not compiler_output.text.contains("local deterministic compiler ready"):
		_fail("Agent workbench compiler output lost its live pipeline trace.")
		return

	var placement_tool = scene.get_node("PlacementTool")
	var snapshot := {
		"day": scene.get_node("FarmWorld/GridManager").get("day"),
		"money": scene.get("money"),
		"resources": (scene.get("resources") as Dictionary).duplicate(true),
		"crafted": (scene.get("crafted_items") as Dictionary).duplicate(true),
		"reserved": (scene.get("reserved_crafted_items") as Dictionary).duplicate(true),
		"orders": (scene.get("work_orders") as Dictionary).duplicate(true),
		"order_ids": (scene.get("work_order_ids") as Array).duplicate(),
		"demands": (scene.get("crafting_demands") as Dictionary).duplicate(true),
		"demand_ids": (scene.get("crafting_demand_ids") as Array).duplicate(),
		"missions": (scene.get("crew_missions") as Dictionary).duplicate(true),
		"mission_ids": (scene.get("crew_mission_ids") as Array).duplicate(),
		"tool": placement_tool.get("current_tool"),
		"item": placement_tool.get("selected_item_id"),
		"crew_action": placement_tool.get("_crew_order_action_id"),
		"ui_order": game_ui.get("_active_work_order_tool"),
		"forge_template": game_ui.get("_active_skill_forge_template_id"),
		"forge_history": (game_ui.get("_skill_forge_history_entries") as Array).duplicate()
	}
	editor.set_caret_line(editor.get_line_count() - 1)
	editor.set_caret_column(editor.get_line(editor.get_line_count() - 1).length())
	editor.insert_text_at_caret("\n# tutor draft only")
	await process_frame
	if runtime_label.text != "UNSAVED  ·  READY TO COMPILE":
		_fail("Editing the agent draft did not switch the workbench to its ready-to-compile state.")
		return
	if not _game_state_matches_snapshot(scene, game_ui, placement_tool, snapshot):
		_fail("Editing the disconnected workbench mutated live game state.")
		return

	var camera_controller = scene.get_node("CameraController")
	editor.grab_focus()
	await process_frame
	if not bool(camera_controller.call("_keyboard_pan_blocked")):
		_fail("Camera keyboard pan was not blocked while AgentCodeEditor owned focus.")
		return
	var target_before: Vector3 = camera_controller.get("target_position")
	if bool(camera_controller.call("_apply_keyboard_pan", Vector2.RIGHT, 1.0)) or camera_controller.get("target_position") != target_before:
		_fail("Typing in AgentCodeEditor panned the farm camera.")
		return

	placement_tool.call("set_tool", "pan")
	var farm_click := InputEventMouseButton.new()
	farm_click.button_index = MOUSE_BUTTON_LEFT
	farm_click.button_mask = MOUSE_BUTTON_MASK_LEFT
	farm_click.pressed = true
	farm_click.position = Vector2(800, 450)
	farm_click.global_position = farm_click.position
	root.push_input(farm_click, true)
	var farm_release := InputEventMouseButton.new()
	farm_release.button_index = MOUSE_BUTTON_LEFT
	farm_release.pressed = false
	farm_release.position = farm_click.position
	farm_release.global_position = farm_click.position
	root.push_input(farm_release, true)
	await process_frame
	if bool(camera_controller.call("_keyboard_pan_blocked")):
		_fail("Clicking back into the farm did not release AgentCodeEditor focus.")
		return
	var resumed_target: Vector3 = camera_controller.get("target_position")
	if not bool(camera_controller.call("_apply_keyboard_pan", Vector2.RIGHT, 0.25)) or camera_controller.get("target_position") == resumed_target:
		_fail("WASD camera panning did not resume after leaving AgentCodeEditor.")
		return


func _assert_pointer_contract(scene: Node, game_ui, panels: Array, editor: CodeEdit, viewport_size: Vector2i) -> void:
	for panel in panels:
		var control := panel as Control
		if not game_ui.is_pointer_over_ui(control.get_global_rect().get_center()):
			_fail("Panel was not registered as a UI hit region: %s" % control.name)
			return
	if game_ui.is_pointer_over_ui(Vector2(viewport_size) * 0.5):
		_fail("Farm viewport center was incorrectly blocked by an invisible UI region.")
		return

	var placement_tool = scene.get_node("PlacementTool")
	var tile = scene.get_node("FarmWorld/GridManager").get_tile(Vector2i(6, 6))
	placement_tool.call("_set_hovered_tile", tile)
	var motion := InputEventMouseMotion.new()
	motion.position = editor.get_global_rect().get_center()
	motion.global_position = motion.position
	root.push_input(motion, true)
	await process_frame
	if placement_tool.get("_hovered_tile") != null:
		_fail("Pointer movement over AgentCodeEditor leaked through to farm targeting.")


func _assert_button_registry(registry_value, expected_icons: Dictionary, dock: Control, label: String) -> void:
	if typeof(registry_value) != TYPE_DICTIONARY:
		_fail("%s command registry is not a dictionary." % label.capitalize())
		return
	var registry: Dictionary = registry_value
	if registry.size() != expected_icons.size():
		_fail("%s command count changed. expected=%s actual=%s" % [label.capitalize(), expected_icons.size(), registry.size()])
		return
	for command_id in expected_icons.keys():
		if not registry.has(command_id):
			_fail("%s command is missing: %s" % [label.capitalize(), command_id])
			return
		var button := registry[command_id] as Button
		if button == null or not dock.is_ancestor_of(button):
			_fail("%s command was not consolidated into CommandDock: %s" % [label.capitalize(), command_id])
			return
		_assert_voxel_icon(button, str(expected_icons[command_id]))
		if _failed:
			return


func _assert_voxel_icon(button: Button, expected_id: String) -> void:
	if button == null:
		_fail("Missing button for voxel icon %s." % expected_id)
		return
	var icon := button.get_node_or_null("VoxelIcon") as Control
	if icon == null or str(icon.get("icon_id")) != expected_id:
		_fail("Button %s lost voxel icon %s." % [button.name, expected_id])
		return
	if icon.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		_fail("Voxel icon on %s intercepts pointer input." % button.name)
		return
	var model := icon.get_node_or_null("IconViewport/IconModel")
	if model == null or model.get_child_count() < 2:
		_fail("Voxel icon %s did not build a plinth plus model/fallback." % expected_id)


func _assert_control_voxel_icon(control: Control, expected_id: String) -> void:
	var icon := control.find_child("VoxelIcon", true, false) as Control
	if icon == null or str(icon.get("icon_id")) != expected_id:
		_fail("Control %s lost voxel icon %s." % [control.name, expected_id])
		return
	if icon.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		_fail("Voxel icon on %s intercepts pointer input." % control.name)
		return
	var model := icon.get_node_or_null("IconViewport/IconModel")
	if model == null or model.get_child_count() < 2:
		_fail("Voxel icon %s did not build a plinth plus model/fallback." % expected_id)


func _game_state_matches_snapshot(scene: Node, game_ui, placement_tool, snapshot: Dictionary) -> bool:
	return (
		scene.get_node("FarmWorld/GridManager").get("day") == snapshot["day"]
		and scene.get("money") == snapshot["money"]
		and scene.get("resources") == snapshot["resources"]
		and scene.get("crafted_items") == snapshot["crafted"]
		and scene.get("reserved_crafted_items") == snapshot["reserved"]
		and scene.get("work_orders") == snapshot["orders"]
		and scene.get("work_order_ids") == snapshot["order_ids"]
		and scene.get("crafting_demands") == snapshot["demands"]
		and scene.get("crafting_demand_ids") == snapshot["demand_ids"]
		and scene.get("crew_missions") == snapshot["missions"]
		and scene.get("crew_mission_ids") == snapshot["mission_ids"]
		and placement_tool.get("current_tool") == snapshot["tool"]
		and placement_tool.get("selected_item_id") == snapshot["item"]
		and placement_tool.get("_crew_order_action_id") == snapshot["crew_action"]
		and game_ui.get("_active_work_order_tool") == snapshot["ui_order"]
		and game_ui.get("_active_skill_forge_template_id") == snapshot["forge_template"]
		and game_ui.get("_skill_forge_history_entries") == snapshot["forge_history"]
	)


func _rects_overlap(first: Rect2, second: Rect2) -> bool:
	var overlap := first.intersection(second)
	return overlap.size.x > 0.5 and overlap.size.y > 0.5


func _fail(message: String) -> void:
	_failed = true
	push_error(message)
	quit(1)
