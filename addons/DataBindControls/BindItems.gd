@tool
@icon("./icons/list.svg")
class_name BindItems
extends Binds

## Bind items in an array to items in an ItemList, PopupMenu, OptionButton etc

@export var array_bind: String:
	set = _set_array_bind
@export var item_text: String:
	set = _set_item_text
@export var item_icon: String:
	set = _set_item_icon
@export var item_disabled: String:
	set = _set_item_disabled
@export var item_selectable: String:
	set = _set_item_selectable
@export var item_tooltip: String:
	set = _set_item_tooltip
@export var item_selected: String:
	set = _set_item_selected


func _get_property_list():
	var pl = _binds_get_property_list()
	return pl


func _set_array_bind(value: String) -> void:
	# need to call _bind_items() if we modify the binding at runtime
	assert(Engine.is_editor_hint() || !is_inside_tree())
	array_bind = value


func _set_item_text(value: String) -> void:
	assert(Engine.is_editor_hint() || !is_inside_tree())
	item_text = value


func _set_item_icon(value: String) -> void:
	assert(Engine.is_editor_hint() || !is_inside_tree())
	item_icon = value


func _set_item_disabled(value: String) -> void:
	assert(Engine.is_editor_hint() || !is_inside_tree())
	item_disabled = value


func _set_item_selectable(value: String) -> void:
	assert(Engine.is_editor_hint() || !is_inside_tree())
	item_selectable = value


func _set_item_tooltip(value: String) -> void:
	assert(Engine.is_editor_hint() || !is_inside_tree())
	item_tooltip = value


func _set_item_selected(value: String) -> void:
	assert(Engine.is_editor_hint() || !is_inside_tree())
	item_selected = value


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var value = _get_value()
	if value:
		detect_changes(value)


func _get_value():
	var bt = BindTarget.new(array_bind, owner)
	return bt.get_value()


func detect_changes(new_value := []) -> bool:
	if len(new_value) == 0:
		var v = _get_value()
		new_value = v if v != null else []
	var size = len(new_value)
	var p = get_parent()
	# TODO: maybe just check for has_method(`get_item_*`)?
	assert(p is ItemList || p is PopupMenu || p is OptionButton)

	while size > p.get_item_count():
		p.add_item("")
	while size < p.get_item_count():
		p.remove_item(p.get_item_count() - 1)

	# Todo: track items so we don't have to assign the entire array
	var change_detected = false
	for i in range(size):
		change_detected = _assign_item(p, i, new_value[i]) || change_detected
	return change_detected


func _on_parent_item_selected(_idx: int) -> void:
	var bt = BindTarget.new(array_bind, owner)
	var array_model = bt.get_value() if bt else null
	var parent = get_parent()
	var selected = PackedByteArray()
	selected.resize(parent.get_item_count())
	for i in parent.get_selected_items():
		selected[i] = 1
	if array_model && item_selected:
		for i in range(parent.get_item_count()):
			var model = array_model[i]
			var value = selected[i] == 1
			if model[item_selected] != value:
				model[item_selected] = value


func _on_parent_multi_selected(idx: int, _selected: bool) -> void:
	_on_parent_item_selected(idx)


func _assign_item(parent: Node, i: int, item) -> bool:
	var change_detected := false
	var pl = get_script().get_script_property_list()
	for p in pl:
		if p.name.begins_with("item_"):
			var set_method_name := "set_%s" % [p.name]
			var get_method_name := "get_%s" % [p.name]
			if p.name == "item_selected":
				# this property follows a different pattern and is only available
				# on ItemList
				set_method_name = "select"
				get_method_name = "is_selected"

			var model_prop = self[p.name]
			if model_prop && parent.has_method(get_method_name) && model_prop in item:
				var new_value = item[model_prop]
				var update := true
				if parent.has_method(set_method_name):
					var old_value = parent.call(get_method_name, i)
					update = typeof(old_value) != typeof(new_value) || old_value != new_value
					change_detected = change_detected || update
				if update:
					if set_method_name == "select":
						if new_value:
							# singleselect = false
							parent.select(i, false)
						else:
							parent.deselect(i)
					else:
						parent.call(set_method_name, i, new_value)
	return change_detected


func _enter_tree():
	_bind_parent()


func _exit_tree():
	_unbind_parent()


func _bind_parent():
	var parent = get_parent()
	var err = parent.connect("multi_selected", Callable(self, "_on_parent_multi_selected"))
	assert(err == OK)
	err = parent.connect("item_selected", Callable(self, "_on_parent_item_selected"))
	assert(err == OK)


func _unbind_parent():
	var parent = get_parent()
	parent.disconnect("multi_selected", Callable(self, "_on_parent_multi_selected"))
	parent.disconnect("item_selected", Callable(self, "_on_parent_item_selected"))
