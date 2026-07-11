class_name VoxelIcon
extends SubViewportContainer

const VoxelFactory := preload("res://scripts/core/Voxel.gd")
const LocalMegavoxAssets := preload("res://scripts/world/LocalMegavoxAssets.gd")

const CREAM := Color("#fff2cf")
const MOSS := Color("#789b45")
const MOSS_LIGHT := Color("#9fc461")
const SOIL := Color("#7b4931")
const SOIL_LIGHT := Color("#a2653d")
const PATH := Color("#d8ae68")
const PATH_LIGHT := Color("#efd18d")
const WOOD := Color("#8a5735")
const WOOD_LIGHT := Color("#bd7b43")
const STONE := Color("#777970")
const STONE_LIGHT := Color("#a9aa9b")
const GOLD := Color("#e4ae35")
const BARN_RED := Color("#b84332")
const WATER := Color("#4c94a8")
const INK := Color("#30251d")

var icon_id: String = ""
var source_kind: String = "procedural"
var _model_root: Node3D


func configure(new_icon_id: String, pixel_size: int = 88) -> void:
	icon_id = new_icon_id
	name = "VoxelIcon"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	stretch = true
	custom_minimum_size = Vector2(44, 42)

	var viewport := SubViewport.new()
	viewport.name = "IconViewport"
	viewport.size = Vector2i(pixel_size, pixel_size)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	viewport.msaa_3d = Viewport.MSAA_2X
	add_child(viewport)

	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0, 0, 0, 0)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#f4ead7")
	environment.ambient_light_energy = 0.72
	environment_node.environment = environment
	viewport.add_child(environment_node)

	var key := DirectionalLight3D.new()
	key.light_color = Color("#fff1d5")
	key.light_energy = 1.22
	key.shadow_enabled = false
	key.rotation_degrees = Vector3(-52.0, -38.0, 0.0)
	viewport.add_child(key)

	var camera := Camera3D.new()
	camera.name = "IconCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 1.62
	camera.position = Vector3(1.65, 1.38, 1.65)
	viewport.add_child(camera)
	camera.look_at(Vector3(0.0, 0.36, 0.0), Vector3.UP)

	_model_root = Node3D.new()
	_model_root.name = "IconModel"
	viewport.add_child(_model_root)
	_build_model()


func uses_local_asset() -> bool:
	return source_kind == "megavox"


