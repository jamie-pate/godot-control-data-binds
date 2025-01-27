@tool
@icon("./icons/links.svg")
class_name BindRepeat
extends Node

## Bind items in an array to be repeated using the parent template.
## Each array item will instance the template once in the grandparent control.

const Util := preload("./util.gd")
const BindTarget := preload("./bind_target.gd")

@export var array_bind: String:
	set = _set_array_bind
@export var target_property: String:
	set = _set_target_property

var _template: Control = null
var _template_connections := []
var _owner
var _detected_change_log := []
var _bound_array: BindTarget


func _ready():
	if Engine.is_editor_hint():
		return
	call_deferred("_deferred_ready")
	_bound_array = BindTarget.new(array_bind, owner)


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
	var value = _get_array_value()
	if value != null:
		detect_changes(value)


func _get_array_value():
	if array_bind && target_property:
		var target = _bound_array.get_target()
		return _bound_array.get_value(target) if target else null
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
		var v = _get_array_value()
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


func _assign_item(child, item, i) -> bool:
	var result := false
	if array_bind && target_property in child:
		var m = child[target_property]
		var current_value = child[target_property]
		if typeof(current_value) != typeof(item) || current_value != item:
			result = true
			_detected_change_log.append(
				"[%s].%s: %s != %s" % [i, target_property, current_value, item]
			)
			child[target_property] = item
	return result


func _notification(what):
	if what == NOTIFICATION_PREDELETE:
		if _template:
			_template.queue_free()
			_template = null


func _parent_visibility_changed():
	DataBindings.update_bind_visibility(self)


func _enter_tree():
	if Engine.is_editor_hint():
		return
	if !owner && _owner:
		owner = _owner
		_owner = null
		assert(owner)
	DataBindings.add_bind(self)
	var p := get_parent()
	if p && p.has_signal("visibility_changed"):
		p.visibility_changed.connect(_parent_visibility_changed)


func _exit_tree():
	if Engine.is_editor_hint():
		return
	DataBindings.remove_bind(self)
	var p := get_parent()
	if p && p.has_signal("visibility_changed"):
		p.visibility_changed.disconnect(_parent_visibility_changed)


func change_count():
	return len(_detected_change_log)


func get_desc():
	return "%s: Repeat\n%s" % [get_path(), "\n".join(_detected_change_log)]
