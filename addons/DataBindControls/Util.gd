extends RefCounted

const BIND_GROUP = "__DataBindingBind__"


static func get_sig_map(obj) -> Dictionary:
	var sig_map := {}
	for s in obj.get_signal_list():
		sig_map[s.name] = s
	return sig_map
