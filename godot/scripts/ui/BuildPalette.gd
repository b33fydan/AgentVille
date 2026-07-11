class_name BuildPalette
extends Control

signal item_selected(item_id: String)

const VoxelIconScript := preload("res://scripts/ui/VoxelIcon.gd")

const CATEGORY_ICON_IDS := {
	"Terrain": "grass_block",
	"Crops": "corn_seed",
	"Nature": "tree",
	"Decor": "fence",
	"Structures": "barn",
	"Tools": "pickaxe"
}

var _category_names := ["Terrain", "Crops", "Nature", "Decor", "Structures", "Tools"]
var _items_by_category := {
	"Terrain": [
		{"id": "grass_block", "label": "Grass"},
		{"id": "dirt_road", "label": "Road"},
		{"id": "soil", "label": "Tilled Soil"}
	],
	"Crops": [
		{"id": "corn_seed", "label": "Corn"},
		{"id": "wheat_seed", "label": "Wheat"}
	],
	"Nature": [
		{"id": "tall_grass", "label": "Tall Grass"},
		{"id": "tree", "label": "Tree"},
		{"id": "flower_patch", "label": "Flowers"},
		{"id": "rock", "label": "Rock"}
	],
	"Decor": [
		{"id": "fence", "label": "Fence"},
		{"id": "wooden_sign", "label": "Sign"}
	],
	"Structures": [
		{"id": "barn", "label": "Barn"},
		{"id": "silo", "label": "Silo"},
		{"id": "well", "label": "Well"}
	],
	"Tools": [
		{"id": "pickaxe", "label": "Pickaxe"},
		{"id": "sickle", "label": "Sickle"}
	]
}

var _active_category: String = "Terrain"
var _selected_item: String = "grass_block"
var _tab_buttons: Dictionary = {}
var _item_buttons: Dictionary = {}
var _items_grid: GridContainer
var _active_category_label: Label


func _ready() -> void:
	_build()
	_select_category("Terrain")
	set_selected_item("grass_block")


func set_selected_item(item_id: String) -> void:
	_selected_item = item_id
	for key in _item_buttons.keys():
		var button := _item_buttons[key] as Button
		var active: bool = str(key) == _selected_item
		button.add_theme_color_override("font_color", Color("#fff8ea") if active else Color("#30251d"))
		button.add_theme_stylebox_override("normal", _item_style(active))


func all_item_ids() -> Array[String]:
	var item_ids: Array[String] = []
	for category in _category_names:
		for item in _items_by_category[category]:
			item_ids.append(str(item.get("id", "")))
	return item_ids


func active_item_buttons() -> Dictionary:
	return _item_buttons.duplicate()


func _build() -> void:
	var panel := PanelContainer.new()
	panel.name = "PalettePanel"
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.add_theme_stylebox_override("panel", _panel_style())
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 9)
	panel.add_child(margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 7)
	margin.add_child(stack)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	stack.add_child(header)

	var title := Label.new()
	title.text = "VOXEL CATALOG"
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color("#735239"))
	header.add_child(title)

	_active_category_label = Label.new()
	_active_category_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_active_category_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_active_category_label.add_theme_font_size_override("font_size", 11)
	_active_category_label.add_theme_color_override("font_color", Color("#8b6f54"))
	header.add_child(_active_category_label)

	var tabs := GridContainer.new()
	tabs.name = "CatalogCategoryGrid"
	tabs.columns = 3
	tabs.add_theme_constant_override("h_separation", 5)
	tabs.add_theme_constant_override("v_separation", 5)
	stack.add_child(tabs)

	for category in _category_names:
		var button := Button.new()
		button.name = "CatalogCategory_%s" % category
		button.text = "\n%s" % category
		button.tooltip_text = "%s voxel pieces" % category
		button.custom_minimum_size = Vector2(64, 46)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.focus_mode = Control.FOCUS_NONE
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.add_theme_font_size_override("font_size", 10)
		button.pressed.connect(_select_category.bind(category))
		tabs.add_child(button)
		_tab_buttons[category] = button
		_attach_icon(button, str(CATEGORY_ICON_IDS.get(category, "grass_block")), Vector2(26, 24), true)

	_items_grid = GridContainer.new()
	_items_grid.name = "CatalogItemGrid"
	_items_grid.columns = 2
	_items_grid.add_theme_constant_override("h_separation", 7)
	_items_grid.add_theme_constant_override("v_separation", 7)
	stack.add_child(_items_grid)


