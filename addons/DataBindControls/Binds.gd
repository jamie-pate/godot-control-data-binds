tool
extends Node

class_name Binds

const PASSTHROUGH_PROPS := [
	'editor_description',
	'pause_mode',
	'process_priority',
	'script',
	'import_path'
]

const SIGNAL_PROPS := {
	visible = 'visibility_changed',
	rect_size = 'resized',
	pressed = 'pressed',
	text = 'text_changed'
}

var _binds := {}
var _exited := false


class BindTarget extends Reference:
	var full_path: String
	var root
	var target = null
	var prop := ''

	func _init(_path: String, _root):
		full_path = _path
		root = _root
		var path := Array(_path.split('.'))
		var t = root
		while len(path) > 1:
			var p = path.pop_front()
			if p in t:
				t = t[p]
			else:
				printerr('Unable to find bind %s on %s' % [full_path, root.get_path()])
				break
		if len(path) == 1:
			prop = path[0]
			target = t

	func get_value():
		assert(target)
		return target.get(prop)


	func set_value(value):
		assert(target)

		target.set(prop, value)

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
		p.hint_text = 'BoundPropertyReadonly'
		if p.name in SIGNAL_PROPS:
			if parent.has_signal(SIGNAL_PROPS[p.name]):
				p.hint_text = 'BoundProperty'
		p.erase('hint')
		p.erase('hint_string')
		p.type = TYPE_STRING
	return pl


func _set(prop_name, value):
	if prop_name in PASSTHROUGH_PROPS:
		var method_name = ('set%s' if prop_name.begins_with('_') else 'set_%s') % prop_name
		if has_method(method_name):
			call(method_name, value)
		else:
			call('_%s' % [method_name], value)
	else:
		_binds[prop_name] = value


func _get(prop_name):
	if prop_name in PASSTHROUGH_PROPS:
		var method_name = ('get%s' if prop_name.begins_with('_') else 'get_%s') % prop_name
		if has_method(method_name):
			return call(method_name)
		else:
			return call('_%s' % [method_name])
	else:
		return _binds.get(prop_name, '')


func _enter_tree():
	assert(!_exited)
	var parent := get_parent()
	for p in _binds:
		if p in PASSTHROUGH_PROPS:
			continue
		var b := _binds[p] as String
		if b:
			var bt = BindTarget.new(b, owner)
			if bt.target:
				parent[p] = bt.get_value()
				if bt.target.has_signal('prop_changed'):
					var err = bt.target.connect('prop_changed', self, '_on_model_prop_changed')
					assert(err == OK)
		if p in SIGNAL_PROPS:
			if parent.has_signal(SIGNAL_PROPS[p]):
				var err = parent.connect(SIGNAL_PROPS[p], self, '_on_parent_prop_changed', [p])
				assert(err == OK)

func _exit_tree():
	_exited = true
	# TODO: exit_tree disconnect all signals etc?


func _on_parent_prop_changed(value = null, prop_name = null):
	# deal with 'varargs' method of connecting to signals with different arrity
	if prop_name == null:
		prop_name = value
	value = get_parent()[prop_name]
	var path = _binds[prop_name]
	if path:
		var bt = BindTarget.new(path, owner)
		if bt.get_value() != value:
			bt.set_value(value)


func _on_model_prop_changed(model, prop_name):
	for p in _binds:
		if p in PASSTHROUGH_PROPS:
			continue
		var b := _binds[p] as String
		if b:
			var bt = BindTarget.new(b, owner)
			if bt.target == model && prop_name == bt.prop:
				var parent = get_parent()
				var cp
				if 'caret_position' in parent:
					cp = parent.caret_position
				parent[p] = bt.get_value()
				if 'caret_position' in parent:
					parent.caret_position = cp
