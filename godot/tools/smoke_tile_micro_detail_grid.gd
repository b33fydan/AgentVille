extends SceneTree

const MICRO_GRID_SIZE := 4
const EXPECTED_CONTACT_Y := 0.089
const CONTACT_TOLERANCE := 0.002
const SEAM_TOLERANCE := 0.026

var _has_failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var grid_manager = scene.get_node("FarmWorld/GridManager")
	if grid_manager.tiles.size() != grid_manager.width * grid_manager.height:
		_fail("Micro detail layer should not change the gameplay tile count.")
		return

	var tile = grid_manager.get_tile(Vector2i(6, 6))
	if tile == null:
		_fail("Could not inspect center gameplay tile.")
		return
	if not tile.has_method("micro_detail_grid_size") or tile.call("micro_detail_grid_size") != MICRO_GRID_SIZE:
		_fail("Tile should expose a 4x4 visual micro-detail grid.")
		return
	if not tile.has_method("micro_detail_count") or tile.call("micro_detail_count") != 16:
		_fail("Tile should render 16 visual micro-detail cells.")
		return
	if not tile.has_method("micro_detail_surface_id"):
		_fail("Tile should expose its visual-only micro-detail surface id.")
		return

	_expect_micro_surface(tile, "grass", "plain grass tile")
	_expect_packed_micro_surface(tile, 0.82, "square", "plain grass tile")
	_expect_patch_color_coherence(tile, "plain grass tile")
	if _has_failed:
		return
	var grass_signature := _micro_detail_signature(tile, "plain grass tile")
	tile.refresh()
	if grass_signature != _micro_detail_signature(tile, "refreshed plain grass tile"):
		_fail("Refreshing a tile should preserve its deterministic packed surface pattern.")
		return
	var adjacent_grass_tile = grid_manager.get_tile(Vector2i(7, 6))
	_expect_micro_surface(adjacent_grass_tile, "grass", "adjacent plain grass tile")
	_expect_packed_micro_surface(adjacent_grass_tile, 0.82, "square", "adjacent plain grass tile")
	if _has_failed:
		return
	if grass_signature == _micro_detail_signature(adjacent_grass_tile, "adjacent plain grass tile"):
		_fail("Adjacent grass tiles should keep deterministic palette variation.")
		return
	_expect_cross_tile_continuity(tile, adjacent_grass_tile, "x", "adjacent grass tiles")
	if _has_failed:
		return

	var path_tile = grid_manager.get_tile(Vector2i(5, 4))
	var adjacent_path_tile = grid_manager.get_tile(Vector2i(6, 4))
	_expect_micro_surface(path_tile, "dirt_path", "dirt path tile")
	_expect_packed_micro_surface(path_tile, 0.78, "square", "dirt path tile")
	_expect_micro_surface(adjacent_path_tile, "dirt_path", "adjacent dirt path tile")
	_expect_packed_micro_surface(adjacent_path_tile, 0.78, "square", "adjacent dirt path tile")
	_expect_cross_tile_continuity(path_tile, adjacent_path_tile, "x", "adjacent dirt path tiles")
	if _has_failed:
		return
	var path_detail_signature := _road_detail_signature(path_tile, "dirt path tile")
	var adjacent_detail_signature := _road_detail_signature(adjacent_path_tile, "adjacent dirt path tile")
	if _has_failed:
		return
	if path_detail_signature == adjacent_detail_signature:
		_fail("Adjacent dirt path tiles should vary their visual-only edge and pebble details.")
		return

	var crop_tile = grid_manager.get_tile(Vector2i(1, 5))
	_expect_micro_surface(crop_tile, "corn_crop_soil", "planted corn tile")
	_expect_packed_micro_surface(crop_tile, 0.70, "x", "planted corn tile")
	_expect_row_color_coherence(crop_tile, "x", "planted corn tile")
	if _has_failed:
		return

	var wheat_tile = grid_manager.get_tile(Vector2i(1, 1))
	_expect_micro_surface(wheat_tile, "wheat_crop_soil", "planted wheat tile")
	_expect_packed_micro_surface(wheat_tile, 0.70, "z", "planted wheat tile")
	_expect_row_color_coherence(wheat_tile, "z", "planted wheat tile")
	if _has_failed:
		return

	var decor_tile = grid_manager.get_tile(Vector2i(0, 6))
	_expect_micro_surface(decor_tile, "decor_grass", "decor tile")
	_expect_packed_micro_surface(decor_tile, 0.82, "square", "decor tile")
	_expect_patch_color_coherence(decor_tile, "decor tile")
	if _has_failed:
		return

	var structure_tile = grid_manager.get_tile(Vector2i(7, 1))
	_expect_micro_surface(structure_tile, "foundation_grass", "structure tile")
	_expect_packed_micro_surface(structure_tile, 0.82, "square", "structure tile")
	_expect_patch_color_coherence(structure_tile, "structure tile")
	if _has_failed:
		return

	for detail in _micro_cells(tile, "plain grass tile"):
		var sampled_tile = grid_manager.get_tile_from_world(
			tile.global_position + Vector3(detail.position.x, 0.0, detail.position.z)
		)
		if sampled_tile != tile:
			_fail("Every visual micro cell center should still resolve to its original gameplay tile.")
			return

	if not tile.till():
		_fail("Could not till the original gameplay tile after micro-detail rendering.")
		return
	_expect_micro_surface(tile, "soil", "freshly tilled gameplay tile")
	_expect_packed_micro_surface(tile, 0.70, "z", "freshly tilled gameplay tile")
	_expect_row_color_coherence(tile, "z", "freshly tilled gameplay tile")
	_expect_soil_bed_buried(tile, "freshly tilled gameplay tile")
	if _has_failed:
		return

	if not tile.plant_wheat():
		_fail("Could not plant wheat on the original gameplay tile after micro-detail rendering.")
		return
	_expect_micro_surface(tile, "wheat_crop_soil", "freshly planted gameplay tile")
	_expect_packed_micro_surface(tile, 0.70, "z", "freshly planted gameplay tile")
	_expect_row_color_coherence(tile, "z", "freshly planted gameplay tile")
	if _has_failed:
		return

	if not tile.erase():
		_fail("Could not clear the freshly planted gameplay tile after micro-detail rendering.")
		return
	if not tile.place_item("flower_patch"):
		_fail("Could not place decor on the original gameplay tile after micro-detail rendering.")
		return
	_expect_micro_surface(tile, "decor_grass", "refreshed decor gameplay tile")
	_expect_packed_micro_surface(tile, 0.82, "square", "refreshed decor gameplay tile")
	_expect_patch_color_coherence(tile, "refreshed decor gameplay tile")
	if _has_failed:
		return
	if grid_manager.get_tile(Vector2i(6, 6)) != tile:
		_fail("Micro detail should not replace the original gameplay tile.")
		return
	if tile.call("micro_detail_count") != 16:
		_fail("Refreshing tile decor should preserve the 4x4 visual micro-detail cells.")
		return

	quit()


