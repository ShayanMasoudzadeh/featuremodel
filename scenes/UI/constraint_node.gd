extends MarginContainer
class_name ConstNode

signal delete_request(const_node: ConstNode, constraint: Constraint)

var constraint : Constraint :
	set(new_const):
		if constraint:
			constraint.from_node.name_changed.disconnect(_on_constraint_name_update)
			constraint.to_node.name_changed.disconnect(_on_constraint_name_update)
		
		new_const.from_node.name_changed.connect(_on_constraint_name_update)
		new_const.to_node.name_changed.connect(_on_constraint_name_update)
		constraint = new_const

@onready var text_label: Label = $PanelContainer/Label

func update_text() -> void:
	text_label.text = "  %s %s %s" % [constraint.from_node.featureName, constraint.type, constraint.to_node.featureName]

func _on_delete_button_pressed() -> void:
	delete_request.emit(self, constraint)

func _on_constraint_name_update() -> void:
	update_text()
