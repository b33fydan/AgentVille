extends SceneTree

const OUTPUT_PATH := "res://artifacts/screenshots/agentville-megavox-starter-map.png"
const MANIFEST_PATH := "res://artifacts/screenshots/agentville-megavox-starter-map.json"
const CAPTURE_SIZE := Vector2i(1600, 900)
const CAPTURE_CAMERA_SIZE := 9.2


func _initialize() -> void:
	root.size = CAPTURE_SIZE
	call_deferred("_capture")


func _capture() -> void:
	if DisplayServer.get_name() == "headless":
		_fail("MEGAVOX starter map capture needs a normal renderer; run without --headless.")
		return

	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)

	await process_frame
	await process_frame

	var game_ui = scene.get_node_or_null("GameUI")
	var ui_hidden := false
	if game_ui != null:
		game_ui.visible = false
		ui_hidden = true

	var camera_controller = scene.get_node_or_null("CameraController")
	var camera_centered := false
	var camera_size := CAPTURE_CAMERA_SIZE
	if camera_controller != null:
		camera_controller.call("center_on_farm")
		if camera_controller.camera != null:
			camera_controller.camera.size = CAPTURE_CAMERA_SIZE
			camera_controller.call("_apply_transform")
			camera_centered = true

	await create_timer(0.45).timeout

	var grid_manager = scene.get_node_or_null("FarmWorld/GridManager")
	if grid_manager == null or not grid_manager.has_method("starter_decor_clusters"):
		_fail("Could not capture MEGAVOX starter map: starter decor catalog is unavailable.")
		return

	var viewport_texture := root.get_texture()
	if viewport_texture == null:
		_fail("Could not capture MEGAVOX starter map: viewport texture is unavailable.")
		return

	var image := viewport_texture.get_image()
	if image == null:
		_fail("Could not capture MEGAVOX starter map: viewport image is unavailable.")
		return

	var error := image.save_png(OUTPUT_PATH)
	if error != OK:
		_fail("Could not save MEGAVOX starter map capture to %s." % OUTPUT_PATH)
		return

	error = _save_manifest(grid_manager, ui_hidden, camera_centered, camera_size)
	if error != OK:
		_fail("Could not save MEGAVOX starter map manifest to %s." % MANIFEST_PATH)
		return

	print("Captured MEGAVOX starter map review to %s and %s." % [OUTPUT_PATH, MANIFEST_PATH])
	quit()


func _save_manifest(grid_manager: Node, ui_hidden: bool, camera_centered: bool, camera_size: float) -> int:
	var file := FileAccess.open(MANIFEST_PATH, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()

	var cluster_summary := _starter_cluster_summary(grid_manager)
	var manifest := {
		"image_path": OUTPUT_PATH,
		"viewport_size": [CAPTURE_SIZE.x, CAPTURE_SIZE.y],
		"display_server": DisplayServer.get_name(),
		"ui_hidden": ui_hidden,
		"camera": {
			"centered_on_farm": camera_centered,
			"size": camera_size
		},
		"starter_decor": {
			"cluster_count": cluster_summary.size(),
			"entry_count": _starter_cluster_entry_count(cluster_summary),
			"clusters": cluster_summary
		}
	}
	file.store_string("%s\n" % JSON.stringify(manifest, "\t"))
	file.close()
	return OK


func _starter_cluster_summary(grid_manager: Node) -> Array:
	var clusters: Dictionary = grid_manager.call("starter_decor_clusters")
	var cluster_ids := clusters.keys()
	cluster_ids.sort()

	var summary := []
	for cluster_id in cluster_ids:
		var entries = clusters.get(cluster_id, [])
		var clean_entries := []
		if typeof(entries) == TYPE_ARRAY:
			for entry in entries:
				if typeof(entry) != TYPE_DICTIONARY:
					continue
				var grid_pos = entry.get("grid_pos", Vector2i(-1, -1))
				var grid_pos_values: Array = []
				if typeof(grid_pos) == TYPE_VECTOR2I:
					grid_pos_values = [grid_pos.x, grid_pos.y]
				clean_entries.append({
					"grid_pos": grid_pos_values,
					"decor_id": str(entry.get("decor_id", ""))
				})
		summary.append({
			"cluster_id": str(cluster_id),
			"entry_count": clean_entries.size(),
			"entries": clean_entries
		})
	return summary


func _starter_cluster_entry_count(cluster_summary: Array) -> int:
	var total := 0
	for cluster in cluster_summary:
		total += int(cluster.get("entry_count", 0))
	return total


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
