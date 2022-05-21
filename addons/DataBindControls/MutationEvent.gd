extends Reference

const Util := preload("./Util.gd")

var model: WeakRef
var index
var removed: bool


func _init(_model, _index, _removed: bool):
	assert(Util.is_model(_model))
	model = weakref(_model)
	index = _index
	removed = _removed


func get_model():
	return model.get_ref()


func _to_string():
	return (
		"%s(%s)"
		% [
			get_script().resource_path.get_file().get_basename(),
			str({model = get_model(), index = index, removed = removed})
		]
	)