func _build_model() -> void:
	_add_cube("Plinth", Vector3(0.92, 0.08, 0.92), Color("#ead7b6"), Vector3(0.0, 0.02, 0.0))
	match icon_id:
		"place":
			if not _try_megavox("icon_hammer", 0.78):
				_add_hammer()
		"till", "pickaxe":
			if not _try_megavox("icon_pickaxe", 0.80):
				_add_pickaxe()
		"plant", "order_plant_seed", "skill_plant_seed":
			_add_sprout()
		"harvest", "sickle", "order_harvest_crop", "skill_harvest_crop":
			_add_sickle()
			_add_crop(false, Vector3(-0.20, 0.0, 0.12))
		"erase", "order_clear_brush", "skill_clear_patch":
			if not _try_megavox("icon_pickaxe", 0.72):
				_add_pickaxe()
			_add_cross(Color("#d95b47"), Vector3(0.26, 0.58, -0.08))
		"pan":
			_add_pan_arrows()
		"grass_block":
			_add_ground_block(MOSS)
		"dirt_road":
			_add_ground_block(PATH)
			_add_cube("PaverA", Vector3(0.32, 0.05, 0.22), PATH_LIGHT, Vector3(-0.18, 0.30, -0.12))
			_add_cube("PaverB", Vector3(0.32, 0.05, 0.22), Color("#c89350"), Vector3(0.18, 0.30, 0.12))
		"soil":
			_add_ground_block(SOIL)
			for x in [-0.24, 0.0, 0.24]:
				_add_cube("Furrow%s" % str(x), Vector3(0.12, 0.08, 0.66), SOIL_LIGHT, Vector3(x, 0.31, 0.0))
		"corn_seed":
			_add_crop(false)
		"wheat_seed":
			_add_crop(true)
		"tall_grass":
			if not _try_megavox("tall_grass", 0.72):
				_add_grass_clump()
		"tree":
			if not _try_megavox("tree", 0.86):
				_add_tree()
		"flower_patch":
			if not _try_megavox("flower_patch", 0.68):
				_add_flowers()
		"rock":
			if not _try_megavox("rock", 0.62):
				_add_rock()
		"fence", "order_build_fence", "skill_build_fence":
			if not _try_megavox("icon_fence", 0.48):
				_add_fence()
		"wooden_sign":
			_add_sign()
		"barn":
			_add_barn()
		"silo":
			_add_silo()
		"well":
			_add_well()
		"craft_fence_kit":
			_add_crate(MOSS)
			_add_fence(Vector3(0.0, 0.08, 0.0), 0.72)
		"craft_seed_bundle":
			_add_crate(GOLD)
			_add_sprout(Vector3(0.0, 0.12, 0.0), 0.75)
		"craft_rush_kit":
			_add_crate(WATER)
			_add_pickaxe(Vector3(0.0, 0.04, 0.0), 0.72)
		"order_tend_crop", "skill_tend_crop":
			_add_crop(false, Vector3(-0.12, 0.0, 0.0))
			_add_droplet(Vector3(0.27, 0.58, 0.02))
		"view_ao":
			_add_cube("Light", Vector3(0.48, 0.48, 0.48), CREAM, Vector3(0.0, 0.34, 0.0))
			_add_cube("Shade", Vector3(0.24, 0.50, 0.50), Color("#64706a"), Vector3(0.18, 0.33, 0.0))
		"view_grid":
			_add_ground_block(MOSS)
			for offset in [-0.22, 0.22]:
				_add_cube("GridX%s" % str(offset), Vector3(0.04, 0.05, 0.88), CREAM, Vector3(offset, 0.32, 0.0))
				_add_cube("GridZ%s" % str(offset), Vector3(0.88, 0.05, 0.04), CREAM, Vector3(0.0, 0.32, offset))
		"view_shadows":
			_add_tree()
			_add_cube("Shadow", Vector3(0.58, 0.025, 0.34), Color("#5c5147"), Vector3(0.18, 0.10, 0.18))
		"parley":
			_add_speech_bubbles()
		"end_day":
			_add_sun()
		_:
			_add_crate(MOSS)


func _try_megavox(asset_id: String, target_height: float) -> bool:
	if not LocalMegavoxAssets.add_ui_icon(_model_root, asset_id, "MegavoxSource", Vector3(0.0, 0.10, 0.0), target_height):
		return false
	source_kind = "megavox"
	return true


func _add_ground_block(top_color: Color) -> void:
	_add_cube("GroundDirt", Vector3(0.76, 0.24, 0.76), SOIL, Vector3(0.0, 0.17, 0.0))
	_add_cube("GroundTop", Vector3(0.78, 0.10, 0.78), top_color, Vector3(0.0, 0.34, 0.0))


func _add_crop(wheat: bool, offset: Vector3 = Vector3.ZERO) -> void:
	var stem_color := Color("#b98b2f") if wheat else Color("#3f7b35")
	var head_color := Color("#f0c85a") if wheat else GOLD
	for i in range(3):
		var x := -0.22 + float(i) * 0.22
		var height := 0.48 + float(i % 2) * 0.10
		_add_cube("CropStem%s" % i, Vector3(0.07, height, 0.07), stem_color, offset + Vector3(x, 0.16 + height * 0.5, 0.02 * float(i - 1)))
		_add_cube("CropHead%s" % i, Vector3(0.13, 0.16, 0.13), head_color, offset + Vector3(x, 0.20 + height, 0.02 * float(i - 1)))


func _add_sprout(offset: Vector3 = Vector3.ZERO, scale_factor: float = 1.0) -> void:
	_add_cube("SproutStem", Vector3(0.08, 0.42, 0.08) * scale_factor, MOSS, offset + Vector3(0.0, 0.29, 0.0))
	var leaf_a := _add_cube("SproutLeafA", Vector3(0.34, 0.08, 0.12) * scale_factor, MOSS_LIGHT, offset + Vector3(-0.12, 0.42, 0.0))
	leaf_a.rotation.z = deg_to_rad(-24.0)
	var leaf_b := _add_cube("SproutLeafB", Vector3(0.30, 0.08, 0.12) * scale_factor, MOSS_LIGHT, offset + Vector3(0.12, 0.53, 0.0))
	leaf_b.rotation.z = deg_to_rad(28.0)


