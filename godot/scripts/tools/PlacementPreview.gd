class_name PlacementPreview
extends Node3D

const VoxelFactory := preload("res://scripts/core/Voxel.gd")

var _item_id: String = ""
var _valid: bool = true


func set_item(item_id: String) -> void:
	if _item_id == item_id:
		return
	_item_id = item_id
	_rebuild()


func show_preview(local_position: Vector3, is_valid: bool) -> void:
	position = local_position
	visible = true
	if _valid != is_valid:
		_valid = is_valid
		_rebuild()


func hide_preview() -> void:
	visible = false


func _rebuild() -> void:
	for child in get_children():
		child.queue_free()

	var tint := Color("#9fe8ff") if _valid else Color("#ff8e76")
	match _item_id:
		"grass_block":
			_add_cube("Grass", Vector3(0.72, 0.08, 0.72), tint, Vector3(0.0, 0.22, 0.0), 0.42)
		"dirt_road":
			_add_cube("Road", Vector3(0.72, 0.07, 0.72), tint, Vector3(0.0, 0.22, 0.0), 0.38)
			_add_cube("RoadLineA", Vector3(0.56, 0.035, 0.035), tint, Vector3(0.0, 0.28, -0.20), 0.58)
			_add_cube("RoadLineB", Vector3(0.52, 0.035, 0.035), tint, Vector3(0.0, 0.28, 0.20), 0.58)
		"soil":
			_add_cube("Soil", Vector3(0.66, 0.08, 0.66), tint, Vector3(0.0, 0.22, 0.0), 0.42)
			_add_cube("FurrowA", Vector3(0.54, 0.04, 0.035), tint, Vector3(0.0, 0.30, -0.16), 0.64)
			_add_cube("FurrowB", Vector3(0.54, 0.04, 0.035), tint, Vector3(0.0, 0.30, 0.16), 0.64)
		"corn_seed", "wheat_seed":
			_add_crop_preview(tint)
		"fence":
			_add_cube("PostA", Vector3(0.10, 0.48, 0.10), tint, Vector3(-0.28, 0.42, 0.0), 0.45)
			_add_cube("PostB", Vector3(0.10, 0.48, 0.10), tint, Vector3(0.28, 0.42, 0.0), 0.45)
			_add_cube("Rail", Vector3(0.70, 0.09, 0.08), tint, Vector3(0.0, 0.44, 0.0), 0.45)
		"flower_patch":
			_add_cube("FlowerBase", Vector3(0.46, 0.07, 0.46), tint, Vector3(0.0, 0.23, 0.0), 0.36)
			for i in range(4):
				var x := -0.18 + float(i % 2) * 0.36
				var z := -0.14 + float(i / 2) * 0.28
				_add_cube("Bloom%s" % i, Vector3(0.11, 0.11, 0.11), tint, Vector3(x, 0.42, z), 0.68)
		"tall_grass":
			for i in range(7):
				var x := -0.24 + float(i % 4) * 0.16
				var z := -0.18 + float(i / 4) * 0.28
				_add_cube("Blade%s" % i, Vector3(0.045, 0.34 + float(i % 3) * 0.05, 0.045), tint, Vector3(x, 0.36, z), 0.46)
		"wooden_sign":
			_add_cube("SignPost", Vector3(0.08, 0.44, 0.08), tint, Vector3(0.0, 0.38, 0.0), 0.44)
			_add_cube("SignFace", Vector3(0.46, 0.22, 0.06), tint, Vector3(0.0, 0.62, -0.04), 0.48)
		"rock":
			_add_cube("RockBase", Vector3(0.44, 0.22, 0.38), tint, Vector3(0.0, 0.28, 0.0), 0.44)
			_add_cube("RockTop", Vector3(0.30, 0.22, 0.28), tint, Vector3(-0.06, 0.42, -0.04), 0.50)
		"barn":
			_add_cube("BarnBody", Vector3(0.90, 0.70, 0.76), tint, Vector3(0.0, 0.58, 0.0), 0.36)
			_add_cube("BarnRoof", Vector3(1.02, 0.20, 0.88), tint, Vector3(0.0, 1.04, 0.0), 0.42)
		"silo":
			_add_cube("SiloBody", Vector3(0.46, 0.86, 0.46), tint, Vector3(0.0, 0.62, 0.0), 0.38)
			_add_cube("SiloRoof", Vector3(0.56, 0.18, 0.56), tint, Vector3(0.0, 1.14, 0.0), 0.44)
		"well":
			_add_cube("WellBase", Vector3(0.56, 0.28, 0.56), tint, Vector3(0.0, 0.34, 0.0), 0.38)
			_add_cube("WellRoof", Vector3(0.66, 0.16, 0.56), tint, Vector3(0.0, 0.82, 0.0), 0.44)
		"pickaxe":
			_add_tool_preview(tint, true)
		"sickle":
			_add_tool_preview(tint, false)
		_:
			_add_cube("Fallback", Vector3(0.44, 0.44, 0.44), tint, Vector3(0.0, 0.44, 0.0), 0.42)


func _add_crop_preview(tint: Color) -> void:
	_add_cube("StemA", Vector3(0.08, 0.48, 0.08), tint, Vector3(-0.12, 0.44, -0.08), 0.42)
	_add_cube("StemB", Vector3(0.08, 0.40, 0.08), tint, Vector3(0.12, 0.40, 0.10), 0.42)
	_add_cube("LeafA", Vector3(0.26, 0.06, 0.06), tint, Vector3(-0.18, 0.52, -0.08), 0.56)
	_add_cube("HeadA", Vector3(0.12, 0.16, 0.12), tint, Vector3(-0.06, 0.70, -0.08), 0.58)


func _add_tool_preview(tint: Color, is_pickaxe: bool) -> void:
	rotation.y = 0.0
	if is_pickaxe:
		_add_cube("Handle", Vector3(0.08, 0.62, 0.08), tint, Vector3(0.0, 0.48, 0.0), 0.48).rotation.z = deg_to_rad(-28.0)
		_add_cube("Head", Vector3(0.58, 0.08, 0.10), tint, Vector3(0.04, 0.73, 0.0), 0.58).rotation.z = deg_to_rad(-28.0)
	else:
		_add_cube("Handle", Vector3(0.07, 0.48, 0.07), tint, Vector3(0.0, 0.45, 0.0), 0.48).rotation.z = deg_to_rad(-18.0)
		_add_cube("BladeA", Vector3(0.38, 0.06, 0.08), tint, Vector3(0.20, 0.65, 0.0), 0.60).rotation.z = deg_to_rad(18.0)
		_add_cube("BladeB", Vector3(0.24, 0.05, 0.07), tint, Vector3(0.32, 0.55, 0.0), 0.60).rotation.z = deg_to_rad(54.0)


func _add_cube(node_name: String, size: Vector3, color: Color, local_position: Vector3, alpha: float) -> MeshInstance3D:
	var mat := VoxelFactory.transparent_material(color, alpha)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.18
	var cube := VoxelFactory.cube_with_material(node_name, size, mat, local_position)
	cube.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(cube)
	return cube
