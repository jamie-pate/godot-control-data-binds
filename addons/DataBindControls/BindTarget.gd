extends Reference

var full_path: String
var root
var target = null
var prop := ""


func _init(_path: String, _root):
	full_path = _path
	root = _root
	var path := Array(_path.split("."))
	var t = root
	while len(path) > 1:
		var p = path.pop_front()
		if t is Object && p in t:
			t = t[p]
		else:
			printerr("Unable to find bind %s on %s" % [full_path, root.get_path()])
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
