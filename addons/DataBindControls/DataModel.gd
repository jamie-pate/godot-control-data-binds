extends Reference

# a direct property of this model's data was changed
signal mutated(mutation_event)
# a property of a descendent was changed.
signal deep_mutated(deep_mutation_event)

const Util := preload("./Util.gd")
const MutationEvent := preload("./MutationEvent.gd")
const DeepMutationEvent := preload("./DeepMutationEvent.gd")
const PASSTHROUGH_PROPS := []
const NO_VALUE := {}
var _data := {}


func _init(data := {}):
	_assign_from(data)


func _assign_from(data: Dictionary):
	# TODO: should this be exposed?
	for p in data:
		_data[p] = data[p]
	for p in _data:
		_emit_mutated(p, _data[p])


func copy_signals_from_and_emit_changes(other_model):
	for s in other_model.get_signal_list():
		for sc in other_model.get_signal_connection_list(s.name):
			var err = connect(sc.signal, sc.target, sc.method, sc.binds, sc.flags)
			assert(err == OK)
	for p in other_model.keys():
		if !p in _data:
			_emit_mutated(p, NO_VALUE, [other_model[p]], true)
	for p in _data.keys():
		var new_value = _data[p]
		if p in other_model:
			var old_value = other_model[p]
			if typeof(new_value) != typeof(old_value) || new_value != old_value:
				_emit_mutated(p, new_value, old_value)
		else:
			_emit_mutated(p, new_value)


func keys():
	return _data.keys()


func erase(prop_name):
	var old_value = _data.get(prop_name)
	_data.erase(prop_name)
	if old_value != NO_VALUE:
		_emit_mutated(prop_name, NO_VALUE, old_value, true)


func values():
	return _data.values()


func _to_string():
	return str(_data)


func _find_prop_name(value):
	for k in _data:
		var v = _data[k]
		if typeof(v) == typeof(value) && v == value:
			return k
	assert(false)


func _set(prop_name, value):
	if prop_name in PASSTHROUGH_PROPS:
		var method_name = ("set%s" if prop_name.begins_with("_") else "set_%s") % prop_name
		if has_method(method_name):
			call(method_name, value)
		else:
			call("_%s" % [method_name], value)
	else:
		var old_value = _data.get(prop_name, NO_VALUE)
		var changed = typeof(old_value) != typeof(value) || old_value != value
		_data[prop_name] = value
		if changed:
			_emit_mutated(prop_name, value, old_value)
	return true


func _emit_mutated(prop_name, new_value, old_value = NO_VALUE, removed = false):
	if Util.is_model(old_value):
		for sig in Util.MODEL_SIGNALS:
			if old_value.has_signal(sig):
				old_value.disconnect(sig, self, "_on_value_%s" % [sig])
	if Util.is_model(new_value):
		for sig in Util.MODEL_SIGNALS:
			if new_value.has_signal(sig):
				var err = new_value.connect(sig, self, "_on_value_%s" % [sig])
				# TODO: this may fail if you try to add the same sub-model
				# instance as two or more different properties
				assert(err == OK)
	emit_signal("mutated", MutationEvent.new(self, prop_name, removed))


func _get(prop_name):
	if prop_name in PASSTHROUGH_PROPS:
		var method_name = ("get%s" if prop_name.begins_with("_") else "get_%s") % prop_name
		if has_method(method_name):
			return call(method_name)
		return call("_%s" % [method_name])
	return _data.get(prop_name, null)


func _emit_deep_mutated(e: MutationEvent, path: Array) -> void:
	var prop_name = _find_prop_name(e.get_model())
	var new_path = [prop_name]
	new_path.append_array(path)
	emit_signal("deep_mutated", DeepMutationEvent.new(self, prop_name, new_path, e.removed))


func _on_value_mutated(e: MutationEvent) -> void:
	_emit_deep_mutated(e, [e.index])


func _on_value_deep_mutated(e: DeepMutationEvent) -> void:
	_emit_deep_mutated(e, e.path)
