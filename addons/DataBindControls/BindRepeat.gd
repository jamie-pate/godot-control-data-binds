tool
class_name BindRepeat, "./icons/links.svg"
extends Node

const Util := preload("./Util.gd")
const BindTarget := preload("./BindTarget.gd")
const ArrayModel := preload("./ArrayModel.gd")
const DataModel := preload("./DataModel.gd")
const MutationEvent := preload("./MutationEvent.gd")

export var array_bind: String setget _set_array_bind
export var target_property: String setget _set_target_property

var _template: Control = null
var _template_connections := []
var _owner = null


func _ready():
	if Engine.editor_hint:
		return
	call_deferred("_deferred_ready")


func _deferred_ready():
	_template = get_parent()
	var sigs_handled = {}
	for sig in _template.get_signal_list():
		for sc in _template.get_signal_connection_list(sig.name):
			if sc.target == _template.owner && sc.flags & CONNECT_PERSIST:
				sc.erase("source")
				sc.erase("target")
				_template_connections.append(sc)

	# we have to finish the _ready() callback _before_ we can do any of this
	var tparent = _template.get_parent()
	# preserve owner because remove_child() will delete it.
	# _enter_tree() will use this value to reset the owner
	_owner = owner
	_template.remove_child(self)
	tparent.add_child_below_node(_template, self)
	tparent.remove_child(_template)

	if array_bind && target_property:
		var bt = BindTarget.new(array_bind, owner)
		var value = bt.get_value() as ArrayModel
		if value:
			_on_model_mutated(MutationEvent.new(value, -1, false))


func _set_array_bind(value: String) -> void:
	assert(Engine.editor_hint || !is_inside_tree())
	array_bind = value


func _set_target_property(value: String) -> void:
	assert(Engine.editor_hint || !is_inside_tree())
	target_property = value


func _on_model_mutated(event: MutationEvent):
	if Engine.editor_hint:
		return
	var array_model = event.get_model()
	if !_template:
		return
	var p := get_parent()
	var size = array_model.size()
	# the repeat node should always be last, and every other node should be
	# a repeated template instance
	if event.removed && p.get_child_count() - 1 > event.index:
		p.remove_child(p.get_child(event.index))
	while size > p.get_child_count() - 1:
		var instance = _template.duplicate(DUPLICATE_USE_INSTANCING)
		p.add_child(instance)
		for sc in _template_connections:
			var err = instance.connect(sc.signal, owner, sc.method, sc.binds, sc.flags)
			assert(err == OK)
	raise()
	while size < p.get_child_count() - 1:
		var c := p.get_child(get_child_count() - 2)
		assert(c is Control && c != self)
		p.remove_child(c)
		c.queue_free()
	assert(event.index == -1 || event.removed || event.index < p.get_child_count() - 1)

	if !event.removed:
		if event.index < 0:
			for i in range(array_model.size()):
				_assign_item(p.get_child(i), array_model.get_at(i))
		else:
			_assign_item(p.get_child(event.index), array_model.get_at(event.index))


func _assign_item(child, item):
	if array_bind && target_property in child:
		var dm = child[target_property] as DataModel
		if typeof(child[target_property]) != typeof(item) || child[target_property] != item:
			child[target_property] = item
		if dm && item is DataModel && dm != item:
			item.copy_signals_from_and_emit_changes(dm)


func _notification(what):
	if what == NOTIFICATION_PREDELETE:
		if _template:
			_template.queue_free()
			_template = null


func _enter_tree():
	if Engine.editor_hint:
		return
	if !owner && _owner:
		owner = _owner
		_owner = null
		assert(owner)
	if array_bind && owner && _template:
		print(owner)
		var bt = BindTarget.new(array_bind, owner)
		var am := bt.get_value() as ArrayModel
		if am:
			var err := am.connect("mutated", self, "_on_model_mutated")
			assert(err == OK)


func _exit_tree():
	if Engine.editor_hint:
		return
	if array_bind:
		var bt = BindTarget.new(array_bind, owner)
		var am := bt.get_value() as ArrayModel
		if am:
			am.disconnect("mutated", self, "_on_model_mutated")
