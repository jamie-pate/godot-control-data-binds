extends RefCounted

var full_path: String
var root
var target = null
var prop := ""
var callable_str := ""


func _init(_path: String, _root, silent := false, c := ""):
	callable_str = c
	full_path = _path
	root = _root
	var path := Array(_path.split("."))
	var t = root
	while len(path) > 1:
		var p = path.pop_front()
		if t != null && t is Object && p in t:
			t = t[p]
		else:
			if !silent:
				printerr(
					(
						"Unable to find bind %s on %s"
						% [full_path, root.get_path() if root is Node else root]
					)
				)
			break
	if len(path) == 1:
		prop = path[0]
		target = t


func get_value():
	assert(target)
	if callable_str:
		var callable = Callable(root, callable_str)
		return callable.call()
	assert(prop in target, "%s not found in %s" % [prop, target])
	return target.get(prop)


func set_value(value):
	assert(target)
	target.set(prop, value)
