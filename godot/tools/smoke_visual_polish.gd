extends SceneTree

var _failed: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_reference_render_profile()
	if _failed:
		return
	await _test_contextual_grid_hierarchy()
	if _failed:
		return
	await _test_reason_badge_has_readable_plate()
	if _failed:
		return
	await _test_reason_badge_pops_when_motive_changes()
	if not _failed:
		quit()


func _test_reference_render_profile() -> void:
	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var world_environment := scene.get_node_or_null("WorldEnvironment") as WorldEnvironment
	var sun := scene.get_node_or_null("WarmSun") as DirectionalLight3D
	var fill := scene.get_node_or_null("SoftFill") as OmniLight3D
	if world_environment == null or world_environment.environment == null:
		_fail("Reference render profile did not create a world environment.")
		return
	if sun == null or fill == null:
		_fail("Reference render profile did not create its sun and fill lights.")
		return

	var environment := world_environment.environment
	if environment.ambient_light_energy < 0.35:
		_fail("Reference render profile ambient light is too dim to preserve readable shadow-side voxel planes.")
		return
	if environment.ambient_light_energy > 0.55:
		_fail("Reference render profile ambient light is bright enough to wash out voxel facets.")
		return
	if not environment.ssao_enabled:
		_fail("Reference render profile needs ambient occlusion for voxel depth.")
		return
	if environment.ssao_radius < 0.55 or environment.ssao_radius > 1.10:
		_fail("Reference render profile ambient occlusion should stay local to voxel contacts.")
		return
	if environment.ssao_intensity < 1.35 or environment.ssao_intensity > 1.70:
		_fail("Reference render profile ambient occlusion intensity left the contact-depth range.")
		return
	if environment.ssao_power < 1.15 or environment.ssao_power > 1.55:
		_fail("Reference render profile ambient occlusion power left the soft contact range.")
		return
	if environment.ssao_detail < 0.55 or environment.ssao_detail > 0.80:
		_fail("Reference render profile ambient occlusion detail left the micro-voxel range.")
		return
	if environment.ssao_light_affect < 0.03 or environment.ssao_light_affect > 0.18:
		_fail("Reference render profile should preserve small voxel crevices under direct light.")
		return
	if sun.light_energy < 1.10 or sun.light_energy > 1.30:
		_fail("Reference render profile sun energy left the contrast-safe range.")
		return
	if not sun.shadow_enabled:
		_fail("Reference render profile needs a shadow-casting sun for voxel depth.")
		return
	var sun_ray := -sun.global_transform.basis.z.normalized()
	if sun_ray.y < -0.94 or sun_ray.y > -0.80:
		_fail("Reference render profile sun direction should stay high enough for compact voxel shadows.")
		return
	if sun.shadow_blur < 1.25 or sun.shadow_blur > 2.00:
		_fail("Reference render profile sun shadows left the soft-edge range.")
		return
	if sun.shadow_opacity < 0.70 or sun.shadow_opacity > 0.90:
		_fail("Reference render profile shadow opacity left the soft contact-safe range.")
		return
	if fill.light_energy < 0.04 or fill.light_energy > 0.12:
		_fail("Reference render profile fill light left the readable shadow-side range.")
		return
	if float(environment.get("adjustment_brightness")) > 0.98:
		_fail("Reference render profile brightness is high enough to reintroduce washout.")
		return
	if not environment.adjustment_enabled or environment.tonemap_mode != Environment.TONE_MAPPER_FILMIC:
		_fail("Reference render profile should keep its enabled Filmic color grade.")
		return
	if float(environment.get("adjustment_contrast")) < 1.08:
		_fail("Reference render profile contrast is too low for readable voxel silhouettes.")
		return
	var saturation := float(environment.get("adjustment_saturation"))
	if saturation < 0.95 or saturation > 1.04:
		_fail("Reference render profile saturation should keep voxel highlights rich without turning fluorescent.")
		return
	if bool(environment.get("fog_enabled")):
		_fail("Reference render profile re-enabled the global fog wash.")
		return
	if not environment.glow_enabled or environment.glow_intensity > 0.10 or environment.glow_strength > 0.20 or environment.glow_bloom > 0.06:
		_fail("Reference render profile glow should remain a restrained highlight lift.")
		return
	if scene.get_node_or_null("WorldHazeWash") != null:
		_fail("Reference render profile reintroduced the full-screen haze wash.")
		return

	var grid = scene.get_node("FarmWorld/GridManager")
	var tile = grid.get_tile(Vector2i(6, 6))
	var tile_top := tile.get_node_or_null("TileTop") as MeshInstance3D
	var micro_cell := tile.get_node_or_null("TerrainDetails/MicroCells/MicroCell_0_0") as MeshInstance3D
	if tile_top == null or tile_top.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_ON:
		_fail("Reference render profile should keep macro voxel forms in the shadow pass.")
		return
	if micro_cell == null or micro_cell.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
		_fail("Reference render profile should keep packed micro cells out of the expensive shadow pass.")
		return
	var voxel_material := tile_top.material_override as BaseMaterial3D
	if voxel_material == null or voxel_material.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED:
		_fail("Reference render profile should keep procedural voxels lit rather than unshaded.")
		return
	if voxel_material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or voxel_material.emission_enabled:
		_fail("Reference render profile should keep terrain voxels opaque and non-emissive.")
		return
	if voxel_material.roughness < 0.84 or voxel_material.roughness > 0.92 or voxel_material.specular_mode != BaseMaterial3D.SPECULAR_DISABLED:
		_fail("Reference render profile should preserve the current matte voxel material contract.")
		return

	scene.queue_free()
	await process_frame


