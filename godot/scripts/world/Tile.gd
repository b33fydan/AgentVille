class_name Tile
extends Node3D

signal changed(tile)

const CropScene := preload("res://scenes/world/Crop.tscn")
const VoxelFactory := preload("res://scripts/core/Voxel.gd")
const LocalMegavoxAssets := preload("res://scripts/world/LocalMegavoxAssets.gd")
const MICRO_GRID_SIZE := 4
const TILE_TOP_SURFACE_Y := 0.09
const MICRO_CELL_EMBED := 0.001

var grid_pos: Vector2i
var terrain: String = "grass"
var is_tilled: bool = false
var crop
var decor_id: String = ""
var structure_id: String = ""
var tile_size: float = 1.0

var _top_mesh: MeshInstance3D
var _soil_mesh: MeshInstance3D
var _grid_root: Node3D
var _hover_root: Node3D
var _selected_root: Node3D
var _terrain_detail_root: Node3D
var _decor_root: Node3D
var _structure_root: Node3D
var _crop_root: Node3D
var _order_marker_root: Node3D
var _demand_marker_root: Node3D
var _wind_phase: float = 0.0


func setup(new_grid_pos: Vector2i, new_tile_size: float = 1.0) -> void:
	grid_pos = new_grid_pos
	tile_size = new_tile_size
	_wind_phase = float((grid_pos.x * 37 + grid_pos.y * 71) % 100) * 0.19
	_build_static()
	refresh()


func _process(delta: float) -> void:
	if _decor_root == null:
		return

	var t := Time.get_ticks_msec() * 0.001
	if decor_id == "tall_grass":
		_decor_root.rotation.x = sin(t * 1.55 + _wind_phase) * 0.025
		_decor_root.rotation.z = cos(t * 1.18 + _wind_phase) * 0.018
	else:
		_decor_root.rotation = Vector3.ZERO

	if _order_marker_root and _order_marker_root.visible:
		_order_marker_root.position.y = sin(t * 2.15 + _wind_phase) * 0.025
	if _demand_marker_root and _demand_marker_root.visible:
		_demand_marker_root.position.y = sin(t * 2.45 + _wind_phase + 1.3) * 0.028


func set_grid_visible(is_visible: bool) -> void:
	if _grid_root:
		_grid_root.visible = is_visible


func set_hovered(is_hovered: bool) -> void:
	if _hover_root:
		_hover_root.visible = is_hovered


func set_selected(is_selected: bool) -> void:
	if _selected_root:
		_selected_root.visible = is_selected


func set_order_marker(marker: Dictionary) -> void:
	if _order_marker_root == null:
		return

	_clear_children(_order_marker_root)
	if marker.is_empty() or str(marker.get("status", "")) == "done":
		_order_marker_root.visible = false
		return

	_order_marker_root.visible = true
	_build_order_marker(
		_order_marker_root,
		str(marker.get("action", "build_fence")),
		str(marker.get("status", "ready")),
		str(marker.get("status_text", ""))
	)


func set_demand_marker(demand: Dictionary) -> void:
	if _demand_marker_root == null:
		return

	_clear_children(_demand_marker_root)
	if demand.is_empty() or str(demand.get("status", "")) == "done":
		_demand_marker_root.visible = false
		return

	_demand_marker_root.visible = true
	_build_demand_marker(
		_demand_marker_root,
		str(demand.get("kind", "deliver_item")),
		str(demand.get("status", "open"))
	)


