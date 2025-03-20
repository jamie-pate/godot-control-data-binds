@tool
@icon("./icons/link.svg")
class_name Binds
extends Node

## Bind properties against a single control

const BindTarget := preload("./bind_target.gd")
const Util := preload("./util.gd")
const NUM_TYPES: Array[Variant.Type] = [TYPE_INT, TYPE_FLOAT]
const OBJ_TYPES: Array[Variant.Type] = [TYPE_NIL, TYPE_OBJECT]

const PASSTHROUGH_PROPS := [
	"editor_description", "process_mode", "process_priority", "script", "import_path"
]

const SIGNAL_PROPS := {
	visible = "visibility_changed",
	size = "resized",
	button_pressed = "pressed",
	text = "text_changed",
	value = "value_changed",
	selected = "item_selected"
}

var _bound_targets := {}
var _binds := {}
var _detected_change_log := []


func _get_property_list():
	# it seems impossible to do an inherited call of _get_property_list() directly.
	return _binds_get_property_list()


func _binds_get_property_list():
	var parent := get_parent()
	if !parent:
		return []
	var pl := parent.get_property_list().duplicate(true)
	var properties := []
	var default_category := {
		"name": "↔ Binds",
		"class_name": &"",
		"type": 4,
		"usage": 128,
	}
	var default_readonly_cat = default_category.duplicate()
	default_readonly_cat.name = "→ Binds"
	var readonly_props := [default_readonly_cat]
	var readwrite_props := [default_category]
	var readwrite_priority_props := [default_readonly_cat]
	var readonly_priority_props := [default_category]
	var group_or_cat_usage = (
		PROPERTY_USAGE_GROUP | PROPERTY_USAGE_CATEGORY | PROPERTY_USAGE_SUBGROUP
	)
	var cat_name := ""
	for p in pl:
		if p.usage & PROPERTY_USAGE_CHECKABLE:
			continue
		if p.usage & PROPERTY_USAGE_CATEGORY:
			cat_name = p.name
		var skip = p.name in PASSTHROUGH_PROPS || cat_name == "Node"
		if skip:
			p.usage = p.usage & ~PROPERTY_USAGE_STORAGE
		if skip || p.usage & group_or_cat_usage:
			properties.append(p)
		if skip:
			continue
		var readonly = true
		if p.name in SIGNAL_PROPS:
			if parent.has_signal(SIGNAL_PROPS[p.name]):
				readonly = false
		p.usage = p.usage & (PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_EDITOR | group_or_cat_usage)
		if !_binds.get(p.name):
			# don't store bindings that are empty
			p.usage = p.usage & ~PROPERTY_USAGE_STORAGE
		# Note hint_string doesn't do anything without a matching hint type
		# afaict there's no way to add custom docs for properties added by get_property_list
		p.erase("hint")
		p.erase("hint_string")
		p.type = TYPE_STRING
		if p.usage & group_or_cat_usage:
			p = p.duplicate()
			var name = p.name
			p.name = "↔ %s Binds" % [name]
			for list in [readwrite_priority_props, readwrite_props]:
				list.append(p)
			p = p.duplicate()
			p.name = "→ %s Binds" % [name]
			for list in [readonly_priority_props, readwrite_props]:
				list.append(p)
		else:
			var dest := []
			var priority := cat_name == parent.get_class()
			if readonly:
				dest = readonly_priority_props if priority else readonly_props
			else:
				dest = readwrite_priority_props if priority else readwrite_props
			dest.append(p)
	var result := []
	result.append_array(readwrite_priority_props)
	result.append_array(readonly_priority_props)
	result.append_array(readwrite_props)
	result.append_array(readonly_props)
	result.append_array(properties)
	return result


func _set(prop_name, value):
	# if this happens at runtime we need to _bind_targets() and _unbind_targets()
	assert(Engine.is_editor_hint() || !is_inside_tree())
	if prop_name in PASSTHROUGH_PROPS:
		var method_name = ("set%s" if prop_name.begins_with("_") else "set_%s") % prop_name
		if has_method(method_name):
			call(method_name, value)
		else:
			call("_%s" % [method_name], value)
	else:
		_binds[prop_name] = value
		update_configuration_warnings()


