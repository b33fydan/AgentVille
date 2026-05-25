class_name Voxel
extends RefCounted

static func material(color: Color, roughness: float = 0.88) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = 0.0
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return mat


static func transparent_material(color: Color, alpha: float) -> StandardMaterial3D:
	var mat := material(color)
	mat.albedo_color.a = alpha
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mat


static func cube(node_name: String, size: Vector3, color: Color, position: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size

	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = position
	instance.material_override = material(color)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return instance


static func cube_with_material(node_name: String, size: Vector3, mat: Material, position: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size

	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = position
	instance.material_override = mat
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return instance
