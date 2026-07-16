extends SceneTree

const PRESET_PATH := "res://export_presets.cfg"
const EXPORT_SCRIPT_PATH := "res://tools/export_web.sh"
const VERCEL_CONFIG_PATH := "res://web/vercel.json"
const CAMERA_CONTROLLER_PATH := "res://scripts/camera/CameraController.gd"
const EXPECTED_EXPORT_PATH := "build/web/index.html"
const LICENSED_ASSET_FILTER := "assets/megavoxpack_local_preview/*"

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_assert_renderer_override()
	_assert_export_preset()
	_assert_export_script()
	_assert_vercel_config()
	_assert_compatibility_camera_guard()
	if not _failed:
		quit()


func _assert_renderer_override() -> void:
	var method := str(ProjectSettings.get_setting("rendering/renderer/rendering_method.web", ""))
	if method != "gl_compatibility":
		_fail("Web should use Godot's Compatibility renderer. actual='%s'" % method)


func _assert_export_preset() -> void:
	var preset := ConfigFile.new()
	var error := preset.load(PRESET_PATH)
	if error != OK:
		_fail("Could not load %s (error %s)." % [PRESET_PATH, error])
		return

	_expect_preset_value(preset, "preset.0", "name", "Web")
	_expect_preset_value(preset, "preset.0", "platform", "Web")
	_expect_preset_value(preset, "preset.0", "export_path", EXPECTED_EXPORT_PATH)
	_expect_preset_value(preset, "preset.0.options", "variant/thread_support", false)
	_expect_preset_value(preset, "preset.0.options", "variant/extensions_support", false)
	_expect_preset_value(preset, "preset.0.options", "vram_texture_compression/for_mobile", false)
	_expect_preset_value(preset, "preset.0.options", "progressive_web_app/enabled", false)

	var exclude_filter := str(preset.get_value("preset.0", "exclude_filter", ""))
	if LICENSED_ASSET_FILTER not in exclude_filter.split(",", false):
		_fail("Web preset must exclude the local licensed MEGAVOX folder.")


func _assert_export_script() -> void:
	var source := _read_text_file(EXPORT_SCRIPT_PATH)
	if source.is_empty():
		return
	for required_text in [
		'GODOT="${GODOT:-/Users/beefymacmini/Downloads/Godot.app/Contents/MacOS/Godot}"',
		'--log-file "$LOG_PATH"',
		'--export-release "Web"',
		"Storing File: res://assets/megavoxpack_local_preview/",
		'cp "$PROJECT_DIR/web/vercel.json"'
	]:
		if required_text not in source:
			_fail("Web export script lost required contract text: %s" % required_text)


func _assert_vercel_config() -> void:
	var source := _read_text_file(VERCEL_CONFIG_PATH)
	if source.is_empty():
		return
	var json := JSON.new()
	var error := json.parse(source)
	if error != OK:
		_fail("Vercel config is not valid JSON: %s at line %s." % [json.get_error_message(), json.get_error_line()])
		return
	if typeof(json.data) != TYPE_DICTIONARY:
		_fail("Vercel config should parse to a dictionary.")
		return

	var config := json.data as Dictionary
	if config.has("outputDirectory") or config.has("buildCommand"):
		_fail("Artifact-local Vercel config must not route through the dead root Vite build.")
	var headers = config.get("headers", [])
	if typeof(headers) != TYPE_ARRAY or (headers as Array).is_empty():
		_fail("Vercel config should define cache revalidation for matching Godot artifacts.")


func _assert_compatibility_camera_guard() -> void:
	var source := _read_text_file(CAMERA_CONTROLLER_PATH)
	if source.is_empty():
		return
	if 'RenderingServer.get_current_rendering_method() != "gl_compatibility"' not in source:
		_fail("Camera depth of field must stay disabled on the Web Compatibility renderer.")


func _expect_preset_value(preset: ConfigFile, section: String, key: String, expected) -> void:
	var actual = preset.get_value(section, key, null)
	if actual != expected:
		_fail("Web preset mismatch for %s/%s. expected=%s actual=%s" % [section, key, expected, actual])


func _read_text_file(path: String) -> String:
	if not FileAccess.file_exists(path):
		_fail("Required Web export file is missing: %s" % path)
		return ""
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_fail("Could not open required Web export file: %s" % path)
		return ""
	var source := file.get_as_text()
	file.close()
	return source


func _fail(message: String) -> void:
	if _failed:
		return
	_failed = true
	push_error(message)
	quit(1)
