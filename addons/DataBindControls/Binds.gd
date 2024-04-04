@tool
@icon("./icons/link.svg")
class_name Binds
extends Node

## Bind properties against a single control

const BindTarget := preload("./BindTarget.gd")
const Util := preload("./Util.gd")

const PASSTHROUGH_PROPS := [
	"editor_description", "process_mode", "process_priority", "script", "import_path"
]

const SIGNAL_PROPS := {
	visible = "visibility_changed", size = "resized", pressed = "pressed", text = "text_changed"
}

var _binds := {}


func _init():
	add_to_group(Util.BIND_GROUP)


func _get_property_list():
	# it seems impossible to do an inherited call of _get_property_list() directly.
	return _binds_get_property_list()


func _binds_get_property_list():
	var parent := get_parent()
	if !parent:
		return []
	var pl := parent.get_property_list().duplicate(true)
	for p in pl:
		if p.name in PASSTHROUGH_PROPS:
			continue
		# for some reason there's a property item with no name?
		# also only can provide bindings for properties that have a _changed signal
		if !p.name:
			pl.erase(p)
		p.hint_text = "BoundPropertyReadonly"
		if p.name in SIGNAL_PROPS:
			if parent.has_signal(SIGNAL_PROPS[p.name]):
				p.hint_text = "BoundProperty"
		if !_binds.get(p.name):
			# don't store bindings that are empty
			p.usage = p.usage & ~PROPERTY_USAGE_STORAGE
		p.erase("hint")
		p.erase("hint_string")
		p.type = TYPE_STRING
	return pl


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


func _bind_targets():
	var parent := get_parent()
	for p in _binds:
		_bind_target(p, parent)


func _bind_target(p: String, parent: Node) -> void:
	if !parent:
		parent = get_parent()
	if p in PASSTHROUGH_PROPS:
		return
	var b := _binds[p] as String
	if b:
		var bt = BindTarget.new(b, owner)
		if bt.target:
			parent[p] = bt.get_value()
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
	_unbind_targets()


func _unbind_targets():
	var parent := get_parent()
	assert(parent)
	for p in _binds:
		_unbind_target(p, parent)


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
	value = get_parent()[prop_name]
	var path = _binds[prop_name]
	if path:
		var bt = BindTarget.new(path, owner)
		if bt.get_value() != value:
			bt.set_value(value)
			DataBindings.detect_changes()


func detect_changes() -> bool:
	var changes_detected = false
	for p in _binds:
		if p in PASSTHROUGH_PROPS:
			continue
		var b := _binds[p] as String
		if b:
			var bt = BindTarget.new(b, owner)
			if bt.target:
				var parent = get_parent()
				var value = bt.get_value()
				if typeof(parent[p]) != typeof(value) || parent[p] != value:
					changes_detected = true
					var cp
					if "caret_column" in parent:
						cp = parent.caret_column
					parent[p] = value
					if "caret_column" in parent:
						parent.caret_column = cp

	return changes_detected
