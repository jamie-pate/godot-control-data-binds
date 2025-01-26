extends RefCounted

var full_path: String
var root
var prop := ""
var method_name := ""

var _path: Array[String]
var _silent: bool


## Create a BindTarget for the selected path and root
## Root may be null, in which case it must be passed when calling get_target()
func _init(path: String, _root, silent := false):
	full_path = path
	root = _root
	_silent = silent
	_path.assign(path.split("."))
	if len(_path) >= 1:
		var last := _path.back()
		if last.ends_with("()"):
			method_name = last.trim_suffix("()")
		else:
			prop = last


## Get the target relative to the root object.
## if this BindTarget has no root you must provide one here.
func get_target(target_root = null):
	var t = root
	if root == null:
		assert(target_root)
		t = target_root
	for i in range(len(_path) - 1):
		var p = _path[i]
		if t != null && t is Object && p in t:
			t = t[p]
		else:
			if !_silent:
				printerr(
					(
						"Unable to find bind %s on %s"
						% [full_path, root.get_path() if root is Node else root]
					)
				)
			break
	return t


## call get_target() first to get the target and pass it in
func get_value(target):
	assert(target)
	if method_name:
		var callable = Callable(target, method_name)
		return callable.call()
	assert(prop in target, "%s not found in %s (%s)" % [prop, target, full_path])
	return target.get(prop)


func set_value(target, value):
	assert(target && prop)
	target.set(prop, value)
