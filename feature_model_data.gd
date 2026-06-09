extends Node
# Autoload singleton: FeatureModelData
# Carries the live model from the editor to the instance view.

signal model_changed()

var root: BaseFeatureNode = null
var constraints: Array[Constraint] = []

func publish(new_root: BaseFeatureNode, new_constraints: Array[Constraint]) -> void:
	root = new_root
	constraints = new_constraints
	model_changed.emit()
