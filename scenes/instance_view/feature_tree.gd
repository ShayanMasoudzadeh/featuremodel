extends Control
class_name FeatureTree

const FEATURE_ITEM = preload("res://scenes/instance_view/feature_item.tscn")

const H_GAP     := 60    # horizontal gap between levels
const V_GAP     := 14    # vertical gap between siblings
const ITEM_H    := 36    # item height (matches FeatureItem minimum)
const ITEM_W    := 150   # item width

# Map from BaseFeatureNode → FeatureItem
var _item_map: Dictionary = {}
# All items in order, for constraint propagation
var _all_items: Array[FeatureItem] = []
# Constraints reference
var _constraints: Array[Constraint] = []

func build(root: BaseFeatureNode, constraints: Array[Constraint]) -> void:
	# Clear previous
	for child in get_children():
		child.queue_free()
	_item_map.clear()
	_all_items.clear()
	_constraints = constraints

	# Recursively instantiate and position items
	var total_height := _place_node(root, 0, 0.0)
	custom_minimum_size = Vector2((total_height + 1) * (ITEM_W + H_GAP), total_height * (ITEM_H + V_GAP))

	# Root is always active
	var root_item: FeatureItem = _item_map.get(root)
	if root_item:
		root_item.set_locked(true, true)

	# Apply initial mandatory selections and constraint propagation
	_apply_initial_state(root)
	_propagate_constraints()
	queue_redraw()

# Returns the number of leaf-rows this subtree occupies
func _place_node(node: BaseFeatureNode, depth: int, y_offset: float) -> float:
	var item: FeatureItem = FEATURE_ITEM.instantiate()
	add_child(item)
	item.setup(node)
	item.selection_changed.connect(_on_item_selection_changed)
	_item_map[node] = item
	_all_items.append(item)

	var children: Array = node.children
	if children.is_empty():
		item.position = Vector2(depth * (ITEM_W + H_GAP), y_offset * (ITEM_H + V_GAP))
		item.custom_minimum_size = Vector2(ITEM_W, ITEM_H)
		return 1.0

	# Place children first to know their total height
	var child_start := y_offset
	var total_rows := 0.0
	for child in children:
		var rows := _place_node(child, depth + 1, y_offset + total_rows)
		total_rows += rows

	# Centre this node vertically over its children
	var centre_y := y_offset + (total_rows - 1.0) / 2.0
	item.position = Vector2(depth * (ITEM_W + H_GAP), centre_y * (ITEM_H + V_GAP))
	item.custom_minimum_size = Vector2(ITEM_W, ITEM_H)
	return total_rows

func _apply_initial_state(node: BaseFeatureNode) -> void:
	for child in node.children:
		var item: FeatureItem = _item_map.get(child)
		if item == null:
			continue
		if child.isMandatory:
			item.set_locked(true, true)
		_apply_initial_state(child)

# ── Connector lines ───────────────────────────────────────────────────────────

func _draw() -> void:
	for node in _item_map.keys():
		if node.children.is_empty():
			continue
		var parent_item: FeatureItem = _item_map[node]
		var px := parent_item.position.x + ITEM_W
		var py := parent_item.position.y + ITEM_H / 2.0

		# Draw group arc indicator for xor/or
		var child_items: Array = []
		for child in node.children:
			var ci: FeatureItem = _item_map.get(child)
			if ci:
				child_items.append(ci)

		for child in node.children:
			var child_item: FeatureItem = _item_map.get(child)
			if child_item == null:
				continue
			var cy := child_item.position.y + ITEM_H / 2.0
			var mid_x := px + H_GAP * 0.4

			var color := Color(0.4, 0.4, 0.4, 0.8)
			if child_item.is_selected or child_item.is_locked:
				color = Color(0.0, 0.75, 0.75, 1.0)
			elif child_item.is_disabled:
				color = Color(0.3, 0.3, 0.3, 0.4)

			# Elbow: horizontal from parent, then vertical, then horizontal to child
			draw_line(Vector2(px, py), Vector2(mid_x, py), color, 1.5, true)
			draw_line(Vector2(mid_x, py), Vector2(mid_x, cy), color, 1.5, true)
			draw_line(Vector2(mid_x, cy), Vector2(child_item.position.x, cy), color, 1.5, true)

		# Draw group bracket for xor / or
		if node.isChildrenXor or node.isChildrenOr:
			if child_items.size() > 1:
				var top_y := (child_items[0] as FeatureItem).position.y + ITEM_H / 2.0
				var bot_y := (child_items[-1] as FeatureItem).position.y + ITEM_H / 2.0
				var bracket_x := px + H_GAP * 0.4
				var arc_color := Color(0.7, 0.35, 0.0, 0.9) if node.isChildrenXor else Color(0.35, 0.0, 0.7, 0.9)
				draw_line(Vector2(bracket_x - 4, top_y), Vector2(bracket_x - 4, bot_y), arc_color, 3.0, true)