func _get(prop_name):
	if prop_name in PASSTHROUGH_PROPS:
		var method_name = ("get%s" if prop_name.begins_with("_") else "get_%s") % prop_name
		if has_method(method_name):
			return call(method_name)
		return call("_%s" % [method_name])
	return _binds.get(prop_name, "")


func _enter_tree():
	if Engine.is_editor_hint():
		return
	_bind_targets()
	DataBindings.add_bind(self)


func _bind_targets():
	var parent := get_parent()
	for p in _binds:
		_bind_target(p, parent)
	# visibility changed notifications don't propagate to non-controls
	if parent.has_signal("visibility_changed"):
		parent.visibility_changed.connect(_on_parent_visibility_changed)


func _bind_target(p: String, parent: Node) -> void:
	if !parent:
		parent = get_parent()
	if p in PASSTHROUGH_PROPS:
		return
	var b := _binds[p] as String
	if b:
		var bt = BindTarget.new(b, owner)
		var target = bt.get_target()
		_bound_targets[b] = bt
		if target:
			parent[p] = bt.get_value(target)
	var sig_map = Util.get_sig_map(parent)
	if p in SIGNAL_PROPS:
		var sig = SIGNAL_PROPS[p]
		if sig in sig_map:
			var method = "_on_parent_prop_changed%s" % [len(sig_map[sig].args)]
			var err = parent.connect(SIGNAL_PROPS[p], Callable(self, method).bind(p))
			assert(err == OK)


func _exit_tree():
	if Engine.is_editor_hint():
		return
	DataBindings.remove_bind(self)
	_unbind_targets()


func _unbind_targets():
	var parent := get_parent()
	assert(parent)
	for p in _binds:
		_unbind_target(p, parent)
	_bound_targets = {}
	if parent.has_signal("visibility_changed"):
		parent.visibility_changed.disconnect(_on_parent_visibility_changed)


func _on_parent_visibility_changed():
	DataBindings.update_bind_visibility(self)


func _unbind_target(p: String, parent: Node):
	if p in PASSTHROUGH_PROPS:
		return
	if !parent:
		parent = get_parent()
	var sig_map = Util.get_sig_map(parent)
	if p in SIGNAL_PROPS:
		var sig = SIGNAL_PROPS[p]
		if sig in sig_map:
			var method = "_on_parent_prop_changed%s" % [len(sig_map[sig].args)]
			parent.disconnect(SIGNAL_PROPS[p], Callable(self, method))


func _on_parent_prop_changed0(prop_name: String):
	_on_parent_prop_changed1(null, prop_name)


func _on_parent_prop_changed1(value, prop_name: String):
	var parent := get_parent()
	value = parent[prop_name]
	var bt = _bound_targets[_binds[prop_name]]
	var target = bt.get_target()
	if bt.get_value(target) != value:
		bt.set_value(target, value)
		DataBindings.detect_changes()


func detect_changes() -> bool:
	_detected_change_log = []
	var changes_detected = false
	for p in _binds:
		if p in PASSTHROUGH_PROPS:
			continue
		var b := _binds[p] as String
		if b:
			var bt = _bound_targets.get(b)
			if !bt:
				bt = BindTarget.new(b, owner)
				_bound_targets.set(b, bt)
			assert(bt.root == owner)
			var target = bt.get_target()
			if target:
				var parent = get_parent()
				var value = bt.get_value(target)
				if !_equal_approx(parent[p], value):
					_detected_change_log.append("%s: %s != %s" % [bt.full_path, parent[p], value])
					changes_detected = true
					var cp
					if "caret_column" in parent:
						cp = parent.caret_column
					parent[p] = value
					if "caret_column" in parent:
						parent.caret_column = cp
	return changes_detected


func _equal_approx(a, b):
	var a_type := typeof(a)
	var b_type := typeof(b)
	if a_type != b_type:
		# compare different types if they are both numbers
		var numbers = a_type in NUM_TYPES && b_type in NUM_TYPES
		var objects = a_type in OBJ_TYPES && b_type in OBJ_TYPES
		if !numbers && !objects:
			return false
	if a_type == TYPE_FLOAT || b_type == TYPE_FLOAT:
		return is_equal_approx(a, b)
	return a == b


func change_count():
	return len(_detected_change_log)


func get_desc():
	return "%s\n%s" % [get_path(), "\n".join(_detected_change_log)]
