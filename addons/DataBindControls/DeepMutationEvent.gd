extends "res://addons/DataBindControls/MutationEvent.gd"

var path


func _init(_model, _index, _path: Array, _removed: bool).(_model, _index, _removed):
	path = _path


func to_string():
	return (
		"%s(%s)"
		% [
			get_script().resource_path.get_file().get_basename(),
			str({model = get_model(), index = index, path = path, removed = removed})
		]
	)
