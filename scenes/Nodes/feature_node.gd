extends BaseFeatureNode
class_name FeatureNode

@onready var name_edit: TextEdit = $NameCont/TextEdit
@onready var optional_check: CheckBox = $OptionalCont/CheckBox
@onready var xor_check: CheckBox = $XorCont/CheckBox
@onready var or_check: CheckBox = $OrCont/CheckBox

@export var isMandatory: bool = false
@export var parent: GraphNode = null

func update() -> void:
	if parent:
		if parent.isChildrenXor or parent.isChildrenOr:
			isMandatory = false
			optional_check.disabled = true
		else:
			optional_check.disabled = false
	else:
		optional_check.disabled = false

	name_edit.text = featureName
	optional_check.button_pressed = isMandatory
	xor_check.button_pressed = isChildrenXor
	or_check.button_pressed = isChildrenOr

func set_parent(node: GraphNode) -> void:
	if node:
		parent = node

func clear_parent() -> void:
	parent = null

#=================================
# Input Signals
#=================================
func _on_name_edit_text_changed() -> void:
	featureName = name_edit.text
	name_changed.emit()

func _on_optional_check_toggled(toggled_on: bool) -> void:
	isMandatory = toggled_on
