tool
extends Node

class_name DataBinds

const PASSTHROUGH_PROPS := [
	'editor_description',
	'pause_mode',
	'process_priority',
	'script',
	'import_path'
]

var _props := {}

func _get_property_list():
	var parent := get_parent()
	if !parent:
		return []
	var pl := parent.get_property_list().duplicate(true)
	for p in pl:
		if p.name in PASSTHROUGH_PROPS:
			continue
		if !p.name:
			# for some reason there's a property item with no name?
			pl.erase(p)
		p.erase('hint')
		p.erase('hint_string')
		p.hint_text = 'BoundProperty'
		p.type = TYPE_STRING
	return pl

func _set(prop_name, value):
	if prop_name in PASSTHROUGH_PROPS:
		var method_name = ('set%s' if prop_name.begins_with('_') else 'set_%s') % prop_name
		if has_method(method_name):
			call(method_name, value)
		else:
			call('_%s' % [method_name], value)
	_props[prop_name] = value

func _get(prop_name):
	if prop_name in PASSTHROUGH_PROPS:
		var method_name = ('get%s' if prop_name.begins_with('_') else 'get_%s') % prop_name
		if has_method(method_name):
			return call(method_name)
		else:
			return call('_%s' % [method_name])
	return _props.get(prop_name, '')
