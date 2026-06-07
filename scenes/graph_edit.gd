extends GraphEdit

signal update_nodes()

# Add Constraint Window nodes
@onready var add_const_window: PanelContainer = $AddConstWindow
@onready var from_option_btn: OptionButton = $AddConstWindow/VBoxContainer/HBoxContainer/FromOptionBtn
@onready var type_option_btn: OptionButton = $AddConstWindow/VBoxContainer/HBoxContainer/TypeOptionBtn
@onready var to_option_btn: OptionButton = $AddConstWindow/VBoxContainer/HBoxContainer/ToOptionBtn

@onready var constraints_cont: VBoxContainer = $FoldableContainer/ScrollContainer/ConstraintsCont
const CONSTRAINT_NODE = preload("uid://c1fw68hmhp7ts")

var nodes: Array[BaseFeatureNode] = []
var constraints: Array[Constraint] = []

const FEATURE_NODE = preload("uid://bqc4u7xobsat")

func _ready() -> void:
	add_to_nodes($RootNode)

func add_to_nodes(node: BaseFeatureNode) -> void:
	nodes.append(node)
	update_nodes.connect(node.update if node.has_method("update") else func(): pass)

func _on_add_node_button_pressed() -> void:
	var new_node: FeatureNode = FEATURE_NODE.instantiate()
	add_child(new_node)
	add_to_nodes(new_node)

func _on_connection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	var from: BaseFeatureNode = get_node(String(from_node)) as BaseFeatureNode
	var to: FeatureNode = get_node(String(to_node)) as FeatureNode
	if from == null or to == null:
		return

	for connection in connections:
		if connection["to_node"] == to_node:
			_on_disconnection_request(connection["from_node"], connection["from_port"], to_node, to_port)
			break

	from.add_child_node(to)
	to.set_parent(from)
	connect_node(from_node, from_port, to_node, to_port)
	update_nodes.emit()

func _on_disconnection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	var from: BaseFeatureNode = get_node(String(from_node)) as BaseFeatureNode
	var to: FeatureNode = get_node(String(to_node)) as FeatureNode
	if from == null or to == null:
		return

	from.remove_child_node(to)
	to.clear_parent()
	disconnect_node(from_node, from_port, to_node, to_port)
	update_nodes.emit()

func _on_save_xml_button_pressed() -> void:
	var root: BaseFeatureNode = $RootNode
	FeatureModelExporter.save(root, constraints, "user://feature_model.xml")

func add_constraint(from_feature: BaseFeatureNode, to_feature: BaseFeatureNode, type: String) -> void:
	var constraint: Constraint = Constraint.new()
	constraint.from_node = from_feature
	constraint.type = type
	constraint.to_node = to_feature
	constraints.append(constraint)

	var const_node: ConstNode = CONSTRAINT_NODE.instantiate()
	const_node.constraint = constraint
	const_node.delete_request.connect(on_remove_constraint)
	constraints_cont.add_child(const_node)
	const_node.update_text()

func on_remove_constraint(const_node: ConstNode, constraint: Constraint) -> void:
	constraints.erase(constraint)
	const_node.queue_free()

func _on_add_constraint_button_pressed() -> void:
	add_const_window.visible = true
	update_const_option_btns()

func _on_add_const_cancel_button_pressed() -> void:
	add_const_window.visible = false

func _on_add_const_add_button_pressed() -> void:
	if (from_option_btn.selected == -1 or
		type_option_btn.selected == -1 or
		to_option_btn.selected == -1):
			return
	if from_option_btn.selected == to_option_btn.selected:
		return

	add_constraint(
		nodes[from_option_btn.selected],
		nodes[to_option_btn.selected],
		type_option_btn.get_item_text(type_option_btn.selected)
	)

	$FoldableContainer.folded = false
	add_const_window.visible = false

func update_const_option_btns() -> void:
	from_option_btn.clear()
	to_option_btn.clear()

	for node in nodes:
		from_option_btn.add_item(node.featureName)
		to_option_btn.add_item(node.featureName)

	from_option_btn.selected = -1
	to_option_btn.selected = -1
