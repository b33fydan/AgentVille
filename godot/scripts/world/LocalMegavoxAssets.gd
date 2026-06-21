class_name LocalMegavoxAssets
extends RefCounted

const ASSET_ROOT := "res://assets/megavoxpack_local_preview"
const PROP_ASSETS := {
	"fence": {
		"path": "%s/Asset_Fence_01.glb" % ASSET_ROOT,
		"target_height": 0.70,
		"yaw_degrees": 30.0
	},
	"rock": {
		"path": "%s/Rock_033.glb" % ASSET_ROOT,
		"target_height": 0.42,
		"yaw_degrees": 28.0
	},
	"flower_patch": {
		"path": "%s/Plant_095.glb" % ASSET_ROOT,
		"target_height": 0.36,
		"yaw_degrees": 36.0
	},
	"tall_grass": {
		"path": "%s/Plant_070.glb" % ASSET_ROOT,
		"target_height": 0.46,
		"yaw_degrees": -18.0
	},
	"tree": {
		"path": "%s/Tree_005.glb" % ASSET_ROOT,
		"target_height": 1.24,
		"yaw_degrees": 22.0
	}
}


static func has_prop(prop_id: String) -> bool:
	var spec: Dictionary = PROP_ASSETS.get(prop_id, {})
	if spec.is_empty():
		return false
	return FileAccess.file_exists(ProjectSettings.globalize_path(str(spec.get("path", ""))))


static func add_prop(
	root: Node3D,
	prop_id: String,
	node_name: String,
	position: Vector3,
	target_height: float = -1.0,
	yaw_degrees: float = 100000.0
) -> bool:
	var spec: Dictionary = PROP_ASSETS.get(prop_id, {})
	if spec.is_empty():
		return false

	var scene := _load_gltf_scene(str(spec.get("path", "")))
	if scene == null:
		return false

	var holder := Node3D.new()
	holder.name = node_name
	holder.position = position
	root.add_child(holder)

	var model_root := Node3D.new()
	model_root.name = "%sModelRoot" % node_name
	holder.add_child(model_root)

	scene.name = "%sSource" % node_name
	model_root.add_child(scene)

	var report := _measure_model(model_root)
	var source_aabb: AABB = report["aabb"]
	var source_height := maxf(source_aabb.size.y, 0.001)
	var display_height := float(spec.get("target_height", 1.0)) if target_height <= 0.0 else target_height
	var display_scale := display_height / source_height
	var display_yaw := float(spec.get("yaw_degrees", 0.0)) if yaw_degrees > 99999.0 else yaw_degrees

	scene.position = Vector3(
		-source_aabb.get_center().x,
		-source_aabb.position.y,
		-source_aabb.get_center().z
	)
	model_root.rotation_degrees.y = display_yaw
	holder.scale = Vector3.ONE * display_scale
	return true


static func _load_gltf_scene(resource_path: String) -> Node3D:
	var global_path := ProjectSettings.globalize_path(resource_path)
	if not FileAccess.file_exists(global_path):
		return null

	var gltf := GLTFDocument.new()
	var state := GLTFState.new()
	var error := gltf.append_from_file(global_path, state)
	if error != OK:
		push_warning("Local MEGAVOXPACK import failed for %s with error %s." % [resource_path, error])
		return null

	return gltf.generate_scene(state)


static func _measure_model(root_node: Node3D) -> Dictionary:
	var combined := AABB()
	var has_aabb := false
	var mesh_instances := 0
	var root_inverse := root_node.global_transform.affine_inverse()

	for node in _node_tree(root_node):
		if node is MeshInstance3D:
			var mesh_instance := node as MeshInstance3D
			if mesh_instance.mesh == null:
				continue
			var local_aabb := mesh_instance.mesh.get_aabb()
			var root_space_aabb := _transform_aabb(root_inverse * mesh_instance.global_transform, local_aabb)
			combined = root_space_aabb if not has_aabb else combined.merge(root_space_aabb)
			has_aabb = true
			mesh_instances += 1

	if not has_aabb:
		combined = AABB(Vector3.ZERO, Vector3.ONE)

	return {
		"aabb": combined,
		"mesh_instances": mesh_instances
	}


static func _node_tree(root_node: Node) -> Array[Node]:
	var nodes: Array[Node] = [root_node]
	var index := 0
	while index < nodes.size():
		var node := nodes[index]
		for child in node.get_children():
			nodes.append(child)
		index += 1
	return nodes


static func _transform_aabb(transform: Transform3D, aabb: AABB) -> AABB:
	var min_corner := aabb.position
	var max_corner := aabb.position + aabb.size
	var corners := [
		Vector3(min_corner.x, min_corner.y, min_corner.z),
		Vector3(max_corner.x, min_corner.y, min_corner.z),
		Vector3(min_corner.x, max_corner.y, min_corner.z),
		Vector3(max_corner.x, max_corner.y, min_corner.z),
		Vector3(min_corner.x, min_corner.y, max_corner.z),
		Vector3(max_corner.x, min_corner.y, max_corner.z),
		Vector3(min_corner.x, max_corner.y, max_corner.z),
		Vector3(max_corner.x, max_corner.y, max_corner.z),
	]

	var transformed := AABB(transform * corners[0], Vector3.ZERO)
	for i in range(1, corners.size()):
		transformed = transformed.expand(transform * corners[i])
	return transformed
