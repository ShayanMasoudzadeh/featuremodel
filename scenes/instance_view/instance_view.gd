extends Control
class_name InstanceView

@onready var feature_tree: FeatureTree = $VBoxContainer/ScrollContainer/FeatureTree
@onready var status_label: Label = $VBoxContainer/TopBar/StatusLabel

func _ready() -> void:
	FeatureModelData.model_changed.connect(_on_model_changed)
	if FeatureModelData.root != null:
		_rebuild()

func _on_model_changed() -> void:
	_rebuild()

func _rebuild() -> void:
	if FeatureModelData.root == null:
		status_label.text = "No model loaded. Define a model in the Editor tab first."
		return
	feature_tree.build(FeatureModelData.root, FeatureModelData.constraints)
	status_label.text = ""

func _on_reset_button_pressed() -> void:
	_rebuild()

func _on_save_instance_button_pressed() -> void:
	if FeatureModelData.root == null:
		return
	var selection := feature_tree.get_selection()
	FeatureModelExporter.save_instance(selection, "user://feature_instance.xml")
	status_label.text = "Saved to user://feature_instance.xml"
