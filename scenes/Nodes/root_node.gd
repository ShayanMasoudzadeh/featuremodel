extends BaseFeatureNode
class_name RootNode

@onready var name_edit: TextEdit = $NameCont/TextEdit
@onready var xor_check: CheckBox = $XorCont/CheckBox
@onready var or_check: CheckBox = $OrCont/CheckBox

#=================================
# Input Signals
#=================================
func _on_name_edit_text_changed() -> void:
	featureName = name_edit.text
	name_changed.emit()
