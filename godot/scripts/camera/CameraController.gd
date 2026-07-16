class_name CameraController
extends Node3D

@export var target_position: Vector3 = Vector3.ZERO
@export var camera_offset: Vector3 = Vector3(6.8, 5.4, 6.8)
@export var default_zoom: float = 7.6
@export var min_zoom: float = 4.4
@export var max_zoom: float = 15.0
@export var zoom_step: float = 0.75
@export var keyboard_pan_speed: float = 4.8
@export var pan_limit_x: float = 6.0
@export var pan_limit_z: float = 5.5

var camera: Camera3D
var pan_tool_active: bool = false

var _dragging: bool = false
var _drag_button: int = 0
var _last_mouse_position: Vector2 = Vector2.ZERO
var _camera_attributes: CameraAttributesPractical


func _ready() -> void:
	camera = Camera3D.new()
	camera.name = "IsoCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = default_zoom
	camera.near = 0.05
	camera.far = 80.0
	camera.current = true
	add_child(camera)
	_setup_camera_atmosphere()
	_apply_transform()


func _process(delta: float) -> void:
	var pan := Vector2.ZERO
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		pan.x += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		pan.x -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		pan.y += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		pan.y -= 1.0
	_apply_keyboard_pan(pan, delta)


func _apply_keyboard_pan(pan: Vector2, delta: float) -> bool:
	if _keyboard_pan_blocked() or pan.length_squared() <= 0.001:
		return false
	_pan_screen_delta(pan.normalized() * keyboard_pan_speed * 70.0 * delta)
	return true


func _keyboard_pan_blocked() -> bool:
	var viewport := get_viewport()
	if viewport == null:
		return false
	var focus_owner := viewport.gui_get_focus_owner()
	return focus_owner is TextEdit or focus_owner is LineEdit


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if not mouse_button.pressed and mouse_button.button_index == _drag_button:
			_stop_drag()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP and mouse_button.pressed:
			adjust_zoom(-1)
			get_viewport().set_input_as_handled()
		elif mouse_button.button_index == MOUSE_BUTTON_WHEEL_DOWN and mouse_button.pressed:
			adjust_zoom(1)
			get_viewport().set_input_as_handled()
		elif mouse_button.button_index in [MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT] or (pan_tool_active and mouse_button.button_index == MOUSE_BUTTON_LEFT):
			if mouse_button.pressed:
				_dragging = true
				_drag_button = mouse_button.button_index
				_last_mouse_position = mouse_button.position
			elif mouse_button.button_index == _drag_button:
				_stop_drag()
			get_viewport().set_input_as_handled()

	if event is InputEventMouseMotion and _dragging:
		var motion := event as InputEventMouseMotion
		var drag_mask := _mouse_button_mask(_drag_button)
		if drag_mask != 0 and (motion.button_mask & drag_mask) == 0:
			_stop_drag()
			return
		_pan_screen_delta(motion.relative)
		_last_mouse_position = motion.position
		get_viewport().set_input_as_handled()


func set_pan_tool_active(is_active: bool) -> void:
	pan_tool_active = is_active
	if not pan_tool_active:
		_stop_drag()


func _stop_drag() -> void:
	_dragging = false
	_drag_button = 0


func _mouse_button_mask(button_index: int) -> int:
	match button_index:
		MOUSE_BUTTON_LEFT:
			return MOUSE_BUTTON_MASK_LEFT
		MOUSE_BUTTON_MIDDLE:
			return MOUSE_BUTTON_MASK_MIDDLE
		MOUSE_BUTTON_RIGHT:
			return MOUSE_BUTTON_MASK_RIGHT
	return 0


func center_on_farm() -> void:
	target_position = Vector3(0.0, 0.0, 0.0)
	camera.size = default_zoom
	_apply_transform()


func adjust_zoom(step_direction: int) -> void:
	if camera == null or step_direction == 0:
		return
	var next_size := clampf(camera.size + zoom_step * float(step_direction), min_zoom, max_zoom)
	if is_equal_approx(next_size, camera.size):
		return
	camera.size = next_size
	_apply_transform()


func focus_world_position(world_position: Vector3, zoom_size: float = -1.0) -> void:
	target_position = Vector3(
		clampf(world_position.x, -pan_limit_x, pan_limit_x),
		0.0,
		clampf(world_position.z, -pan_limit_z, pan_limit_z)
	)
	if zoom_size > 0.0:
		camera.size = clampf(zoom_size, min_zoom, max_zoom)
	_apply_transform()


func _pan_screen_delta(delta_pixels: Vector2) -> void:
	var viewport_height := maxf(1.0, get_viewport().get_visible_rect().size.y)
	var world_per_pixel := camera.size / viewport_height
	var right := camera.global_transform.basis.x
	var forward := -camera.global_transform.basis.z
	right.y = 0.0
	forward.y = 0.0
	right = right.normalized()
	forward = forward.normalized()

	target_position += (-right * delta_pixels.x + forward * delta_pixels.y) * world_per_pixel
	target_position.x = clampf(target_position.x, -pan_limit_x, pan_limit_x)
	target_position.z = clampf(target_position.z, -pan_limit_z, pan_limit_z)
	_apply_transform()


func _apply_transform() -> void:
	if camera == null:
		return
	camera.global_position = target_position + camera_offset
	camera.look_at(target_position, Vector3.UP)
	_update_depth_of_field()


func _setup_camera_atmosphere() -> void:
	_camera_attributes = CameraAttributesPractical.new()
	if _supports_depth_of_field():
		_set_property_if_present(_camera_attributes, "dof_blur_amount", 0.065)
	_set_property_if_present(_camera_attributes, "auto_exposure_enabled", false)
	_set_property_if_present(camera, "attributes", _camera_attributes)


func _update_depth_of_field() -> void:
	if _camera_attributes == null or camera == null or not _supports_depth_of_field():
		return

	var focus_distance := camera.global_position.distance_to(target_position)
	_set_property_if_present(_camera_attributes, "dof_blur_near_enabled", true)
	_set_property_if_present(_camera_attributes, "dof_blur_near_distance", maxf(0.1, focus_distance - 5.4))
	_set_property_if_present(_camera_attributes, "dof_blur_near_transition", 4.6)
	_set_property_if_present(_camera_attributes, "dof_blur_far_enabled", true)
	_set_property_if_present(_camera_attributes, "dof_blur_far_distance", focus_distance + 3.2)
	_set_property_if_present(_camera_attributes, "dof_blur_far_transition", 5.8)


func _supports_depth_of_field() -> bool:
	return RenderingServer.get_current_rendering_method() != "gl_compatibility"


func _set_property_if_present(target: Object, property_name: StringName, value) -> void:
	for property in target.get_property_list():
		if property.name == property_name:
			target.set(property_name, value)
			return
