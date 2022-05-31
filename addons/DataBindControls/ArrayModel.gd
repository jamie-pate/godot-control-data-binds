extends Reference

# index of the item that was added/removed/replaced
# index is -1 if the whole array has been updated (clear, append_array, sort, sort_custom etc)
signal mutated(mutation_event)
# Item was mutated (some property of the item or it's descendents changed)
signal deep_mutated(deep_mutation_event)

const PASSTHROUGH_PROPS := []
const Util := preload("./Util.gd")
const MutationEvent := preload("./MutationEvent.gd")
const DeepMutationEvent := preload("./DeepMutationEvent.gd")

var _data := []


func _init(data := []):
	_data = data
	if len(data):
		_emit_mutated(-1, data)


func _to_string() -> String:
	return str(_data)


func size() -> int:
	return len(_data)


func append(value) -> void:
	_data.append(value)
	_emit_mutated(len(_data) - 1, [value])


func pop_back():
	var result = _data.pop_back()
	_emit_mutated(len(_data) + 1, [], [result], true)
	return result


func clear() -> void:
	var copy = _data.duplicate()
	_data.clear()
	_emit_mutated(-1, [], copy)


func append_array(array: Array) -> void:
	_data.append_array(array)
	_emit_mutated(-1, array)


func sort() -> void:
	_data.sort()
	_emit_mutated(-1)


func sort_custom(obj, f: String) -> void:
	_data.sort_custom(obj, f)
	_emit_mutated(-1)


func erase(value) -> void:
	var index = _data.find(value)
	remove(index)


func remove(index: int) -> void:
	if index > -1:
		var value = _data[index]
		_data.remove(index)
		_emit_mutated(index, [], [value], true)


func has(value) -> bool:
	return _data.has(value)


func find(value, from: int = 0) -> int:
	return _data.find(value, from)


func find_last(value) -> int:
	return _data.find_last(value)


func slice(begin: int, end: int, step := 1, deep := false) -> Array:
	return _data.slice(begin, end, step, deep)


# unfortunately gdscript has no way to overload the [] operator
func get_at(index: int):
	return _data[index]


# unfortunately gdscript has no way to overload the [] operator
func set_at(index: int, value) -> void:
	var old_value = _data[index] if len(_data) > index else null
	_data[index] = value
	_emit_mutated(index, [value], [old_value] if old_value != value else [])


func values() -> Array:
	return _data.duplicate()


func _emit_mutated(index: int, added_items := [], removed_items := [], removed := false) -> void:
	# add/remove hooks to propagate changes up the tree
	for item in removed_items:
		if Util.is_model(item):
			for sig in Util.MODEL_SIGNALS:
				if item.has_signal(sig):
					item.disconnect(sig, self, "_on_item_%s" % [sig])
	for item in added_items:
		if Util.is_model(item):
			for sig in Util.MODEL_SIGNALS:
				if item.has_signal(sig):
					var err = item.connect(sig, self, "_on_item_%s" % [sig])
					# TODO: this may fail if you try to add the same sub-model
					# instance as two or more different properties
					assert(err == OK)
	emit_signal("mutated", MutationEvent.new(self, index, removed))


func _emit_deep_mutated(e: MutationEvent, path: Array) -> void:
	var index = find(e.get_model())
	var new_path = [index]
	new_path.append_array(path)
	emit_signal("deep_mutated", DeepMutationEvent.new(self, index, new_path, e.removed))


func _on_item_mutated(e: MutationEvent) -> void:
	_emit_deep_mutated(e, [e.index])


func _on_item_deep_mutated(e: DeepMutationEvent) -> void:
	_emit_deep_mutated(e, e.path)