func _expect_micro_surface(tile, expected_surface: String, context: String) -> void:
	if tile == null:
		_fail("Could not inspect %s." % context)
		return
	if tile.call("micro_detail_surface_id") != expected_surface:
		_fail("%s should use %s micro detail, saw %s." % [
			context,
			expected_surface,
			str(tile.call("micro_detail_surface_id"))
		])
		return
	var detail_count := int(tile.call("micro_detail_count"))
	if detail_count != 16:
		_fail("%s should keep 16 visual micro-detail cells, saw %s." % [context, detail_count])


func _expect_packed_micro_surface(tile, minimum_coverage: float, major_axis: String, context: String) -> void:
	var details: Array[MeshInstance3D] = _micro_cells(tile, context)
	if _has_failed:
		return
	var pitch: float = tile.tile_size / float(MICRO_GRID_SIZE)
	var footprint_area: float = 0.0
	for detail in details:
		var box_mesh: BoxMesh = detail.mesh as BoxMesh
		var size: Vector3 = box_mesh.size
		footprint_area += size.x * size.z
		if size.x >= pitch or size.z >= pitch or size.x <= 0.0 or size.z <= 0.0:
			_fail("%s micro cells should be positive blocks that stay inside their visual grid pitch." % context)
			return
		var contact_y: float = detail.position.y - size.y * 0.5
		if abs(contact_y - EXPECTED_CONTACT_Y) > CONTACT_TOLERANCE:
			_fail("%s micro cells should contact the TileTop support plane; saw bottom %.4f." % [context, contact_y])
			return
		if abs(detail.position.x) + size.x * 0.5 > 0.491 or abs(detail.position.z) + size.z * 0.5 > 0.491:
			_fail("%s micro cells should remain inside the gameplay tile footprint." % context)
			return
	var coverage: float = footprint_area / (tile.tile_size * tile.tile_size)
	if coverage < minimum_coverage:
		_fail("%s should cover at least %.0f%% of its tile footprint, saw %.1f%%." % [
			context,
			minimum_coverage * 100.0,
			coverage * 100.0
		])
		return

	match major_axis:
		"square":
			for detail in details:
				var size: Vector3 = (detail.mesh as BoxMesh).size
				if size.x < pitch * 0.88 or size.z < pitch * 0.88:
					_fail("%s should use broad, square voxel pavers rather than sparse inserts." % context)
					return
			_expect_internal_continuity(tile, "x", context)
			_expect_internal_continuity(tile, "z", context)
		"x":
			for detail in details:
				var size: Vector3 = (detail.mesh as BoxMesh).size
				if size.x < pitch * 0.90 or size.z < pitch * 0.78 or size.x - size.z < 0.025:
					_fail("%s should form broad, connected voxel rows along x." % context)
					return
			_expect_internal_continuity(tile, "x", context)
		"z":
			for detail in details:
				var size: Vector3 = (detail.mesh as BoxMesh).size
				if size.z < pitch * 0.90 or size.x < pitch * 0.78 or size.z - size.x < 0.025:
					_fail("%s should form broad, connected voxel rows along z." % context)
					return
			_expect_internal_continuity(tile, "z", context)
		_:
			_fail("Unknown packed-surface axis %s for %s." % [major_axis, context])