func _add_tree() -> void:
	_add_cube("Trunk", Vector3(0.16, 0.56, 0.16), WOOD, Vector3(0.0, 0.36, 0.0))
	_add_cube("CanopyLow", Vector3(0.68, 0.34, 0.62), MOSS, Vector3(0.0, 0.70, 0.0))
	_add_cube("CanopyTop", Vector3(0.48, 0.30, 0.46), MOSS_LIGHT, Vector3(0.04, 0.94, 0.02))


func _add_grass_clump() -> void:
	for i in range(7):
		var x := -0.27 + float(i % 4) * 0.18
		var z := -0.13 + float(i / 4) * 0.24
		_add_cube("GrassBlade%s" % i, Vector3(0.055, 0.36 + float(i % 3) * 0.08, 0.055), MOSS_LIGHT if i % 2 == 0 else MOSS, Vector3(x, 0.24, z))


func _add_flowers() -> void:
	for i in range(4):
		var x := -0.22 + float(i % 2) * 0.44
		var z := -0.15 + float(i / 2) * 0.30
		_add_cube("FlowerStem%s" % i, Vector3(0.05, 0.34, 0.05), MOSS, Vector3(x, 0.27, z))
		_add_cube("FlowerBloom%s" % i, Vector3(0.14, 0.14, 0.14), [BARN_RED, GOLD, WATER, CREAM][i], Vector3(x, 0.49, z))


func _add_rock() -> void:
	_add_cube("RockLow", Vector3(0.58, 0.30, 0.50), STONE, Vector3(0.0, 0.24, 0.0))
	_add_cube("RockHigh", Vector3(0.38, 0.26, 0.36), STONE_LIGHT, Vector3(-0.08, 0.44, -0.04))


func _add_fence(offset: Vector3 = Vector3.ZERO, scale_factor: float = 1.0) -> void:
	_add_cube("FencePostA", Vector3(0.10, 0.62, 0.10) * scale_factor, WOOD, offset + Vector3(-0.28, 0.37, 0.0))
	_add_cube("FencePostB", Vector3(0.10, 0.62, 0.10) * scale_factor, WOOD, offset + Vector3(0.28, 0.37, 0.0))
	_add_cube("FenceRailA", Vector3(0.68, 0.10, 0.09) * scale_factor, WOOD_LIGHT, offset + Vector3(0.0, 0.31, 0.0))
	_add_cube("FenceRailB", Vector3(0.68, 0.10, 0.09) * scale_factor, WOOD_LIGHT, offset + Vector3(0.0, 0.56, 0.0))


func _add_sign() -> void:
	_add_cube("SignPost", Vector3(0.10, 0.62, 0.10), WOOD, Vector3(0.0, 0.39, 0.0))
	_add_cube("SignFace", Vector3(0.62, 0.32, 0.10), WOOD_LIGHT, Vector3(0.0, 0.63, -0.02))


func _add_barn() -> void:
	_add_cube("BarnBody", Vector3(0.72, 0.58, 0.62), BARN_RED, Vector3(0.0, 0.39, 0.0))
	_add_cube("BarnRoof", Vector3(0.84, 0.20, 0.72), INK, Vector3(0.0, 0.77, 0.0))
	_add_cube("BarnDoor", Vector3(0.24, 0.34, 0.05), WOOD, Vector3(0.0, 0.31, -0.34))


func _add_silo() -> void:
	_add_cube("SiloBody", Vector3(0.48, 0.70, 0.48), Color("#ded7c4"), Vector3(0.0, 0.45, 0.0))
	_add_cube("SiloBand", Vector3(0.52, 0.08, 0.52), STONE, Vector3(0.0, 0.46, 0.0))
	_add_cube("SiloRoof", Vector3(0.58, 0.18, 0.58), BARN_RED, Vector3(0.0, 0.88, 0.0))


func _add_well() -> void:
	_add_cube("WellBase", Vector3(0.60, 0.30, 0.60), STONE, Vector3(0.0, 0.26, 0.0))
	_add_cube("Water", Vector3(0.42, 0.06, 0.42), WATER, Vector3(0.0, 0.43, 0.0))
	_add_cube("WellRoof", Vector3(0.72, 0.14, 0.58), WOOD_LIGHT, Vector3(0.0, 0.79, 0.0))


func _add_hammer() -> void:
	var handle := _add_cube("HammerHandle", Vector3(0.10, 0.72, 0.10), WOOD, Vector3(0.0, 0.45, 0.0))
	handle.rotation.z = deg_to_rad(-28.0)
	var head := _add_cube("HammerHead", Vector3(0.48, 0.18, 0.20), STONE, Vector3(0.16, 0.72, 0.0))
	head.rotation.z = deg_to_rad(-28.0)


