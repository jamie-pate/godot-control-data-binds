tool
class_name BindItems, "./icons/list.svg"
extends Binds

const ArrayModel := preload("./ArrayModel.gd")
const MutationEvent := preload("./MutationEvent.gd")
const DeepMutationEvent := preload("./DeepMutationEvent.gd")

export var array_bind: String setget _set_array_bind
export var item_text: String setget _set_item_text
export var item_icon: String setget _set_item_icon
export var item_disabled: String setget _set_item_disabled
export var item_selectable: String setget _set_item_selectable
export var item_tooltip: String setget _set_item_tooltip
export var item_selected: String setget _set_item_selected


func _get_property_list():
	var pl = _binds_get_property_list()
	return pl


func _set_array_bind(value: String) -> void:
	# need to call _bind_items() if we modify the binding at runtime
	assert(Engine.editor_hint || !is_inside_tree())
	array_bind = value


func _set_item_text(value: String) -> void:
	assert(Engine.editor_hint || !is_inside_tree())
	item_text = value


func _set_item_icon(value: String) -> void:
	assert(Engine.editor_hint || !is_inside_tree())
	item_icon = value


func _set_item_disabled(value: String) -> void:
	assert(Engine.editor_hint || !is_inside_tree())
	item_disabled = value


func _set_item_selectable(value: String) -> void:
	assert(Engine.editor_hint || !is_inside_tree())
	item_selectable = value


func _set_item_tooltip(value: String) -> void:
	assert(Engine.editor_hint || !is_inside_tree())
	item_tooltip = value


func _set_item_selected(value: String) -> void:
	assert(Engine.editor_hint || !is_inside_tree())
	item_selected = value


func _ready() -> void:
	if Engine.editor_hint:
		return
	var bt = BindTarget.new(array_bind, owner)
	var value = bt.get_value() as ArrayModel
	if value:
		_on_model_mutated(MutationEvent.new(value, -1, false))


func _on_model_mutated(event: MutationEvent) -> void:
	if Engine.editor_hint:
		return
	var array_model = event.get_model()
	assert(array_model is ArrayModel)
	var size = array_model.size()
	var p = get_parent()
	# TODO: maybe just check for has_method(`get_item_*`)?
	assert(p is ItemList || p is PopupMenu || p is OptionButton)
	# the repeat node should always be last, and every other node should be
	# a repeated template instance
	if event.removed && p.get_item_count() > event.index:
		p.remove_item(event.index)
	while size > p.get_item_count():
		p.add_item("")
	while size < p.get_item_count():
		p.remove_item(p.get_item_count() - 1)
	assert(event.index == -1 || event.removed || event.index < p.get_item_count())

	if !event.removed:
		if event.index < 0:
			for i in range(array_model.size()):
				_assign_item(p, i, array_model.get_at(i))
		else:
			_assign_item(p, event.index, array_model.get_at(event.index))


func _on_model_deep_mutated(event: DeepMutationEvent):
	if len(event.path) != 2 || !event.path[0] is int || !event.path[1] is String:
		return
	var idx = event.path[0]
	var item_prop = event.path[1]
	var bt = BindTarget.new(array_bind, owner)
	var array_model = bt.get_value() if bt else null
	if !array_model:
		return
	var parent = get_parent()
	for p in get_script().get_script_property_list():
		var bind_prop = self[p.name] if p.name.begins_with("item_") else ""
		if p.name.begins_with("item_") && bind_prop && bind_prop == item_prop:
			var value = array_model.get_at(event.path[0])[item_prop]
			if p.name == "item_selected":
				if value:
					parent.select(idx, parent.select_mode == parent.SELECT_SINGLE)
				else:
					parent.unselect(idx)
			else:
				var method_name = "set_%s" % [p.name]
				if parent.has_method(method_name):
					parent.call(method_name, idx, array_model.get_at(idx)[item_prop])
			break


func _on_parent_item_selected(idx: int) -> void:
	var bt = BindTarget.new(array_bind, owner)
	var array_model = bt.get_value() if bt else null
	var parent = get_parent()
	var selected = PoolByteArray()
	selected.resize(parent.get_item_count())
	for i in parent.get_selected_items():
		selected[i] = 1
	if array_model && item_selected:
		for i in range(parent.get_item_count()):
			var model = array_model.get_at(i)
			var value = selected[i] == 1
			if model[item_selected] != value:
				model[item_selected] = value


func _on_parent_multi_selected(idx: int, selected: bool) -> void:
	_on_parent_item_selected(idx)


func _assign_item(parent: Node, i: int, item) -> void:
	var pl = get_script().get_script_property_list()
	for p in pl:
		if p.name.begins_with("item_"):
			var method_name = "set_%s" % [p.name]
			var model_prop = self[p.name]
			if model_prop && parent.has_method(method_name) && model_prop in item:
				parent.call(method_name, i, item[model_prop])


func _enter_tree():
	_bind_items()
	_bind_parent()


func _exit_tree():
	_unbind_items()
	_unbind_parent()


func _bind_parent():
	var parent = get_parent()
	var err = parent.connect("multi_selected", self, "_on_parent_multi_selected")
	assert(err == OK)
	err = parent.connect("item_selected", self, "_on_parent_item_selected")
	assert(err == OK)


func _unbind_parent():
	var parent = get_parent()
	parent.disconnect("multi_selected", self, "_on_parent_multi_selected")
	parent.disconnect("item_selected", self, "_on_parent_item_selected")


func _bind_items():
	if !array_bind:
		return
	var bt = BindTarget.new(array_bind, owner)
	var array_model = bt.get_value() if bt else null
	if array_model:
		if array_model.has_signal("deep_mutated"):
			var err = array_model.connect("deep_mutated", self, "_on_model_deep_mutated")
			assert(err == OK)
		if array_model.has_signal("mutated"):
			var err = array_model.connect("mutated", self, "_on_model_mutated")
			assert(err == OK)


func _unbind_items():
	var bt = BindTarget.new(array_bind, owner)
	var array_model = bt.get_value() if bt else null
	if array_model:
		if array_model.has_signal("deep_mutated"):
			array_model.disconnect("deep_mutated", self, "_on_model_deep_mutated")
		if array_model.has_signal("mutated"):
			array_model.disconnect("mutated", self, "_on_model_mutated")