func pulse_demand_marker() -> void:
	if _demand_marker_root == null or not _demand_marker_root.visible:
		return

	var tween := create_tween()
	_demand_marker_root.scale = Vector3.ONE * 1.22
	tween.tween_property(_demand_marker_root, "scale", Vector3.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func pulse_order_marker() -> void:
	if _order_marker_root == null or not _order_marker_root.visible:
		return

	var tween := create_tween()
	_order_marker_root.scale = Vector3.ONE * 1.18
	tween.tween_property(_order_marker_root, "scale", Vector3.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func set_terrain(new_terrain: String) -> bool:
	terrain = new_terrain
	is_tilled = new_terrain == "soil"
	_clear_crop()
	decor_id = ""
	structure_id = ""
	refresh()
	_pulse()
	changed.emit(self)
	return true


func till() -> bool:
	if crop != null or structure_id != "" or terrain == "dirt_path":
		return false

	terrain = "soil"
	is_tilled = true
	decor_id = ""
	refresh()
	_pulse()
	changed.emit(self)
	return true


func plant_corn() -> bool:
	return plant_crop("corn")


func plant_wheat() -> bool:
	return plant_crop("wheat")


func plant_crop(crop_id: String) -> bool:
	if crop != null or not is_tilled or structure_id != "":
		return false

	crop = CropScene.instantiate()
	crop.setup(crop_id, 0)
	_crop_root.add_child(crop)
	refresh()
	_pulse()
	changed.emit(self)
	return true


func grow_crop() -> bool:
	if crop == null:
		return false
	return crop.grow()


func harvest() -> int:
	if crop == null or not crop.is_ready():
		return 0

	var value: int = crop.harvest_value()
	_clear_crop()
	terrain = "soil"
	is_tilled = true
	refresh()
	_pulse()
	changed.emit(self)
	return value


func can_apply_item(item_id: String) -> bool:
	match item_id:
		"grass_block", "dirt_path", "dirt_road":
			return true
		"soil":
			return crop == null and structure_id == "" and terrain != "dirt_path"
		"corn_seed", "wheat_seed":
			return crop == null and is_tilled and structure_id == ""
		"fence", "flower_patch", "tall_grass", "tree", "wooden_sign", "rock":
			return crop == null and structure_id == ""
		"barn", "silo", "well":
			return crop == null
		"pickaxe":
			return can_pickaxe()
		"sickle":
			return can_sickle()
	return false


func can_pickaxe() -> bool:
	return structure_id != "" or decor_id in ["rock", "fence", "tree", "wooden_sign"] or terrain == "dirt_path"


func can_sickle() -> bool:
	if crop != null:
		return crop.is_ready()
	return decor_id in ["tall_grass", "flower_patch"]


func break_with_pickaxe() -> bool:
	if not can_pickaxe():
		return false

	if structure_id != "":
		structure_id = ""
	elif decor_id in ["rock", "fence", "tree", "wooden_sign"]:
		decor_id = ""
	elif terrain == "dirt_path":
		terrain = "grass"
		is_tilled = false

	refresh()
	_pulse()
	changed.emit(self)
	return true


func cut_with_sickle() -> int:
	if crop != null:
		return harvest()

	if decor_id in ["tall_grass", "flower_patch"]:
		decor_id = ""
		refresh()
		_pulse()
		changed.emit(self)
		return -1

	return 0


func place_item(item_id: String) -> bool:
	match item_id:
		"grass_block":
			return set_terrain("grass")
		"dirt_path", "dirt_road":
			return set_terrain("dirt_path")
		"soil":
			return till()
		"corn_seed":
			return plant_corn()
		"wheat_seed":
			return plant_wheat()
		"fence", "flower_patch", "tall_grass", "tree", "wooden_sign", "rock":
			if crop != null or structure_id != "":
				return false
			decor_id = item_id
			structure_id = ""
			is_tilled = false
			if terrain == "soil":
				terrain = "grass"
			refresh()
			_pulse()
			changed.emit(self)
			return true
		"barn", "silo", "well":
			if crop != null:
				return false
			structure_id = item_id
			decor_id = ""
			is_tilled = false
			terrain = "grass"
			refresh()
			_pulse()
			changed.emit(self)
			return true
	return false


func erase() -> bool:
	var had_content := crop != null or decor_id != "" or structure_id != "" or is_tilled or terrain != "grass"
	if not had_content:
		return false

	_clear_crop()
	decor_id = ""
	structure_id = ""
	terrain = "grass"
	is_tilled = false
	refresh()
	_pulse()
	changed.emit(self)
	return true


func refresh() -> void:
	if _top_mesh:
		_top_mesh.material_override = VoxelFactory.material(_top_color())
	if _soil_mesh:
		_soil_mesh.visible = is_tilled

	_clear_children(_decor_root)
	_clear_children(_structure_root)
	_clear_children(_terrain_detail_root)
	_build_micro_detail_layer(_terrain_detail_root)

	if terrain == "dirt_path":
		_build_dirt_road_details(_terrain_detail_root)

	match decor_id:
		"fence":
			_build_fence(_decor_root)
		"flower_patch":
			_build_flower_patch(_decor_root)
		"tall_grass":
			_build_tall_grass(_decor_root)
		"tree":
			_build_tree(_decor_root)
		"wooden_sign":
			_build_wooden_sign(_decor_root)
		"rock":
			_build_rock(_decor_root)

	match structure_id:
		"barn":
			_build_barn(_structure_root)
		"silo":
			_build_silo(_structure_root)
		"well":
			_build_well(_structure_root)


func _build_static() -> void:
	_clear_children(self)

	add_child(VoxelFactory.cube("DirtCore", Vector3(0.98, 0.34, 0.98), Color("#a66b42"), Vector3(0.0, -0.18, 0.0)))
	add_child(VoxelFactory.cube("LowerLip", Vector3(0.92, 0.08, 0.92), Color("#7f563d"), Vector3(0.0, -0.39, 0.0)))

	_top_mesh = VoxelFactory.cube("TileTop", Vector3(0.98, 0.10, 0.98), _top_color(), Vector3(0.0, 0.04, 0.0))
	add_child(_top_mesh)

	_soil_mesh = VoxelFactory.cube("TilledSoil", Vector3(0.78, 0.018, 0.78), Color("#845136"), Vector3(0.0, 0.082, 0.0))
	add_child(_soil_mesh)

	_grid_root = Node3D.new()
	_grid_root.name = "GridLines"
	add_child(_grid_root)
	_build_frame(_grid_root, Color("#503d30"), 0.025, 0.13)

	_hover_root = Node3D.new()
	_hover_root.name = "HoverFrame"
	add_child(_hover_root)
	_build_frame(_hover_root, Color("#fff1a8"), 0.055, 0.19)
	_hover_root.visible = false

	_selected_root = Node3D.new()
	_selected_root.name = "SelectedFrame"
	add_child(_selected_root)
	_build_frame(_selected_root, Color("#79d8c0"), 0.072, 0.215)
	_selected_root.visible = false

	_terrain_detail_root = Node3D.new()
	_terrain_detail_root.name = "TerrainDetails"
	add_child(_terrain_detail_root)

	_decor_root = Node3D.new()
	_decor_root.name = "Decor"
	add_child(_decor_root)

	_structure_root = Node3D.new()
	_structure_root.name = "Structure"
	add_child(_structure_root)

	_crop_root = Node3D.new()
	_crop_root.name = "Crop"
	add_child(_crop_root)

	_order_marker_root = Node3D.new()
	_order_marker_root.name = "OrderMarker"
	add_child(_order_marker_root)
	_order_marker_root.visible = false

	_demand_marker_root = Node3D.new()
	_demand_marker_root.name = "DemandMarker"
	add_child(_demand_marker_root)
	_demand_marker_root.visible = false


func _top_color() -> Color:
	match terrain:
		"dirt_path":
			return Color("#e9c782")
		"soil":
			return Color("#9a613d")
		_:
			return Color("#a8cf65")


func micro_detail_grid_size() -> int:
	return MICRO_GRID_SIZE


func micro_detail_count() -> int:
	var micro_root := get_node_or_null("TerrainDetails/MicroCells")
	if micro_root == null:
		return 0
	return micro_root.get_child_count()


func micro_detail_surface_id() -> String:
	return _micro_surface_id()


func blocks_agent_movement() -> bool:
	return structure_id != "" or decor_id in ["rock", "fence", "tree", "wooden_sign"]


func item_blocks_agent_movement(item_id: String) -> bool:
	return item_id in ["barn", "silo", "well", "rock", "fence", "tree", "wooden_sign"]


func agent_walk_surface_y() -> float:
	var detail_size := _micro_cell_size(Vector2i.ZERO)
	return TILE_TOP_SURFACE_Y + detail_size.y - MICRO_CELL_EMBED


func _build_frame(root: Node3D, color: Color, thickness: float, y: float) -> void:
	root.add_child(VoxelFactory.cube("North", Vector3(0.98, thickness, thickness), color, Vector3(0.0, y, -0.49)))
	root.add_child(VoxelFactory.cube("South", Vector3(0.98, thickness, thickness), color, Vector3(0.0, y, 0.49)))
	root.add_child(VoxelFactory.cube("West", Vector3(thickness, thickness, 0.98), color, Vector3(-0.49, y, 0.0)))
	root.add_child(VoxelFactory.cube("East", Vector3(thickness, thickness, 0.98), color, Vector3(0.49, y, 0.0)))


func _build_micro_detail_layer(root: Node3D) -> void:
	var micro_root := Node3D.new()
	micro_root.name = "MicroCells"
	root.add_child(micro_root)
	for x in range(MICRO_GRID_SIZE):
		for z in range(MICRO_GRID_SIZE):
			var cell := Vector2i(x, z)
			var detail_size := _micro_cell_size(cell)
			var detail := VoxelFactory.cube(
				"MicroCell_%s_%s" % [x, z],
				detail_size,
				_micro_cell_color(cell),
				_micro_cell_position(cell, detail_size)
			)
			detail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			micro_root.add_child(detail)


func _micro_cell_position(cell: Vector2i, detail_size: Vector3) -> Vector3:
	var cell_size := tile_size / float(MICRO_GRID_SIZE)
	var x := -tile_size * 0.5 + cell_size * 0.5 + float(cell.x) * cell_size
	var z := -tile_size * 0.5 + cell_size * 0.5 + float(cell.y) * cell_size
	var y := TILE_TOP_SURFACE_Y + detail_size.y * 0.5 - MICRO_CELL_EMBED
	return Vector3(x, y, z)


func _micro_cell_size(cell: Vector2i) -> Vector3:
	match _micro_surface_id():
		"corn_crop_soil":
			return Vector3(0.230, 0.054, 0.200)
		"wheat_crop_soil":
			return Vector3(0.200, 0.054, 0.230)
		"crop_soil":
			return Vector3(0.230, 0.054, 0.200)
		"soil":
			return Vector3(0.200, 0.054, 0.230)
		"dirt_path":
			return Vector3(0.225, 0.040, 0.225)
		"decor_grass":
			return Vector3(0.230, 0.036, 0.230)
		"foundation_grass":
			return Vector3(0.230, 0.035, 0.230)
		_:
			return Vector3(0.230, 0.036, 0.230)


func _micro_cell_color(cell: Vector2i) -> Color:
	var seed := _micro_pattern_seed(cell)
	match _micro_surface_id():
		"corn_crop_soil":
			var corn_soil_colors := [Color("#7c4b31"), Color("#9f6842"), Color("#6c422d"), Color("#b37a4a")]
			return corn_soil_colors[seed % corn_soil_colors.size()]
		"wheat_crop_soil":
			var wheat_soil_colors := [Color("#8b5b34"), Color("#b47a45"), Color("#c69250"), Color("#755033")]
			return wheat_soil_colors[seed % wheat_soil_colors.size()]
		"crop_soil":
			var crop_soil_colors := [Color("#7c4b31"), Color("#9f6842"), Color("#6c422d"), Color("#b37a4a")]
			return crop_soil_colors[seed % crop_soil_colors.size()]
		"soil":
			var soil_colors := [Color("#70452f"), Color("#845136"), Color("#9b6040"), Color("#623d2b")]
			return soil_colors[seed % soil_colors.size()]
		"dirt_path":
			var path_colors := [Color("#f0d08b"), Color("#d7aa66"), Color("#e5bd78"), Color("#c89457")]
			return path_colors[seed % path_colors.size()]
		"decor_grass":
			var decor_grass_colors := [Color("#a6d26b"), Color("#7fb75a"), Color("#c8de78"), Color("#6fa24f")]
			return decor_grass_colors[seed % decor_grass_colors.size()]
		"foundation_grass":
			var foundation_colors := [Color("#729e50"), Color("#85ad58"), Color("#668d48"), Color("#93bd66")]
			return foundation_colors[seed % foundation_colors.size()]
		_:
			var grass_colors := [Color("#b7da72"), Color("#93c260"), Color("#c6e27a"), Color("#84b857")]
			return grass_colors[seed % grass_colors.size()]


func _micro_pattern_seed(cell: Vector2i) -> int:
	var pattern_cell := cell
	match _micro_surface_id():
		"soil", "wheat_crop_soil":
			pattern_cell = Vector2i(cell.x, 0)
		"corn_crop_soil", "crop_soil":
			pattern_cell = Vector2i(0, cell.y)
		"grass", "decor_grass", "foundation_grass":
			pattern_cell = Vector2i(int(cell.x / 2), int(cell.y / 2))
	return int(abs(grid_pos.x * 31 + grid_pos.y * 47 + pattern_cell.x * 13 + pattern_cell.y * 17))


func _micro_surface_id() -> String:
	if crop != null:
		match str(crop.crop_id):
			"corn":
				return "corn_crop_soil"
			"wheat":
				return "wheat_crop_soil"
		return "crop_soil"
	if is_tilled:
		return "soil"
	if terrain == "dirt_path":
		return "dirt_path"
	if structure_id != "":
		return "foundation_grass"
	if decor_id != "":
		return "decor_grass"
	return "grass"


func _road_detail_seed() -> int:
	return int(abs(grid_pos.x * 19 + grid_pos.y * 23))


func _build_dirt_road_details(root: Node3D) -> void:
	var seed := _road_detail_seed()
	var edge_colors := [Color("#d6ad6b"), Color("#e0b977"), Color("#c99b5f")]
	var pebble_colors := [Color("#b88755"), Color("#9f774f"), Color("#c0915c")]
	var edge: Color = edge_colors[seed % edge_colors.size()]
	var pebble: Color = pebble_colors[int(seed / 3) % pebble_colors.size()]
	var edge_shift := (float(seed % 5) - 2.0) * 0.010
	var edge_a_width := 0.72 + float(seed % 4) * 0.035
	var edge_b_width := 0.72 + float(int(seed / 5) % 4) * 0.035
	var pebble_a_size := Vector3(0.07 + float(seed % 3) * 0.012, 0.025, 0.05 + float(int(seed / 7) % 3) * 0.010)
	var pebble_b_size := Vector3(0.05 + float(int(seed / 11) % 3) * 0.012, 0.025, 0.06 + float(int(seed / 13) % 3) * 0.010)
	var pebble_a_pos := Vector3(-0.28 + float(seed % 6) * 0.045, 0.1405, -0.12 + float(int(seed / 5) % 5) * 0.040)
	var pebble_b_pos := Vector3(0.08 + float(int(seed / 7) % 6) * 0.040, 0.1405, 0.03 + float(int(seed / 11) % 5) * 0.040)
	root.add_child(VoxelFactory.cube("RoadEdgeA", Vector3(edge_a_width, 0.025, 0.035), edge, Vector3(edge_shift, 0.14, -0.32)))
	root.add_child(VoxelFactory.cube("RoadEdgeB", Vector3(edge_b_width, 0.025, 0.035), edge, Vector3(-edge_shift, 0.14, 0.32)))
	root.add_child(VoxelFactory.cube("PebbleA", pebble_a_size, pebble, pebble_a_pos))
	root.add_child(VoxelFactory.cube("PebbleB", pebble_b_size, pebble, pebble_b_pos))


func _build_fence(root: Node3D) -> void:
	if LocalMegavoxAssets.add_prop(root, "fence", "MegavoxFence", Vector3(0.0, 0.13, 0.0)):
		return

	var post := Color("#9c6a3e")
	var rail := Color("#bd8147")
	root.add_child(VoxelFactory.cube("PostA", Vector3(0.12, 0.58, 0.12), post, Vector3(-0.32, 0.40, 0.0)))
	root.add_child(VoxelFactory.cube("PostB", Vector3(0.12, 0.58, 0.12), post, Vector3(0.32, 0.40, 0.0)))
	root.add_child(VoxelFactory.cube("RailLow", Vector3(0.82, 0.11, 0.10), rail, Vector3(0.0, 0.30, 0.0)))
	root.add_child(VoxelFactory.cube("RailHigh", Vector3(0.82, 0.11, 0.10), rail, Vector3(0.0, 0.54, 0.0)))


func _build_flower_patch(root: Node3D) -> void:
	if LocalMegavoxAssets.add_prop(root, "flower_patch", "MegavoxFlowerPatch", Vector3(0.0, 0.14, 0.0)):
		return

	root.add_child(VoxelFactory.cube("FlowerSoil", Vector3(0.65, 0.08, 0.65), Color("#7d4e34"), Vector3(0.0, 0.16, 0.0)))
	var colors := [Color("#ef6f8f"), Color("#f6cf57"), Color("#8ab9ff"), Color("#ffffff")]
	var offsets := [Vector3(-0.22, 0.0, -0.12), Vector3(0.18, 0.0, -0.18), Vector3(-0.06, 0.0, 0.20), Vector3(0.22, 0.0, 0.16)]
	for i in range(offsets.size()):
		var offset: Vector3 = offsets[i]
		root.add_child(VoxelFactory.cube("Stem%s" % i, Vector3(0.06, 0.22, 0.06), Color("#4b8a3d"), Vector3(offset.x, 0.30, offset.z)))
		root.add_child(VoxelFactory.cube("Bloom%s" % i, Vector3(0.13, 0.13, 0.13), colors[i], Vector3(offset.x, 0.44, offset.z)))


func _build_tall_grass(root: Node3D) -> void:
	if _uses_tall_grass_variant() and LocalMegavoxAssets.add_prop(root, "tall_grass_alt", "MegavoxTallGrassAlt", Vector3(0.0, 0.14, 0.0)):
		return
	if LocalMegavoxAssets.add_prop(root, "tall_grass", "MegavoxTallGrass", Vector3(0.0, 0.14, 0.0)):
		return

	var colors := [Color("#6fa649"), Color("#80b957"), Color("#9bc765"), Color("#c6ba5a")]
	var offsets := [
		Vector3(-0.30, 0.0, -0.24), Vector3(-0.12, 0.0, -0.28), Vector3(0.10, 0.0, -0.24), Vector3(0.28, 0.0, -0.14),
		Vector3(-0.24, 0.0, -0.04), Vector3(-0.04, 0.0, -0.02), Vector3(0.18, 0.0, 0.00),
		Vector3(-0.28, 0.0, 0.20), Vector3(-0.06, 0.0, 0.22), Vector3(0.16, 0.0, 0.20), Vector3(0.32, 0.0, 0.12)
	]

	for i in range(offsets.size()):
		var offset: Vector3 = offsets[i]
		var blade_height := 0.34 + float((i * 13) % 5) * 0.055
		var blade_width := 0.045 + float(i % 3) * 0.01
		root.add_child(VoxelFactory.cube("TallGrass%s" % i, Vector3(blade_width, blade_height, blade_width), colors[i % colors.size()], Vector3(offset.x, 0.16 + blade_height * 0.5, offset.z)))
		if i % 3 == 0:
			root.add_child(VoxelFactory.cube("SeedTop%s" % i, Vector3(0.07, 0.10, 0.07), Color("#dfc76a"), Vector3(offset.x, 0.29 + blade_height, offset.z)))


func _build_tree(root: Node3D) -> void:
	if _uses_tree_variant() and LocalMegavoxAssets.add_prop(root, "tree_alt", "MegavoxTreeAlt", Vector3(0.0, 0.12, 0.0)):
		return
	if LocalMegavoxAssets.add_prop(root, "tree", "MegavoxTree", Vector3(0.0, 0.12, 0.0)):
		return

	root.add_child(VoxelFactory.cube("TreeShadow", Vector3(0.62, 0.025, 0.52), Color(0.22, 0.16, 0.10, 0.18), Vector3(0.0, 0.13, 0.0)))
	root.add_child(VoxelFactory.cube("TreeTrunk", Vector3(0.16, 0.62, 0.16), Color("#8a5a36"), Vector3(0.0, 0.48, 0.0)))
	root.add_child(VoxelFactory.cube("TreeCanopyLow", Vector3(0.68, 0.42, 0.62), Color("#5f9f47"), Vector3(0.0, 0.90, 0.0)))
	root.add_child(VoxelFactory.cube("TreeCanopyMid", Vector3(0.54, 0.38, 0.52), Color("#74b456"), Vector3(-0.05, 1.14, -0.03)))
	root.add_child(VoxelFactory.cube("TreeCanopyTop", Vector3(0.38, 0.30, 0.38), Color("#91c76c"), Vector3(0.06, 1.36, 0.04)))


func _build_wooden_sign(root: Node3D) -> void:
	var post := Color("#8f6139")
	var face := Color("#c88a4b")
	var trim := Color("#6f4930")
	root.add_child(VoxelFactory.cube("SignPost", Vector3(0.10, 0.50, 0.10), post, Vector3(0.0, 0.38, 0.08)))
	root.add_child(VoxelFactory.cube("SignFace", Vector3(0.54, 0.28, 0.08), face, Vector3(0.0, 0.68, -0.02)))
	root.add_child(VoxelFactory.cube("SignTrimTop", Vector3(0.58, 0.045, 0.09), trim, Vector3(0.0, 0.84, -0.02)))
	root.add_child(VoxelFactory.cube("SignTrimBottom", Vector3(0.58, 0.045, 0.09), trim, Vector3(0.0, 0.52, -0.02)))


func _build_rock(root: Node3D) -> void:
	if _uses_rock_variant() and LocalMegavoxAssets.add_prop(root, "rock_alt", "MegavoxRockAlt", Vector3(0.0, 0.14, 0.0)):
		return
	if LocalMegavoxAssets.add_prop(root, "rock", "MegavoxRock", Vector3(0.0, 0.14, 0.0)):
		return

	var stone := Color("#8b8c82")
	var light := Color("#aeb09f")
	var dark := Color("#66685f")
	root.add_child(VoxelFactory.cube("RockBase", Vector3(0.48, 0.22, 0.42), stone, Vector3(0.0, 0.23, 0.0)))
	root.add_child(VoxelFactory.cube("RockFaceA", Vector3(0.32, 0.28, 0.30), light, Vector3(-0.08, 0.38, -0.04)))
	root.add_child(VoxelFactory.cube("RockFaceB", Vector3(0.24, 0.20, 0.26), dark, Vector3(0.15, 0.33, 0.10)))
	root.add_child(VoxelFactory.cube("RockChip", Vector3(0.16, 0.12, 0.14), dark, Vector3(-0.28, 0.20, 0.18)))


func _uses_rock_variant() -> bool:
	return grid_pos.y >= 5


func _uses_tall_grass_variant() -> bool:
	return grid_pos.x == 0


func _uses_tree_variant() -> bool:
	return grid_pos.x <= 4


func _build_barn(root: Node3D) -> void:
	root.add_child(VoxelFactory.cube("BarnBody", Vector3(1.18, 0.92, 1.02), Color("#c94135"), Vector3(0.0, 0.58, 0.0)))
	root.add_child(VoxelFactory.cube("BarnTrimFront", Vector3(0.18, 0.76, 0.04), Color("#f7ead8"), Vector3(0.0, 0.52, -0.53)))
	root.add_child(VoxelFactory.cube("BarnDoor", Vector3(0.42, 0.50, 0.05), Color("#873326"), Vector3(0.0, 0.38, -0.56)))
	root.add_child(VoxelFactory.cube("BarnWindow", Vector3(0.26, 0.23, 0.055), Color("#f9e9d6"), Vector3(0.0, 0.84, -0.56)))
	root.add_child(VoxelFactory.cube("RoofMain", Vector3(1.36, 0.26, 1.18), Color("#5b3f34"), Vector3(0.0, 1.11, 0.0)))
	root.add_child(VoxelFactory.cube("RoofCap", Vector3(1.08, 0.19, 0.96), Color("#6c4b3d"), Vector3(0.0, 1.28, 0.0)))
	root.add_child(VoxelFactory.cube("HayStack", Vector3(0.38, 0.34, 0.38), Color("#e9bc50"), Vector3(-0.44, 0.30, 0.44)))


func _build_silo(root: Node3D) -> void:
	var body := Color("#d9d1bc")
	var shade := Color("#bfb59e")
	var roof := Color("#b8483b")
	var band := Color("#8e7e65")
	root.add_child(VoxelFactory.cube("SiloBase", Vector3(0.74, 0.18, 0.74), Color("#a27652"), Vector3(0.0, 0.20, 0.0)))
	root.add_child(VoxelFactory.cube("SiloBodyLow", Vector3(0.62, 0.48, 0.62), body, Vector3(0.0, 0.52, 0.0)))
	root.add_child(VoxelFactory.cube("SiloBodyHigh", Vector3(0.56, 0.44, 0.56), shade, Vector3(0.0, 0.98, 0.0)))
	root.add_child(VoxelFactory.cube("SiloBandA", Vector3(0.66, 0.055, 0.66), band, Vector3(0.0, 0.73, 0.0)))
	root.add_child(VoxelFactory.cube("SiloBandB", Vector3(0.60, 0.055, 0.60), band, Vector3(0.0, 1.15, 0.0)))
	root.add_child(VoxelFactory.cube("SiloRoof", Vector3(0.72, 0.24, 0.72), roof, Vector3(0.0, 1.33, 0.0)))
	root.add_child(VoxelFactory.cube("SiloCap", Vector3(0.38, 0.15, 0.38), Color("#cf6655"), Vector3(0.0, 1.52, 0.0)))


func _build_well(root: Node3D) -> void:
	var stone := Color("#9c9588")
	var stone_dark := Color("#716d65")
	var wood := Color("#8f6139")
	var roof := Color("#b46f3b")
	root.add_child(VoxelFactory.cube("WellBase", Vector3(0.62, 0.28, 0.62), stone, Vector3(0.0, 0.26, 0.0)))
	root.add_child(VoxelFactory.cube("WellHole", Vector3(0.34, 0.08, 0.34), stone_dark, Vector3(0.0, 0.44, 0.0)))
	root.add_child(VoxelFactory.cube("WellPostA", Vector3(0.08, 0.70, 0.08), wood, Vector3(-0.30, 0.70, 0.0)))
	root.add_child(VoxelFactory.cube("WellPostB", Vector3(0.08, 0.70, 0.08), wood, Vector3(0.30, 0.70, 0.0)))
	root.add_child(VoxelFactory.cube("WellBeam", Vector3(0.72, 0.08, 0.08), wood, Vector3(0.0, 1.07, 0.0)))
	root.add_child(VoxelFactory.cube("WellRoofA", Vector3(0.82, 0.12, 0.52), roof, Vector3(0.0, 1.23, -0.12)))
	root.add_child(VoxelFactory.cube("WellRoofB", Vector3(0.70, 0.10, 0.42), Color("#c78348"), Vector3(0.0, 1.34, 0.10)))


func _build_order_marker(root: Node3D, action_id: String, status: String, _status_text: String) -> void:
	var color := _order_marker_color(action_id, status)
	var shade := color.darkened(0.28)
	var light := color.lightened(0.20)
	var offset := Vector3(0.31, 0.0, -0.31)

	root.add_child(VoxelFactory.cube("MarkerShadow", Vector3(0.34, 0.025, 0.24), Color(0.18, 0.14, 0.10, 0.20), Vector3(offset.x, 0.17, offset.z)))
	root.add_child(VoxelFactory.cube("MarkerPin", Vector3(0.055, 0.48, 0.055), shade, Vector3(offset.x - 0.12, 0.46, offset.z)))
	root.add_child(VoxelFactory.cube("MarkerFlag", Vector3(0.34, 0.22, 0.055), color, Vector3(offset.x + 0.07, 0.66, offset.z)))
	root.add_child(VoxelFactory.cube("MarkerFlagLip", Vector3(0.34, 0.045, 0.065), light, Vector3(offset.x + 0.07, 0.795, offset.z)))
	root.add_child(VoxelFactory.cube("MarkerTip", Vector3(0.10, 0.10, 0.07), light, Vector3(offset.x + 0.28, 0.66, offset.z)))

	match action_id:
		"build_fence":
			root.add_child(VoxelFactory.cube("FenceGlyphPost", Vector3(0.035, 0.17, 0.07), Color("#fff9df"), Vector3(offset.x + 0.00, 0.66, offset.z - 0.035)))
			root.add_child(VoxelFactory.cube("FenceGlyphRail", Vector3(0.20, 0.035, 0.075), Color("#fff9df"), Vector3(offset.x + 0.08, 0.66, offset.z - 0.035)))
		"clear_brush":
			var blade_a := VoxelFactory.cube("ClearGlyphBladeA", Vector3(0.20, 0.04, 0.075), Color("#fff9df"), Vector3(offset.x + 0.08, 0.68, offset.z - 0.035))
			blade_a.rotation.z = deg_to_rad(24.0)
			root.add_child(blade_a)
			var blade_b := VoxelFactory.cube("ClearGlyphBladeB", Vector3(0.15, 0.035, 0.075), Color("#fff9df"), Vector3(offset.x + 0.16, 0.61, offset.z - 0.035))
			blade_b.rotation.z = deg_to_rad(-28.0)
			root.add_child(blade_b)
		"harvest_crop":
			root.add_child(VoxelFactory.cube("HarvestGlyphStem", Vector3(0.045, 0.18, 0.075), Color("#fff9df"), Vector3(offset.x + 0.07, 0.65, offset.z - 0.035)))
			root.add_child(VoxelFactory.cube("HarvestGlyphHead", Vector3(0.13, 0.11, 0.075), Color("#fff9df"), Vector3(offset.x + 0.07, 0.76, offset.z - 0.035)))

	if status in ["queued", "gathering", "waiting"]:
		root.add_child(VoxelFactory.cube("StatusDot", Vector3(0.10, 0.10, 0.08), Color("#fff0a8"), Vector3(offset.x + 0.27, 0.83, offset.z - 0.04)))


func _build_demand_marker(root: Node3D, demand_kind: String, _status: String) -> void:
	var color := _demand_marker_color(demand_kind)
	var shade := color.darkened(0.30)
	var light := color.lightened(0.24)
	var cream := Color("#fff7dc")
	var offset := Vector3(-0.31, 0.0, -0.31)

	root.add_child(VoxelFactory.cube("DemandShadow", Vector3(0.32, 0.025, 0.24), Color(0.16, 0.11, 0.13, 0.22), Vector3(offset.x, 0.17, offset.z)))
	root.add_child(VoxelFactory.cube("DemandStem", Vector3(0.055, 0.42, 0.055), shade, Vector3(offset.x, 0.43, offset.z)))
	var badge := VoxelFactory.cube("DemandBadge", Vector3(0.28, 0.28, 0.06), color, Vector3(offset.x, 0.72, offset.z))
	badge.rotation.z = deg_to_rad(45.0)
	root.add_child(badge)
	var inset := VoxelFactory.cube("DemandBadgeInset", Vector3(0.18, 0.18, 0.065), light, Vector3(offset.x, 0.72, offset.z - 0.01))
	inset.rotation.z = deg_to_rad(45.0)
	root.add_child(inset)

	match demand_kind:
		"clear_brush":
			var blade := VoxelFactory.cube("DemandClearSlash", Vector3(0.18, 0.035, 0.075), cream, Vector3(offset.x, 0.72, offset.z - 0.045))
			blade.rotation.z = deg_to_rad(-24.0)
			root.add_child(blade)
		"harvest_crop":
			root.add_child(VoxelFactory.cube("DemandHarvestStem", Vector3(0.040, 0.16, 0.075), cream, Vector3(offset.x, 0.70, offset.z - 0.045)))
			root.add_child(VoxelFactory.cube("DemandHarvestHead", Vector3(0.12, 0.09, 0.075), cream, Vector3(offset.x, 0.80, offset.z - 0.045)))
		"build_fence":
			root.add_child(VoxelFactory.cube("DemandFencePost", Vector3(0.040, 0.15, 0.075), cream, Vector3(offset.x - 0.04, 0.72, offset.z - 0.045)))
			root.add_child(VoxelFactory.cube("DemandFenceRail", Vector3(0.18, 0.035, 0.075), cream, Vector3(offset.x + 0.03, 0.72, offset.z - 0.045)))


func _order_marker_color(action_id: String, status: String) -> Color:
	if status == "waiting":
		return Color("#c7b89d")
	if status == "gathering":
		return Color("#f2c94c")
	match action_id:
		"build_fence":
			return Color("#78a65a")
		"clear_brush":
			return Color("#65b99a")
		"harvest_crop":
			return Color("#e7b84e")
	return Color("#9fb7e8")


func _demand_marker_color(demand_kind: String) -> Color:
	match demand_kind:
		"clear_brush":
			return Color("#c86f74")
		"harvest_crop":
			return Color("#8e80c8")
		"build_fence":
			return Color("#4f9e8f")
	return Color("#c8924f")


func _clear_crop() -> void:
	if crop != null:
		crop.queue_free()
		crop = null


func _clear_children(node: Node) -> void:
	if node == null:
		return
	for child in node.get_children():
		child.free()


func _pulse() -> void:
	var tween := create_tween()
	scale = Vector3.ONE
	tween.tween_property(self, "scale", Vector3.ONE * 1.035, 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector3.ONE, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
