extends Node
# Autoload singleton: ModelValidator
#
# Validates a feature model by simulating constraint propagation from the
# mandatory baseline and reporting any contradictions found.
#
# Two passes:
#   Pass 1 - Mandatory baseline: start from always-on features, propagate,
#            check for contradictions reachable without any user selection.
#   Pass 2 - Optional feature sweep: for each optional feature, hypothetically
#            force it on and propagate, check if selecting it is self-defeating.

# ── Public API ────────────────────────────────────────────────────────────────

static func validate(root: BaseFeatureNode, constraints: Array[Constraint]) -> Array[String]:
	var errors: Array[String] = []

	var all_features: Array[BaseFeatureNode] = []
	_collect_features(root, all_features)

	# ── Pass 1: mandatory baseline ────────────────────────────────────────────
	var base_selected: Dictionary = {}
	var base_disabled: Dictionary = {}
	for f in all_features:
		base_selected[f] = _is_always_on(f, root)
		base_disabled[f] = false

	_propagate(constraints, base_selected, base_disabled)
	_check_baseline(all_features, constraints, base_selected, base_disabled, errors)

	# ── Pass 2: optional feature sweep ───────────────────────────────────────
	for candidate in all_features:
		if _is_always_on(candidate, root):
			continue  # already covered by pass 1

		# Clone baseline state and force this feature on
		var sel := base_selected.duplicate()
		var dis := base_disabled.duplicate()

		# If the candidate is already disabled in the baseline, selecting it
		# is impossible — that's already caught or will be caught elsewhere
		if dis[candidate]:
			continue

		sel[candidate] = true
		_propagate(constraints, sel, dis)
		_check_optional(candidate, all_features, constraints, sel, dis, root, errors)

	# Deduplicate in case both passes produce the same message
	var seen: Dictionary = {}
	var deduped: Array[String] = []
	for e in errors:
		if not seen.has(e):
			seen[e] = true
			deduped.append(e)
	return deduped

# ── Pass 1 checks ─────────────────────────────────────────────────────────────

static func _check_baseline(
	all_features: Array[BaseFeatureNode],
	constraints: Array[Constraint],
	selected: Dictionary,
	disabled: Dictionary,
	errors: Array[String]
) -> void:
	# Check 1a: mandatory feature ended up disabled
	for f in all_features:
		if not selected.get(f, false) and not disabled.get(f, false):
			continue  # not mandatory, skip
		if not disabled.get(f, false):
			continue
		# f is mandatory but disabled
		var name := _fname(f)
		var cause_found := false
		for c in constraints:
			if c.type == "excludes" and c.to_node == f and selected.get(c.from_node, false):
				errors.append(
					"Contradiction: \"%s\" is mandatory but excluded by \"%s excludes %s\"."
					% [name, _fname(c.from_node), name]
				)
				cause_found = true
		if not cause_found:
			errors.append(
				"Contradiction: \"%s\" is mandatory but ends up disabled by transitive constraints."
				% name
			)

	# Check 1b: alt/or group active in baseline but all children disabled
	for f in all_features:
		if f.children.is_empty() or not (f.isChildrenXor or f.isChildrenOr):
			continue
		if not selected.get(f, false):
			continue
		var available := 0
		for child in f.children:
			if not disabled.get(child, false):
				available += 1
		if available == 0:
			var kind := "ALT" if f.isChildrenXor else "OR"
			errors.append(
				"Contradiction: \"%s\" is a %s group but all its children are disabled by constraints."
				% [_fname(f), kind]
			)

	# Check 1c: alt group with multiple mandatory children
	for f in all_features:
		if not f.isChildrenXor:
			continue
		var mandatory_children := 0
		for child in f.children:
			if child is FeatureNode and (child as FeatureNode).isMandatory:
				mandatory_children += 1
		if mandatory_children > 1:
			errors.append(
				"Contradiction: \"%s\" is an ALT group but has %d mandatory children (at most one can be selected)."
				% [_fname(f), mandatory_children]
			)

# ── Pass 2 checks ─────────────────────────────────────────────────────────────