func _expect_internal_continuity(tile, axis: String, context: String) -> void:
	if _has_failed:
		return
	for fixed_index in range(MICRO_GRID_SIZE):
		for moving_index in range(MICRO_GRID_SIZE - 1):
			var left_cell := Vector2i(moving_index, fixed_index) if axis == "x" else Vector2i(fixed_index, moving_index)
			var right_cell := Vector2i(moving_index + 1, fixed_index) if axis == "x" else Vector2i(fixed_index, moving_index + 1)
			var left := _micro_cell(tile, left_cell, context)
			var right := _micro_cell(tile, right_cell, context)
			if _has_failed:
				return
			var left_size: Vector3 = (left.mesh as BoxMesh).size
			var right_size: Vector3 = (right.mesh as BoxMesh).size
			var center_distance: float = abs(right.position.x - left.position.x) if axis == "x" else abs(right.position.z - left.position.z)
			var left_extent: float = left_size.x * 0.5 if axis == "x" else left_size.z * 0.5
			var right_extent: float = right_size.x * 0.5 if axis == "x" else right_size.z * 0.5
			var seam: float = center_distance - left_extent - right_extent
			if seam < -0.001 or seam > SEAM_TOLERANCE:
				_fail("%s should use near-contiguous voxel blocks along %s; saw seam %.4f." % [context, axis, seam])
				return


func _expect_cross_tile_continuity(first_tile, second_tile, axis: String, context: String) -> void:
	for fixed_index in range(MICRO_GRID_SIZE):
		var first_cell := Vector2i(MICRO_GRID_SIZE - 1, fixed_index) if axis == "x" else Vector2i(fixed_index, MICRO_GRID_SIZE - 1)
		var second_cell := Vector2i(0, fixed_index) if axis == "x" else Vector2i(fixed_index, 0)
		var first := _micro_cell(first_tile, first_cell, context)
		var second := _micro_cell(second_tile, second_cell, context)
		if _has_failed:
			return
		var first_size: Vector3 = (first.mesh as BoxMesh).size
		var second_size: Vector3 = (second.mesh as BoxMesh).size
		var first_center: Vector3 = first_tile.global_position + first.position
		var second_center: Vector3 = second_tile.global_position + second.position
		var center_distance: float = abs(second_center.x - first_center.x) if axis == "x" else abs(second_center.z - first_center.z)
		var first_extent: float = first_size.x * 0.5 if axis == "x" else first_size.z * 0.5
		var second_extent: float = second_size.x * 0.5 if axis == "x" else second_size.z * 0.5
		var seam: float = center_distance - first_extent - second_extent
		if seam < -0.001 or seam > SEAM_TOLERANCE:
			_fail("%s should remain near-contiguous across gameplay tile boundaries; saw seam %.4f." % [context, seam])
			return


func _expect_patch_color_coherence(tile, context: String) -> void:
	for patch_x in range(2):
		for patch_z in range(2):
			var expected := _micro_color(_micro_cell(tile, Vector2i(patch_x * 2, patch_z * 2), context), context)
			for offset_x in range(2):
				for offset_z in range(2):
					var actual := _micro_color(_micro_cell(tile, Vector2i(patch_x * 2 + offset_x, patch_z * 2 + offset_z), context), context)
					if not actual.is_equal_approx(expected):
						_fail("%s should group grass color into readable 2x2 voxel patches." % context)
						return


