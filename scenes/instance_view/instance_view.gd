extends Control
class_name InstanceView

@onready var scroll: ScrollContainer = $ScrollContainer
@onready var feature_tree: FeatureTree = $ScrollContainer/FeatureTree
@onready var status_label: Label = $TopBar/StatusLabel
@onready var reset_btn: Button = $TopBar/ResetButton

func _ready() -> void:
	FeatureModelData.model_changed.connect(_on_model_changed)
	# If a model is already loaded (e.g. tab switched after model was built), build immediately
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