func _select_category(category: String) -> void:
	_active_category = category
	if _active_category_label:
		_active_category_label.text = category.to_upper()
	for key in _tab_buttons.keys():
		var button := _tab_buttons[key] as Button
		var active: bool = str(key) == category
		button.add_theme_color_override("font_color", Color("#fff8ea") if active else Color("#4d3c2e"))
		button.add_theme_stylebox_override("normal", _tab_style(active))
		button.add_theme_stylebox_override("hover", _tab_style(true))
		button.add_theme_stylebox_override("pressed", _tab_style(true))
	_rebuild_items()


func _rebuild_items() -> void:
	for child in _items_grid.get_children():
		child.queue_free()
	_item_buttons.clear()

	for data in _items_by_category[_active_category]:
		var item_id := str(data.get("id", ""))
		var button := Button.new()
		button.name = "CatalogItem_%s" % item_id
		button.text = "\n\n%s" % str(data.get("label", "Item"))
		button.tooltip_text = str(data.get("label", "Item"))
		button.custom_minimum_size = Vector2(98, 78)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.focus_mode = Control.FOCUS_NONE
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.add_theme_font_size_override("font_size", 13)
		var active: bool = item_id == _selected_item
		button.add_theme_color_override("font_color", Color("#fff8ea") if active else Color("#30251d"))
		button.add_theme_stylebox_override("normal", _item_style(active))
		button.add_theme_stylebox_override("hover", _item_style(true))
		button.add_theme_stylebox_override("pressed", _item_style(true))
		button.pressed.connect(_select_item.bind(item_id))
		_items_grid.add_child(button)
		_item_buttons[item_id] = button
		_attach_icon(button, item_id, Vector2(44, 43), true)


func _select_item(item_id: String) -> void:
	set_selected_item(item_id)
	item_selected.emit(item_id)


func _attach_icon(button: Button, icon_id: String, icon_size: Vector2, centered: bool) -> void:
	var icon = VoxelIconScript.new()
	button.add_child(icon)
	icon.configure(icon_id)
	icon.custom_minimum_size = icon_size
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if centered:
		icon.anchor_left = 0.5
		icon.anchor_right = 0.5
		icon.anchor_top = 0.0
		icon.offset_left = -icon_size.x * 0.5
		icon.offset_right = icon_size.x * 0.5
		icon.offset_top = 0.0
		icon.offset_bottom = icon_size.y
	else:
		icon.anchor_left = 0.0
		icon.anchor_top = 0.5
		icon.offset_left = 3.0
		icon.offset_right = 3.0 + icon_size.x
		icon.offset_top = -icon_size.y * 0.5
		icon.offset_bottom = icon_size.y * 0.5


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#fff8ea")
	style.border_color = Color("#c9b28e")
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	return style


func _tab_style(active: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#b84332") if active else Color("#f3e6cd")
	style.border_color = Color("#8e3428") if active else Color("#d4bd98")
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	if active:
		style.shadow_color = Color(0.22, 0.12, 0.07, 0.26)
		style.shadow_size = 2
		style.shadow_offset = Vector2(0, 2)
	return style


func _item_style(active: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#67863b") if active else Color("#fff0d3")
	style.border_color = Color("#405c27") if active else Color("#c9aa7b")
	style.set_border_width_all(2 if active else 1)
	style.set_corner_radius_all(9)
	style.shadow_color = Color(0.22, 0.12, 0.07, 0.20)
	style.shadow_size = 3
	style.shadow_offset = Vector2(0, 3)
	return style