# ── Selection logic ───────────────────────────────────────────────────────────

func _on_item_selection_changed(item: FeatureItem, new_selected: bool) -> void:
	var feature: BaseFeatureNode = _get_feature_for_item(item)
	if feature == null:
		return

	item.set_selected(new_selected)

	# When selecting, ensure all ancestors are selected too
	if new_selected:
		_select_ancestors(feature)

	# Enforce parent group rules
	var parent_feature := _get_parent_of(feature)
	if parent_feature != null:
		if parent_feature.isChildrenXor and new_selected:
			# Deselect all siblings
			for sibling in parent_feature.children:
				if sibling != feature:
					var sib_item: FeatureItem = _item_map.get(sibling)
					if sib_item and not sib_item.is_locked:
						sib_item.set_selected(false)
						_deselect_subtree(sibling)
		elif parent_feature.isChildrenOr:
			# Ensure at least one remains selected — prevent last one being deselected
			if not new_selected:
				var any_selected := false
				for sibling in parent_feature.children:
					var sib_item: FeatureItem = _item_map.get(sibling)
					if sib_item and (sib_item.is_selected or sib_item.is_locked):
						any_selected = true
						break
				if not any_selected:
					item.set_selected(true) # revert
					return

	# When deselecting, deselect the whole subtree
	if not new_selected:
		_deselect_subtree(feature)

	_propagate_constraints()
	queue_redraw()

func _select_ancestors(node: BaseFeatureNode) -> void:
	var parent := _get_parent_of(node)
	while parent != null:
		var parent_item: FeatureItem = _item_map.get(parent)
		if parent_item and not parent_item.is_selected and not parent_item.is_locked:
			parent_item.set_selected(true)
		parent = _get_parent_of(parent)

func _deselect_subtree(node: BaseFeatureNode) -> void:
	for child in node.children:
		var ci: FeatureItem = _item_map.get(child)
		if ci and not ci.is_locked:
			ci.set_selected(false)
		_deselect_subtree(child)

func _get_feature_for_item(item: FeatureItem) -> BaseFeatureNode:
	for key in _item_map.keys():
		if _item_map[key] == item:
			return key
	return null

func _get_parent_of(feature: BaseFeatureNode) -> BaseFeatureNode:
	if feature is FeatureNode:
		var fn := feature as FeatureNode
		if fn.parent is BaseFeatureNode:
			return fn.parent as BaseFeatureNode
	return null

# ── Public API ────────────────────────────────────────────────────────────────

# Returns Array of Dictionaries: {feature: BaseFeatureNode, selected: bool, automatic: bool}
func get_selection() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for feature in _item_map.keys():
		var item: FeatureItem = _item_map[feature]
		result.append({
			"feature": feature,
			"selected": item.is_selected or item.is_locked,
			"automatic": item.locked_by_mandatory or item.is_locked,
		})
	return result

# ── Constraint propagation ────────────────────────────────────────────────────

func _propagate_constraints() -> void:
	# Reset only constraint-driven state; mandatory locks (_locked_by_mandatory) are preserved
	for item in _all_items:
		if not item.locked_by_mandatory:
			item.is_locked = false
		item.is_disabled = false

	for c in _constraints:
		var from_item: FeatureItem = _item_map.get(c.from_node)
		var to_item: FeatureItem   = _item_map.get(c.to_node)
		if from_item == null or to_item == null:
			continue

		var from_active := from_item.is_selected or from_item.is_locked
		if not from_active:
			continue

		match c.type:
			"requires":
				if not to_item.locked_by_mandatory:
					to_item.is_locked = true
					to_item.is_selected = true
			"excludes":
				if not to_item.locked_by_mandatory:
					to_item.is_disabled = true
					to_item.is_selected = false

	# Refresh visuals
	for item in _all_items:
		item._refresh_style()