func _expect_row_color_coherence(tile, axis: String, context: String) -> void:
	for row in range(MICRO_GRID_SIZE):
		var first_cell := Vector2i(0, row) if axis == "x" else Vector2i(row, 0)
		var expected := _micro_color(_micro_cell(tile, first_cell, context), context)
		for step in range(1, MICRO_GRID_SIZE):
			var cell := Vector2i(step, row) if axis == "x" else Vector2i(row, step)
			var actual := _micro_color(_micro_cell(tile, cell, context), context)
			if not actual.is_equal_approx(expected):
				_fail("%s should keep each voxel furrow color coherent along %s." % [context, axis])
				return


func _expect_soil_bed_buried(tile, context: String) -> void:
	var soil_bed := tile.get_node_or_null("TilledSoil") as MeshInstance3D
	if soil_bed == null or not soil_bed.visible or not soil_bed.mesh is BoxMesh:
		_fail("%s should retain its mesh-backed tilled-soil seam bed." % context)
		return
	var top_y := soil_bed.position.y + (soil_bed.mesh as BoxMesh).size.y * 0.5
	if top_y > 0.092:
		_fail("%s tilled-soil bed should stay buried under the packed voxel furrows." % context)


func _micro_cells(tile, context: String) -> Array[MeshInstance3D]:
	var details: Array[MeshInstance3D] = []
	for x in range(MICRO_GRID_SIZE):
		for z in range(MICRO_GRID_SIZE):
			var detail := _micro_cell(tile, Vector2i(x, z), context)
			if _has_failed:
				return details
			details.append(detail)
	if details.size() != 16:
		_fail("%s should expose exactly 16 mesh-backed micro cells." % context)
	return details


func _micro_cell(tile, cell: Vector2i, context: String) -> MeshInstance3D:
	if tile == null:
		_fail("Could not inspect %s micro detail cell." % context)
		return null
	var detail := tile.get_node_or_null("TerrainDetails/MicroCells/MicroCell_%s_%s" % [cell.x, cell.y]) as MeshInstance3D
	if detail == null:
		_fail("%s should render MicroCell_%s_%s." % [context, cell.x, cell.y])
		return null
	if not detail.mesh is BoxMesh:
		_fail("%s should use a box mesh for MicroCell_%s_%s." % [context, cell.x, cell.y])
		return null
	return detail


func _micro_color(detail: MeshInstance3D, context: String) -> Color:
	if detail == null:
		return Color.BLACK
	var material := detail.material_override as StandardMaterial3D
	if material == null:
		_fail("%s micro cells should use a StandardMaterial3D color." % context)
		return Color.BLACK
	return material.albedo_color


func _micro_detail_signature(tile, context: String) -> String:
	var signature: Array[String] = []
	for detail in _micro_cells(tile, context):
		var size: Vector3 = (detail.mesh as BoxMesh).size
		var color: Color = _micro_color(detail, context)
		signature.append("%s|%s|%s" % [str(detail.position), str(size), str(color)])
	return ";".join(signature)


func _road_detail_signature(tile, context: String) -> String:
	var edge := tile.get_node_or_null("TerrainDetails/RoadEdgeA") as MeshInstance3D
	var pebble := tile.get_node_or_null("TerrainDetails/PebbleA") as MeshInstance3D
	if edge == null or pebble == null:
		_fail("%s should render road edge and pebble detail nodes." % context)
		return ""
	if not edge.mesh is BoxMesh or not pebble.mesh is BoxMesh:
		_fail("%s should render box-mesh road detail nodes." % context)
		return ""
	var path_cell := _micro_cell(tile, Vector2i(0, 0), context)
	var path_top := path_cell.position.y + (path_cell.mesh as BoxMesh).size.y * 0.5
	var pebble_bottom := pebble.position.y - (pebble.mesh as BoxMesh).size.y * 0.5
	if abs(path_top - pebble_bottom) > CONTACT_TOLERANCE:
		_fail("%s pebble detail should contact the packed path surface." % context)
		return ""
	return "%s|%s|%s|%s" % [
		str(edge.position),
		str((edge.mesh as BoxMesh).size),
		str(pebble.position),
		str((pebble.mesh as BoxMesh).size)
	]


func _fail(message: String) -> void:
	_has_failed = true
	push_error(message)
	quit(1)