func _add_pickaxe(offset: Vector3 = Vector3.ZERO, scale_factor: float = 1.0) -> void:
	var handle := _add_cube("PickHandle", Vector3(0.09, 0.72, 0.09) * scale_factor, WOOD, offset + Vector3(0.0, 0.44, 0.0))
	handle.rotation.z = deg_to_rad(-30.0)
	var head := _add_cube("PickHead", Vector3(0.60, 0.10, 0.14) * scale_factor, STONE_LIGHT, offset + Vector3(0.15, 0.72, 0.0))
	head.rotation.z = deg_to_rad(-30.0)


func _add_sickle() -> void:
	var handle := _add_cube("SickleHandle", Vector3(0.08, 0.58, 0.08), WOOD, Vector3(-0.08, 0.39, 0.0))
	handle.rotation.z = deg_to_rad(-22.0)
	var blade_a := _add_cube("SickleBladeA", Vector3(0.42, 0.08, 0.10), STONE_LIGHT, Vector3(0.16, 0.64, 0.0))
	blade_a.rotation.z = deg_to_rad(20.0)
	var blade_b := _add_cube("SickleBladeB", Vector3(0.28, 0.07, 0.09), STONE_LIGHT, Vector3(0.31, 0.52, 0.0))
	blade_b.rotation.z = deg_to_rad(58.0)


func _add_pan_arrows() -> void:
	_add_cube("PanCenter", Vector3(0.24, 0.24, 0.24), WATER, Vector3(0.0, 0.36, 0.0))
	for direction in [Vector3(0.34, 0.0, 0.0), Vector3(-0.34, 0.0, 0.0), Vector3(0.0, 0.0, 0.34), Vector3(0.0, 0.0, -0.34)]:
		_add_cube("Arrow%s" % str(direction), Vector3(0.30 if direction.x != 0 else 0.10, 0.10, 0.30 if direction.z != 0 else 0.10), WATER, Vector3(direction.x, 0.36, direction.z))


func _add_cross(color: Color, offset: Vector3) -> void:
	var a := _add_cube("CrossA", Vector3(0.42, 0.08, 0.08), color, offset)
	a.rotation.z = deg_to_rad(45.0)
	var b := _add_cube("CrossB", Vector3(0.42, 0.08, 0.08), color, offset)
	b.rotation.z = deg_to_rad(-45.0)


func _add_crate(color: Color) -> void:
	_add_cube("Crate", Vector3(0.64, 0.52, 0.58), color, Vector3(0.0, 0.34, 0.0))
	_add_cube("CrateBand", Vector3(0.70, 0.10, 0.62), WOOD, Vector3(0.0, 0.35, 0.0))


func _add_droplet(offset: Vector3) -> void:
	_add_cube("DropLow", Vector3(0.20, 0.22, 0.18), WATER, offset)
	_add_cube("DropTip", Vector3(0.10, 0.18, 0.10), Color("#78c4d2"), offset + Vector3(0.0, 0.18, 0.0))


func _add_speech_bubbles() -> void:
	_add_cube("BubbleA", Vector3(0.52, 0.30, 0.12), CREAM, Vector3(-0.13, 0.52, 0.0))
	_add_cube("BubbleB", Vector3(0.44, 0.26, 0.12), WATER, Vector3(0.18, 0.30, 0.08))


func _add_sun() -> void:
	_add_cube("SunCore", Vector3(0.42, 0.42, 0.42), GOLD, Vector3(0.0, 0.48, 0.0))
	for offset in [Vector3(0.0, 0.34, 0.0), Vector3(0.0, -0.34, 0.0), Vector3(0.34, 0.0, 0.0), Vector3(-0.34, 0.0, 0.0)]:
		_add_cube("Ray%s" % str(offset), Vector3(0.12, 0.22 if offset.y != 0 else 0.12, 0.22 if offset.z != 0 else 0.12), GOLD, Vector3(offset.x, 0.48 + offset.y, offset.z))


func _add_cube(node_name: String, size: Vector3, color: Color, local_position: Vector3) -> MeshInstance3D:
	var cube := VoxelFactory.cube(node_name, size, color, local_position)
	cube.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_model_root.add_child(cube)
	return cube
