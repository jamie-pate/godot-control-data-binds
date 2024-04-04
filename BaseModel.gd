## A base model that facilitates an automatic init to make it easy to call `.new()`
## You can use any classes you like or even a dictionary if you are lazy.
extends Reference

var _keys := []


func keys():
	return _keys.duplicate()


func _init(initial_values = {}):
	for p in initial_values:
		assert(p in self, "%s is not a property of %s" % [p, self])
		_keys.append(p)
		self[p] = initial_values[p]
