extends Reference

signal prop_changed(model, prop_name)

const PASSTHROUGH_PROPS := []
var _props := {}

func _init(data := {}):
	for p in data:
		_props[p] = data[p]


func _to_string():
	return str(_props)


func _set(prop_name, value):
	if prop_name in PASSTHROUGH_PROPS:
		var method_name = ('set%s' if prop_name.begins_with('_') else 'set_%s') % prop_name
		if has_method(method_name):
			call(method_name, value)
		else:
			call('_%s' % [method_name], value)
	else:
		var changed = _props.get(prop_name) != value
		_props[prop_name] = value
		if changed:
			_emit_changed(prop_name)


func _emit_changed(prop_name):
	emit_signal('prop_changed', self, prop_name)


func _get(prop_name):
	if prop_name in PASSTHROUGH_PROPS:
		var method_name = ('get%s' if prop_name.begins_with('_') else 'get_%s') % prop_name
		if has_method(method_name):
			return call(method_name)
		else:
			return call('_%s' % [method_name])
	else:
		return _props.get(prop_name, '')