static func _check_optional(
	candidate: BaseFeatureNode,
	all_features: Array[BaseFeatureNode],
	constraints: Array[Constraint],
	selected: Dictionary,
	disabled: Dictionary,
	root: BaseFeatureNode,
	errors: Array[String]
) -> void:
	var cname := _fname(candidate)

	# Check 2a: selecting this feature disables itself
	# (e.g. A excludes A, or A requires B and B excludes A)
	if disabled.get(candidate, false):
		errors.append(
			"Unsatisfiable: selecting \"%s\" leads to a contradiction that disables itself."
			% cname
		)
		return

	# Check 2b: selecting this feature disables a mandatory feature
	for f in all_features:
		if not _is_always_on(f, root):
			continue
		if disabled.get(f, false):
			var fname := _fname(f)
			# Find the most direct cause in the constraint list
			var direct_cause := ""
			for c in constraints:
				if c.type == "excludes" and c.to_node == f and selected.get(c.from_node, false):
					direct_cause = "\"%s\" excludes \"%s\"" % [_fname(c.from_node), fname]
					break
			if direct_cause != "":
				errors.append(
					"Unsatisfiable: selecting \"%s\" triggers %s (mandatory feature disabled)."
					% [cname, direct_cause]
				)
			else:
				errors.append(
					"Unsatisfiable: selecting \"%s\" transitively disables mandatory feature \"%s\"."
					% [cname, fname]
				)

	# Check 2c: selecting this feature makes an alt/or group unsatisfiable
	for f in all_features:
		if f.children.is_empty() or not (f.isChildrenXor or f.isChildrenOr):
			continue
		if not selected.get(f, false):
			continue
		var available := 0
		for child in f.children:
			if not disabled.get(child, false):
				available += 1
		if available == 0:
			var kind := "ALT" if f.isChildrenXor else "OR"
			errors.append(
				"Unsatisfiable: selecting \"%s\" disables all children of %s group \"%s\"."
				% [cname, kind, _fname(f)]
			)

	# Check 2d: selecting this feature requires an ALT sibling
	# (forces a sibling on, but being in the same ALT group means only one can be active)
	var parent := _get_parent(candidate)
	if parent != null and parent.isChildrenXor:
		for c in constraints:
			if c.from_node == candidate and c.type == "requires":
				var target := c.to_node
				# Is target a sibling in the same ALT group?
				if parent.children.has(target):
					errors.append(
						"Unsatisfiable: \"%s\" requires \"%s\" but they are siblings in ALT group \"%s\" (only one can be selected)."
						% [cname, _fname(target), _fname(parent)]
					)

# ── Simulation ────────────────────────────────────────────────────────────────

static func _propagate(
	constraints: Array[Constraint],
	selected: Dictionary,
	disabled: Dictionary
) -> void:
	var changed := true
	while changed:
		changed = false
		for c in constraints:
			var from: BaseFeatureNode = c.from_node
			var to: BaseFeatureNode   = c.to_node
			if not selected.has(from) or not selected.has(to):
				continue
			if not selected[from]:
				continue
			match c.type:
				"requires":
					if not selected[to]:
						selected[to] = true
						changed = true
				"excludes":
					if not disabled[to]:
						disabled[to] = true
						selected[to] = false
						changed = true

# ── Helpers ───────────────────────────────────────────────────────────────────

static func _collect_features(node: BaseFeatureNode, out: Array[BaseFeatureNode]) -> void:
	out.append(node)
	for child in node.children:
		_collect_features(child, out)

static func _is_always_on(feature: BaseFeatureNode, root: BaseFeatureNode) -> bool:
	if feature == root:
		return true
	if feature is FeatureNode:
		return (feature as FeatureNode).isMandatory
	return false

static func _get_parent(feature: BaseFeatureNode) -> BaseFeatureNode:
	if feature is FeatureNode:
		var p := (feature as FeatureNode).parent
		if p is BaseFeatureNode:
			return p as BaseFeatureNode
	return null

static func _fname(feature: BaseFeatureNode) -> String:
	return feature.featureName if feature.featureName != "" else "(unnamed)"
