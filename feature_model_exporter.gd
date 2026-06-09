extends Node
#class_name FeatureModelExporter

# ── public API ────────────────────────────────────────────────────────────────

static func save(root: BaseFeatureNode, constraints: Array[Constraint], path: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("FeatureModelExporter: cannot open '%s'" % path)
		return
	file.store_string(_build_xml(root, constraints))

static func save_instance(selection: Array[Dictionary], path: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("FeatureModelExporter: cannot open '%s'" % path)
		return
	file.store_string(_build_instance_xml(selection))

# ── Instance XML builder ──────────────────────────────────────────────────────

static func _build_instance_xml(selection: Array[Dictionary]) -> String:
	var lines: PackedStringArray = []
	lines.append('<?xml version="1.0" encoding="UTF-8"?>')
	lines.append("<configuration>")
	for entry in selection:
		var feature: BaseFeatureNode = entry["feature"]
		var name := _escape(feature.featureName)
		if entry["selected"]:
			var kind := "automatic" if entry["automatic"] else "manual"
			lines.append('  <feature %s="selected" name="%s"/>' % [kind, name])
		else:
			lines.append('  <feature manual="unselected" name="%s"/>' % name)
	lines.append("</configuration>")
	return "\n".join(lines)

# ── XML builder ───────────────────────────────────────────────────────────────

static func _build_xml(root: BaseFeatureNode, constraints: Array[Constraint]) -> String:
	return "\n".join([
		'<?xml version="1.0" encoding="UTF-8"?>',
		"<featureModel>",
		"  <struct>",
		_serialize_node(root, 2),
		"  </struct>",
		_serialize_constraints(constraints),
		"</featureModel>",
	])

# ── struct serializer ─────────────────────────────────────────────────────────

static func _serialize_node(node: BaseFeatureNode, depth: int) -> String:
	var pad  := "  ".repeat(depth)
	var name := ' name="%s"'        % _escape(node.featureName)
	var mand := ' mandatory="true"' if (node is FeatureNode and (node as FeatureNode).isMandatory) else ""

	if node.children.is_empty():
		return pad + "<feature%s%s/>" % [name, mand]

	var tag: String
	if   node.isChildrenXor: tag = "alt"
	elif node.isChildrenOr:  tag = "or"
	else:                    tag = "and"

	var lines: PackedStringArray = []
	lines.append(pad + "<%s%s%s>" % [tag, name, mand])
	for child in node.children:
		lines.append(_serialize_node(child, depth + 1))
	lines.append(pad + "</%s>" % tag)
	return "\n".join(lines)

# ── constraints serializer ────────────────────────────────────────────────────

static func _serialize_constraints(constraints: Array[Constraint]) -> String:
	if constraints.is_empty():
		return "  <constraints/>"

	var lines: PackedStringArray = []
	lines.append("  <constraints>")
	for c in constraints:
		var rule := _serialize_rule(c)
		if rule != "":
			lines.append(rule)
	lines.append("  </constraints>")
	return "\n".join(lines)

static func _serialize_rule(c: Constraint) -> String:
	var a := _escape(c.from_node.featureName)
	var b := _escape(c.to_node.featureName)

	# FeatureIDE propositional logic:
	#   requires → A ⇒  B        <imp><var>A</var><var>B</var></imp>
	#   excludes → A ⇒ ¬B        <imp><var>A</var><not><var>B</var></not></imp>
	match c.type:
		"requires":
			return "\n".join([
				"    <rule>",
				"      <imp>",
				"        <var>%s</var>" % a,
				"        <var>%s</var>" % b,
				"      </imp>",
				"    </rule>",
			])
		"excludes":
			return "\n".join([
				"    <rule>",
				"      <imp>",
				"        <var>%s</var>" % a,
				"        <not><var>%s</var></not>" % b,
				"      </imp>",
				"    </rule>",
			])
		_:
			push_warning("FeatureModelExporter: unknown constraint type '%s', skipping." % c.type)
			return ""

# ── helpers ───────────────────────────────────────────────────────────────────

static func _escape(s: String) -> String:
	return s \
		.replace("&",  "&amp;")  \
		.replace("<",  "&lt;")   \
		.replace(">",  "&gt;")   \
		.replace('"',  "&quot;") \
		.replace("'",  "&apos;")
