extends SceneTree

const PRESET_PATH := "res://export_presets.cfg"
const EXPORT_SCRIPT_PATH := "res://tools/export_web.sh"
const PUBLISH_SCRIPT_PATH := "res://tools/publish_web.sh"
const ARTIFACT_VERCEL_CONFIG_PATH := "res://web/vercel.json"
const DEPLOY_IGNORE_PATH := "res://deploy/.gdignore"
const PUBLISH_DIR := "res://deploy/vercel"
const CAMERA_CONTROLLER_PATH := "res://scripts/camera/CameraController.gd"
const EXPECTED_EXPORT_PATH := "build/web/index.html"
const EXPECTED_PUBLISH_PATH := "godot/deploy/vercel"
const LICENSED_ASSET_FILTER := "assets/megavoxpack_local_preview/*"
const RECURSIVE_EXPORT_FILTERS := ["build/*", "deploy/*"]

var _failed := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_assert_renderer_override()
	_assert_export_preset()
	_assert_export_script()
	_assert_publish_script()
	_assert_artifact_vercel_config()
	_assert_repo_vercel_config()
	_assert_reviewed_publish_artifact()
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
	var excluded_paths := exclude_filter.split(",", false)
	if LICENSED_ASSET_FILTER not in excluded_paths:
		_fail("Web preset must exclude the local licensed MEGAVOX folder.")
	for required_filter in RECURSIVE_EXPORT_FILTERS:
		if required_filter not in excluded_paths:
			_fail("Web preset must exclude generated Web path: %s" % required_filter)


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


func _assert_publish_script() -> void:
	var source := _read_text_file(PUBLISH_SCRIPT_PATH)
	if source.is_empty():
		return
	for required_text in [
		"AGENTVILLE_WEB_PUBLISH_DIR",
		'"$TOOLS_DIR/export_web.sh"',
		"--exclude='vercel.json'",
		"artifact-sha256.txt"
	]:
		if required_text not in source:
			_fail("Web publish script lost required contract text: %s" % required_text)


func _assert_artifact_vercel_config() -> void:
	var config := _read_json_dictionary(ARTIFACT_VERCEL_CONFIG_PATH, "Artifact-local Vercel config")
	if config.is_empty():
		return

	if config.has("outputDirectory") or config.has("buildCommand"):
		_fail("Artifact-local Vercel config must not route through the dead root Vite build.")
	var headers = config.get("headers", [])
	if typeof(headers) != TYPE_ARRAY or (headers as Array).is_empty():
		_fail("Vercel config should define cache revalidation for matching Godot artifacts.")


func _assert_repo_vercel_config() -> void:
	var godot_root := ProjectSettings.globalize_path("res://").trim_suffix("/")
	var repo_config_path := godot_root.get_base_dir().path_join("vercel.json")
	var config := _read_json_dictionary(repo_config_path, "Repository Vercel config")
	if config.is_empty():
		return

	if str(config.get("outputDirectory", "")) != EXPECTED_PUBLISH_PATH:
		_fail("Repository Vercel config must publish %s." % EXPECTED_PUBLISH_PATH)
	if str(config.get("installCommand", "missing")) != "":
		_fail("Repository Vercel config must skip the retired npm install.")
	if "reviewed AgentVille Godot Web artifact" not in str(config.get("buildCommand", "")):
		_fail("Repository Vercel config must bypass the retired Vite build.")
	if config.has("rewrites"):
		_fail("Repository Vercel config must not retain legacy React/API rewrites.")
	var headers = config.get("headers", [])
	if typeof(headers) != TYPE_ARRAY or (headers as Array).is_empty():
		_fail("Repository Vercel config should define cache revalidation for Godot artifacts.")


func _assert_reviewed_publish_artifact() -> void:
	if not FileAccess.file_exists(DEPLOY_IGNORE_PATH):
		_fail("Reviewed Web artifact root must be hidden from Godot's resource scan.")
		return
	for required_file in ["index.html", "index.js", "index.wasm", "index.pck", "artifact-sha256.txt"]:
		var path := PUBLISH_DIR.path_join(required_file)
		if not FileAccess.file_exists(path):
			_fail("Reviewed Web artifact is missing: %s" % path)
			return
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null or file.get_length() <= 0:
			_fail("Reviewed Web artifact file is empty: %s" % path)
			return
		file.close()
	if FileAccess.file_exists(PUBLISH_DIR.path_join("vercel.json")):
		_fail("Reviewed Web artifact must not expose a nested vercel.json file.")


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


func _read_json_dictionary(path: String, label: String) -> Dictionary:
	var source := _read_text_file(path)
	if source.is_empty():
		return {}
	var json := JSON.new()
	var error := json.parse(source)
	if error != OK:
		_fail("%s is not valid JSON: %s at line %s." % [label, json.get_error_message(), json.get_error_line()])
		return {}
	if typeof(json.data) != TYPE_DICTIONARY:
		_fail("%s should parse to a dictionary." % label)
		return {}
	return json.data as Dictionary


func _fail(message: String) -> void:
	if _failed:
		return
	_failed = true
	push_error(message)
	quit(1)
