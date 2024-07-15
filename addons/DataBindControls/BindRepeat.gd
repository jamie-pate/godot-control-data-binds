@tool
@icon("./icons/links.svg")
class_name BindRepeat
extends Node

## Bind items in an array to be repeated using the parent template.
## Each array item will instance the template once in the grandparent control.

const Util := preload("./Util.gd")
const BindTarget := preload("./BindTarget.gd")

@export var array_bind: String:
	set = _set_array_bind
@export var target_property: String:
	set = _set_target_property

var _template: Control = null
var _template_connections := []
var _owner
var _detected_change_log := []


func _init():
	add_to_group(Util.BIND_GROUP)


func _ready():
	if Engine.is_editor_hint():
		return
	call_deferred("_deferred_ready")


func _deferred_ready():
	_template = get_parent()
	var sigs_handled = {}
	for sig in _template.get_signal_list():
		for sc in _template.get_signal_connection_list(sig.name):
			var c = sc.callable as Callable
			if c.get_object() == _template.owner && sc.flags & CONNECT_PERSIST:
				sc.signal_name = sc.signal.get_name()
				sc.method = c.get_method()
				sc.binds = c.get_bound_arguments()
				_template_connections.append(sc)
				# try to erase any possible node/object references
				sc.erase("callable")
				sc.erase("signal")

	# we have to finish the _ready() callback _before_ we can do any of this
	var tparent = _template.get_parent()
	# preserve owner because remove_child() will delete it.
	# _enter_tree() will use this value to reset the owner
	_owner = owner
	_template.remove_child(self)
	tparent.add_child(self, false, Node.INTERNAL_MODE_BACK)
	tparent.remove_child(_template)
	var value = _get_value(true)
	if value != null:
		detect_changes(value)


func _get_value(silent := false):
	if array_bind && target_property:
		var bt = BindTarget.new(array_bind, owner, silent)
		var path := Array(array_bind.split("."))
		var last_elem: String = path[len(path) - 1]
		var callable_present = last_elem.ends_with("()")

		if callable_present:
			bt = BindTarget.new(
				array_bind.replace("." + last_elem, ""),
				owner,
				silent,
				last_elem.replace("()", "") if callable_present else ""
			)
		return bt.get_value() if bt.target else null
	return null


func _set_array_bind(value: String) -> void:
	assert(Engine.is_editor_hint() || !is_inside_tree())
	array_bind = value


func _set_target_property(value: String) -> void:
	assert(Engine.is_editor_hint() || !is_inside_tree())
	target_property = value


func detect_changes(new_value: Array = []) -> bool:
	_detected_change_log = []
	# TODO: track moved items instead of reassigning every time
	if !_template:
		return false
	if len(new_value) == 0:
		var v = _get_value()
		new_value = v if v != null else []
	var p := get_parent()
	var size = len(new_value)
	# the repeat node should always be last, and every other node should be
	# a repeated template instance
	var change_detected = size != p.get_child_count()
	while size > p.get_child_count():
		var instance = _template.duplicate(DUPLICATE_USE_INSTANTIATION)
		p.add_child(instance)
		for sc in _template_connections:
			var err = instance.connect(
				sc.signal_name, Callable(owner, sc.method).bindv(sc.binds), sc.flags
			)
			assert(err == OK)
	while size < p.get_child_count():
		var c := p.get_child(p.get_child_count() - 1)
		assert(c is Control && c != self)
		p.remove_child(c)
		c.queue_free()
	for i in range(size):
		change_detected = _assign_item(p.get_child(i), new_value[i], i) || change_detected
	return change_detected


func _assign_item(child, item, i):
	if array_bind && target_property in child:
		var m = child[target_property]
		var current_value = child[target_property]
		if typeof(current_value) != typeof(item) || current_value != item:
			_detected_change_log.append("[%s].%s: %s != %s" % [i, current_value, item])
			child[target_property] = item


func _notification(what):
	if what == NOTIFICATION_PREDELETE:
		if _template:
			_template.queue_free()
			_template = null


func _enter_tree():
	if Engine.is_editor_hint():
		return
	if !owner && _owner:
		owner = _owner
		_owner = null
		assert(owner)


func get_desc():
	return "%s: Repeat" % [get_path(), "\n".join(_detected_change_log)]
