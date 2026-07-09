extends SceneTree

const MANIFEST_PATH := "res://artifacts/screenshots/agentville-megavox-starter-map.json"
const IMAGE_PATH := "res://artifacts/screenshots/agentville-megavox-starter-map.png"
const EXPECTED_VIEWPORT_SIZE := [1600, 900]
const EXPECTED_CAMERA_SIZE := 9.2

var _has_failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if not FileAccess.file_exists(IMAGE_PATH):
		_fail("MEGAVOX starter capture image is missing at %s." % IMAGE_PATH)
		return

	var manifest := _read_manifest()
	if _failed():
		return

	_expect_string_field(manifest, "image_path", IMAGE_PATH, "manifest")
	_expect_number_array(manifest.get("viewport_size", []), EXPECTED_VIEWPORT_SIZE, "manifest.viewport_size")
	_expect_bool_field(manifest, "ui_hidden", true, "manifest")
	_expect_bool_field(manifest, "grid_visible", false, "manifest")
	_expect_non_empty_string_field(manifest, "display_server", "manifest")
	if _failed():
		return

	var camera := _dictionary_field(manifest, "camera", "manifest")
	_expect_bool_field(camera, "centered_on_farm", true, "manifest.camera")
	_expect_float_field(camera, "size", EXPECTED_CAMERA_SIZE, "manifest.camera")
	if _failed():
		return

	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var grid_manager = scene.get_node("FarmWorld/GridManager")
	_expect_starter_decor_manifest(manifest, grid_manager)
	if _failed():
		return

	root.remove_child(scene)
	scene.queue_free()
	await process_frame
	quit()


func _read_manifest() -> Dictionary:
	if not FileAccess.file_exists(MANIFEST_PATH):
		_fail("MEGAVOX starter capture manifest is missing at %s." % MANIFEST_PATH)
		return {}

	var file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if file == null:
		_fail("Could not open MEGAVOX starter capture manifest at %s." % MANIFEST_PATH)
		return {}

	var text := file.get_as_text()
	file.close()

	var json := JSON.new()
	var error := json.parse(text)
	if error != OK:
		_fail("Could not parse MEGAVOX starter capture manifest: %s at line %s." % [
			json.get_error_message(),
			json.get_error_line()
		])
		return {}

	if typeof(json.data) != TYPE_DICTIONARY:
		_fail("MEGAVOX starter capture manifest should parse to a dictionary.")
		return {}
	return json.data


func _expect_starter_decor_manifest(manifest: Dictionary, grid_manager) -> void:
	if not grid_manager.has_method("starter_decor_clusters") or not grid_manager.has_method("starter_decor_cluster_order"):
		_fail("GridManager should expose starter decor clusters for manifest validation.")
		return

	var starter_decor := _dictionary_field(manifest, "starter_decor", "manifest")
	var expected_cluster_order := _starter_cluster_order(grid_manager)
	var expected_clusters := _starter_cluster_summary(grid_manager, expected_cluster_order)
	_expect_string_array(starter_decor.get("cluster_order", []), expected_cluster_order, "manifest.starter_decor.cluster_order")
	_expect_int_field(starter_decor, "cluster_count", expected_clusters.size(), "manifest.starter_decor")
	_expect_int_field(starter_decor, "entry_count", _starter_cluster_entry_count(expected_clusters), "manifest.starter_decor")
	if _failed():
		return

	var actual_clusters = starter_decor.get("clusters", [])
	if typeof(actual_clusters) != TYPE_ARRAY:
		_fail("manifest.starter_decor.clusters should be an array.")
		return
	if actual_clusters.size() != expected_clusters.size():
		_fail("manifest.starter_decor.clusters should have %s clusters, saw %s." % [
			expected_clusters.size(),
			actual_clusters.size()
		])
		return

	for cluster_index in range(expected_clusters.size()):
		_expect_cluster_matches_catalog(
			actual_clusters[cluster_index],
			expected_clusters[cluster_index],
			"manifest.starter_decor.clusters[%s]" % cluster_index
		)
		if _failed():
			return


func _expect_cluster_matches_catalog(actual, expected: Dictionary, context: String) -> void:
	if typeof(actual) != TYPE_DICTIONARY:
		_fail("%s should be a dictionary." % context)
		return

	var actual_cluster: Dictionary = actual
	_expect_string_field(actual_cluster, "cluster_id", str(expected.get("cluster_id", "")), context)
	_expect_int_field(actual_cluster, "entry_count", int(expected.get("entry_count", 0)), context)
	if _failed():
		return

	var actual_entries = actual_cluster.get("entries", [])
	var expected_entries: Array = expected.get("entries", [])
	if typeof(actual_entries) != TYPE_ARRAY:
		_fail("%s.entries should be an array." % context)
		return
	if actual_entries.size() != expected_entries.size():
		_fail("%s.entries should have %s entries, saw %s." % [
			context,
			expected_entries.size(),
			actual_entries.size()
		])
		return

	for entry_index in range(expected_entries.size()):
		_expect_entry_matches_catalog(
			actual_entries[entry_index],
			expected_entries[entry_index],
			"%s.entries[%s]" % [context, entry_index]
		)
		if _failed():
			return


