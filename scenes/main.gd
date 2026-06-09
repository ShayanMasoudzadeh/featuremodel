extends Control

# Tab indices
const TAB_EDITOR      := 0
const TAB_INSTANTIATE := 1

@onready var tab_container: TabContainer = $TabContainer
@onready var graph_edit: GraphEdit       = $TabContainer/Editor/VBoxContainer/GraphEdit

func _on_tab_changed(tab: int) -> void:
	if tab == TAB_INSTANTIATE:
		graph_edit.publish_model()
