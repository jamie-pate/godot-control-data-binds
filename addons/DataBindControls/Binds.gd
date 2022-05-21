tool
class_name Binds
extends Node

const BindTarget := preload("./BindTarget.gd")
const Util := preload("./Util.gd")

const PASSTHROUGH_PROPS := [
	"editor_description", "pause_mode", "process_priority", "script", "import_path"
]

const SIGNAL_PROPS := {
	visible = "visibility_changed",
	rect_size = "resized",
	pressed = "pressed",
	text = "text_changed"
}

var _binds := {}


func _get_property_list():
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
		p.erase("hint")
		p.erase("hint_string")
		p.type = TYPE_STRING
	return pl


func _set(prop_name, value):
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
	if Engine.editor_hint:
		return
	var parent := get_parent()
	for p in _binds:
		if p in PASSTHROUGH_PROPS:
			continue
		var b := _binds[p] as String
		if b:
			var bt = BindTarget.new(b, owner)
			if bt.target:
				parent[p] = bt.get_value()
				if bt.target.has_signal("mutated"):
					var err = bt.target.connect("mutated", self, "_on_model_mutated")
					assert(err == OK)
		var sig_map = Util.get_sig_map(parent)
		if p in SIGNAL_PROPS:
			var sig = SIGNAL_PROPS[p]
			if sig in sig_map:
				var method = "_on_parent_prop_changed%s" % [len(sig_map[sig].args)]
				var err = parent.connect(SIGNAL_PROPS[p], self, method, [p])
				assert(err == OK)


func _exit_tree():
	if Engine.editor_hint:
		return
	var parent := get_parent()
	for p in _binds:
		if p in PASSTHROUGH_PROPS:
			continue
		var b := _binds[p] as String
		if b:
			var bt = BindTarget.new(b, owner)
			if bt.target && bt.target.has_signal("mutated"):
				bt.target.disconnect("mutated", self, "_on_model_mutated")
		var sig_map = Util.get_sig_map(parent)
		if p in SIGNAL_PROPS:
			var sig = SIGNAL_PROPS[p]
			if sig in sig_map:
				var method = "_on_parent_prop_changed%s" % [len(sig_map[sig].args)]
				parent.disconnect(SIGNAL_PROPS[p], self, method)


func _on_parent_prop_changed0(prop_name: String):
	_on_parent_prop_changed1(null, prop_name)


func _on_parent_prop_changed1(value, prop_name: String):
	value = get_parent()[prop_name]
	var path = _binds[prop_name]
	if path:
		var bt = BindTarget.new(path, owner)
		if bt.get_value() != value:
			bt.set_value(value)


func _on_model_mutated(event):
	var model = event.get_model()
	for p in _binds:
		if p in PASSTHROUGH_PROPS:
			continue
		var b := _binds[p] as String
		if b:
			var bt = BindTarget.new(b, owner)
			if bt.target == model && event.index == bt.prop:
				var parent = get_parent()
				var cp
				if "caret_position" in parent:
					cp = parent.caret_position
				parent[p] = bt.get_value()
				if "caret_position" in parent:
					parent.caret_position = cp
