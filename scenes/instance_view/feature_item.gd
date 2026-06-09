extends PanelContainer
class_name FeatureItem

signal selection_changed(item: FeatureItem, selected: bool)

# The feature this item represents
var feature: BaseFeatureNode = null
var is_selected: bool = false
var is_locked: bool = false            # constraint-driven lock (temporary)
var locked_by_mandatory: bool = false  # structural lock (permanent for this session)
var is_disabled: bool = false          # excluded by constraint

@onready var label: Label = $MarginContainer/HBoxContainer/Label
@onready var badge: Label = $MarginContainer/HBoxContainer/Badge
@onready var check: TextureRect = $MarginContainer/HBoxContainer/Check

const COLOR_DEFAULT    := Color(0.14, 0.14, 0.14, 1.0)
const COLOR_SELECTED   := Color(0.0,  0.46, 0.46, 1.0)
const COLOR_LOCKED     := Color(0.10, 0.35, 0.10, 1.0)
const COLOR_DISABLED   := Color(0.20, 0.20, 0.20, 0.5)
const COLOR_BADGE_ALT  := Color(0.7,  0.35, 0.0,  1.0)
const COLOR_BADGE_OR   := Color(0.35, 0.0,  0.7,  1.0)
const COLOR_BADGE_AND  := Color(0.15, 0.15, 0.15, 1.0)

func setup(feat: BaseFeatureNode) -> void:
	feature = feat
	label.text = feat.featureName if feat.featureName != "" else "(unnamed)"
	_update_badge()
	_refresh_style()

func set_selected(value: bool) -> void:
	if is_disabled and value:
		return
	is_selected = value
	_refresh_style()

func set_locked(value: bool, mandatory: bool = false) -> void:
	is_locked = value
	if mandatory:
		locked_by_mandatory = value
	if value:
		is_selected = true
	_refresh_style()

func set_disabled(value: bool) -> void:
	is_disabled = value
	if value:
		is_selected = false
	_refresh_style()

func _update_badge() -> void:
	if feature == null:
		badge.visible = false
		return
	if feature.isChildrenXor:
		badge.text = "ALT"
		badge.add_theme_color_override("font_color", Color.WHITE)
		var s := StyleBoxFlat.new()
		s.bg_color = COLOR_BADGE_ALT
		s.set_corner_radius_all(3)
		badge.add_theme_stylebox_override("normal", s)
		badge.visible = true
	elif feature.isChildrenOr:
		badge.text = "OR"
		badge.add_theme_color_override("font_color", Color.WHITE)
		var s := StyleBoxFlat.new()
		s.bg_color = COLOR_BADGE_OR
		s.set_corner_radius_all(3)
		badge.add_theme_stylebox_override("normal", s)
		badge.visible = true
	else:
		badge.visible = false

func _refresh_style() -> void:
	var s := StyleBoxFlat.new()
	s.set_corner_radius_all(5)
	s.set_content_margin_all(6)
	s.border_width_left = 3

	if is_disabled:
		s.bg_color = COLOR_DISABLED
		s.border_color = Color(0.3, 0.3, 0.3, 0.5)
		check.modulate = Color(0.4, 0.4, 0.4, 0.5)
		check.visible = false
	elif is_locked:
		s.bg_color = COLOR_LOCKED
		s.border_color = Color(0.4, 0.8, 0.4, 1.0)
		check.visible = true
		check.modulate = Color(0.6, 1.0, 0.6, 1.0)
	elif is_selected:
		s.bg_color = COLOR_SELECTED
		s.border_color = Color(0.0, 0.8, 0.8, 1.0)
		check.visible = true
		check.modulate = Color.WHITE
	else:
		s.bg_color = COLOR_DEFAULT
		s.border_color = Color(0.35, 0.35, 0.35, 1.0)
		check.visible = false
		check.modulate = Color.WHITE

	add_theme_stylebox_override("panel", s)

func _gui_input(event: InputEvent) -> void:
	if is_disabled or is_locked:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		selection_changed.emit(self, not is_selected)
