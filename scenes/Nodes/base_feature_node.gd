extends GraphNode
class_name BaseFeatureNode

signal name_changed()

@export var featureName: String = ""
@export var isChildrenXor: bool = false
@export var isChildrenOr: bool = false

@export var children: Array[FeatureNode] = []

func add_child_node(node: FeatureNode) -> void:
	if node and not node in children:
		children.append(node)

func remove_child_node(node: FeatureNode) -> void:
	if node:
		children.erase(node)

#=================================
# Input Signals
#=================================
func _on_xor_check_toggled(toggled_on: bool) -> void:
	isChildrenXor = toggled_on
	for child in children:
		child.update()

func _on_or_check_toggled(toggled_on: bool) -> void:
	isChildrenOr = toggled_on
	for child in children:
		child.update()
