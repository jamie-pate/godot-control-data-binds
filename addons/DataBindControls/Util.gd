extends Reference

const MODEL_SIGNALS := ["mutated", "deep_mutated"]
const Classes = preload("./Classes.gd")
const CLASSES = {}


static func get_sig_map(obj) -> Dictionary:
	var sig_map := {}
	for s in obj.get_signal_list():
		sig_map[s.name] = s
	return sig_map


static func classes():
	if len(CLASSES) == 0:
		# static function, but we can't load other relative script paths in the static function
		# because static functions don't know their own script path..
		Classes.new(CLASSES)
	return CLASSES


static func is_model(obj):
	if obj is Object:
		for c in classes().values():
			if obj is c:
				return true
	return false