func _test_contextual_grid_hierarchy() -> void:
	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var grid = scene.get_node("FarmWorld/GridManager")
	var placement_tool = scene.get_node("PlacementTool")
	var game_ui = scene.get_node("GameUI")
	var grid_toggle := game_ui.find_child("GridToggle", true, false) as Button
	var tile = grid.get_tile(Vector2i(6, 6))
	if tile == null:
		_fail("Contextual grid check could not find its sample tile.")
		return
	if bool(grid.show_grid):
		_fail("Macro grid should be opt-in on first load.")
		return
	if grid_toggle == null or grid_toggle.button_pressed or grid_toggle.text != "Grid  OFF":
		_fail("Grid view toggle should start in the visible OFF state.")
		return
	var view_row := grid_toggle.get_parent() as HBoxContainer
	if view_row == null or view_row.name != "ViewToggleRow" or view_row.get_child_count() != 3:
		_fail("Grid view toggle should stay in the compact visible view-control row.")
		return
	if not _expect_macro_grid_visibility(grid, false, "first load"):
		return

	placement_tool.call("set_tool", "place")
	placement_tool.call("set_selected_item", "flower_patch")
	placement_tool.call("_set_hovered_tile", tile)
	placement_tool.call("_update_preview_visibility")
	var hover_frame := tile.get_node_or_null("HoverFrame") as Node3D
	var placement_preview = placement_tool.get("_preview") as Node3D
	if hover_frame == null or not hover_frame.visible:
		_fail("Local hover frame should stay visible while the macro grid is off.")
		return
	if placement_preview == null or not placement_preview.visible:
		_fail("Placement preview should stay visible while the macro grid is off.")
		return
	if tile.get_node("GridLines").visible:
		_fail("Hovering a tile should not re-enable the full macro grid.")
		return

	grid_toggle.set_pressed_no_signal(true)
	grid_toggle.toggled.emit(true)
	await process_frame
	if not bool(grid.show_grid) or grid_toggle.text != "Grid  ON":
		_fail("Grid view toggle did not enable the macro grid.")
		return
	if not _expect_macro_grid_visibility(grid, true, "manual grid toggle on"):
		return
	if not hover_frame.visible:
		_fail("Manual macro-grid visibility should not suppress local hover feedback.")
		return

	grid_toggle.set_pressed_no_signal(false)
	grid_toggle.toggled.emit(false)
	await process_frame
	if bool(grid.show_grid) or grid_toggle.text != "Grid  OFF":
		_fail("Grid view toggle did not restore the opt-in grid state.")
		return
	if not _expect_macro_grid_visibility(grid, false, "manual grid toggle off"):
		return
	if not hover_frame.visible:
		_fail("Local hover feedback should remain after the macro grid is hidden again.")
		return
	if grid.get_tile_from_world(tile.global_position) != tile:
		_fail("Grid presentation changes should not alter gameplay tile targeting.")
		return

	placement_tool.call("_set_hovered_tile", null)
	placement_tool.call("_update_preview_visibility")
	if hover_frame.visible or placement_preview.visible:
		_fail("Clearing tile hover should hide both contextual feedback elements.")
		return

	scene.queue_free()
	await process_frame


func _expect_macro_grid_visibility(grid, expected_visible: bool, context: String) -> bool:
	for tile in grid.tiles.values():
		var grid_lines := tile.get_node_or_null("GridLines") as Node3D
		if grid_lines == null:
			_fail("%s tile is missing its macro grid frame." % context.capitalize())
			return false
		if grid_lines.visible != expected_visible:
			_fail("%s should keep every macro grid frame %s." % [
				context.capitalize(),
				"visible" if expected_visible else "hidden"
			])
			return false
	return true


func _test_reason_badge_has_readable_plate() -> void:
	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var marigold = _agent_actor(scene, "marigold")
	if marigold == null:
		_fail("Could not find Marigold for reason-badge polish check.")
		return

	var badge = marigold.get_node_or_null("VoxelRig/ReasonBadge")
	var plate = marigold.get_node_or_null("VoxelRig/ReasonBadgePlate")
	if badge == null or plate == null:
		_fail("Reason badge did not include both text and backing plate nodes.")
		return
	if not badge.visible or not plate.visible:
		_fail("Reason badge plate/text were not visible for the idle plan.")
		return
	if int(badge.outline_size) < 4:
		_fail("Reason badge text outline is too thin for in-world readability.")
		return

	scene.queue_free()
	await process_frame


func _test_reason_badge_pops_when_motive_changes() -> void:
	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var bert = _agent_actor(scene, "bert")
	if bert == null:
		_fail("Could not find Bert for reason-badge pop check.")
		return

	bert.call("start_directive", "clear_brush", Vector2i(1, 1), "memory work", {
		"social_preference_source": "memory",
		"social_preference_label": "Seed Bundle"
	})
	await process_frame

	var badge = bert.get_node_or_null("VoxelRig/ReasonBadge")
	var plate = bert.get_node_or_null("VoxelRig/ReasonBadgePlate")
	if badge == null or plate == null:
		_fail("Reason badge pop check could not find badge nodes.")
		return
	if str(badge.text) != "Memory":
		_fail("Reason badge did not switch to Memory before pop check.")
		return
	if float(badge.scale.x) <= 1.0 and float(plate.scale.x) <= 1.0:
		_fail("Reason badge did not pop when the active motive changed.")
		return

	scene.queue_free()
	await process_frame


func _agent_actor(scene: Node, agent_id: String):
	var agent_manager = scene.get_node("FarmWorld/AgentManager")
	for agent in agent_manager.agents:
		if str(agent.get("agent_id")) == agent_id:
			return agent
	return null


func _fail(message: String) -> void:
	_failed = true
	push_error(message)
	quit(1)