func _expect_entry_matches_catalog(actual, expected: Dictionary, context: String) -> void:
	if typeof(actual) != TYPE_DICTIONARY:
		_fail("%s should be a dictionary." % context)
		return

	var actual_entry: Dictionary = actual
	_expect_string_field(actual_entry, "decor_id", str(expected.get("decor_id", "")), context)
	_expect_number_array(actual_entry.get("grid_pos", []), expected.get("grid_pos", []), "%s.grid_pos" % context)


func _starter_cluster_order(grid_manager) -> Array:
	var raw_order: Array = grid_manager.call("starter_decor_cluster_order")
	var cluster_order := []
	for cluster_id in raw_order:
		cluster_order.append(str(cluster_id))
	return cluster_order


func _starter_cluster_summary(grid_manager, cluster_order: Array) -> Array:
	var clusters: Dictionary = grid_manager.call("starter_decor_clusters")
	var summary := []
	for cluster_id in cluster_order:
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


func _dictionary_field(source: Dictionary, key: String, context: String) -> Dictionary:
	var value = source.get(key, {})
	if typeof(value) != TYPE_DICTIONARY:
		_fail("%s.%s should be a dictionary." % [context, key])
		return {}
	return value


func _expect_string_field(source: Dictionary, key: String, expected: String, context: String) -> void:
	var actual := str(source.get(key, ""))
	if actual != expected:
		_fail("%s.%s should be %s, saw %s." % [context, key, expected, actual])


func _expect_non_empty_string_field(source: Dictionary, key: String, context: String) -> void:
	var actual := str(source.get(key, ""))
	if actual.is_empty():
		_fail("%s.%s should be a non-empty string." % [context, key])


func _expect_bool_field(source: Dictionary, key: String, expected: bool, context: String) -> void:
	var actual = source.get(key, null)
	if typeof(actual) != TYPE_BOOL or bool(actual) != expected:
		_fail("%s.%s should be %s." % [context, key, str(expected)])


func _expect_int_field(source: Dictionary, key: String, expected: int, context: String) -> void:
	var actual = source.get(key, null)
	if typeof(actual) != TYPE_INT and typeof(actual) != TYPE_FLOAT:
		_fail("%s.%s should be numeric." % [context, key])
		return
	if int(actual) != expected:
		_fail("%s.%s should be %s, saw %s." % [context, key, expected, int(actual)])


func _expect_float_field(source: Dictionary, key: String, expected: float, context: String) -> void:
	var actual = source.get(key, null)
	if typeof(actual) != TYPE_INT and typeof(actual) != TYPE_FLOAT:
		_fail("%s.%s should be numeric." % [context, key])
		return
	if absf(float(actual) - expected) > 0.001:
		_fail("%s.%s should be %.2f, saw %.2f." % [context, key, expected, float(actual)])


func _expect_number_array(actual, expected: Array, context: String) -> void:
	if typeof(actual) != TYPE_ARRAY:
		_fail("%s should be an array." % context)
		return
	if actual.size() != expected.size():
		_fail("%s should have %s values, saw %s." % [context, expected.size(), actual.size()])
		return
	for index in range(expected.size()):
		var actual_value = actual[index]
		if typeof(actual_value) != TYPE_INT and typeof(actual_value) != TYPE_FLOAT:
			_fail("%s[%s] should be numeric." % [context, index])
			return
		if int(actual_value) != int(expected[index]):
			_fail("%s[%s] should be %s, saw %s." % [
				context,
				index,
				int(expected[index]),
				int(actual_value)
			])
			return


func _expect_string_array(actual, expected: Array, context: String) -> void:
	if typeof(actual) != TYPE_ARRAY:
		_fail("%s should be an array." % context)
		return
	if actual.size() != expected.size():
		_fail("%s should have %s values, saw %s." % [context, expected.size(), actual.size()])
		return
	for index in range(expected.size()):
		var actual_value := str(actual[index])
		var expected_value := str(expected[index])
		if actual_value != expected_value:
			_fail("%s[%s] should be %s, saw %s." % [
				context,
				index,
				expected_value,
				actual_value
			])
			return


func _failed() -> bool:
	return _has_failed


func _fail(message: String) -> void:
	_has_failed = true
	push_error(message)
	quit(1)
