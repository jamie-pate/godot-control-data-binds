@tool
@icon("./icons/list.svg")
class_name BindItems
extends Binds

## Bind items in an array to items in an ItemList, PopupMenu, OptionButton etc

@export_category("Owner Binds")

## → Path to array of objects, relative to owner.
## One object represents one item
## Use item_* binds to bind each item's text, icon, etc to each object's property
@export var array_bind: String:
	set = _set_array_bind

## ↔ Bind the currently selected item's object to this property on owner
@export var selected_item: String:
	set = _set_selected_item

@export_category("Item Binds")

## → Bind this property to the item's text
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
## ← Set this property on the selected item to true/false when selected
# TODO: ↔ binding?
@export var item_selected: String:
	set = _set_item_selected

var _script_property_list: Array[Dictionary] = get_script().get_script_property_list().filter(
	func(p): return p.name.begins_with("item_")
)
var _bound_array: BindTarget
var _bound_selected_item: BindTarget
var _bound_item_props: Dictionary


func _get_configuration_warnings() -> PackedStringArray:
	var result: PackedStringArray
	if selected_item && "selected" in _binds && _binds.selected:
		result.append("The binds for selected and selected_item conflict.\nOnly use one of them.")
	return result


func _get_property_list():
	var pl = _binds_get_property_list()
	return pl


func _set_array_bind(value: String) -> void:
	# need to call _bind_items() if we modify the binding at runtime
	assert(Engine.is_editor_hint() || !is_inside_tree())
	array_bind = value


func _set_selected_item(value: String) -> void:
	assert(Engine.is_editor_hint() || !is_inside_tree())
	update_configuration_warnings()
	selected_item = value


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
	_bound_array = BindTarget.new(array_bind, owner)
	_bound_selected_item = BindTarget.new(selected_item, owner)
	for p in _script_property_list:
		var bind_expr = self[p.name]
		if bind_expr:
			var bt := BindTarget.new(bind_expr, null)
			_bound_item_props[bind_expr] = bt
	var value = _get_array_value()
	if value:
		detect_changes(value)


func _get_items_target():
	## target can be the parent, but if it's a MenuButton or something similar
	## try the `get_popup()` method to get the 'real' target
	var parent := get_parent()
	if parent is OptionButton:
		return parent
	return parent.get_popup() if parent.has_method("get_popup") else parent


func _get_array_value():
	var target = _bound_array.get_target()
	return _bound_array.get_value(target) if target else []


func detect_changes(new_array := []) -> bool:
	var change_log := []
	if len(new_array) == 0:
		var v = _get_array_value()
		new_array = v if v != null else []
	var size = len(new_array)
	var it = _get_items_target()
	# TODO: maybe just check for has_method(`get_item_*`)?
	assert(it is ItemList || it is PopupMenu || it is OptionButton)
	# Todo: track items so we don't have to assign the entire array
	var change_detected = false

	while size > it.get_item_count():
		change_detected = true
		it.add_item("")
	while size < it.get_item_count():
		change_detected = true
		it.remove_item(it.get_item_count() - 1)

	for i in range(size):
		change_detected = _assign_item(it, i, new_array[i]) || change_detected
	var parent = get_parent()
	if selected_item && "selected" in parent:
		var bt := _bound_selected_item
		var target = bt.get_target()
		if target:
			var item = new_array[parent.selected] if parent.selected >= 0 else null
			var model_item = bt.get_value(target)
			if !_equal_approx(model_item, item):
				var idx = new_array.find(model_item)
				parent.selected = idx
				var new_item = new_array[idx] if idx >= 0 else null
				bt.set_value(target, new_item)
				model_item = bt.get_value(target)
				if _equal_approx(new_item, model_item):
					change_detected = true
					change_log.append("%s: %s != %s" % [bt.full_path, model_item, item])
				else:
					printerr(
						(
							"WARNING: %s.selected_item %s: %s != %s (could not be assigned?)"
							% [get_path(), bt.full_path, model_item, new_item]
						)
					)
	change_detected = change_detected || super()
	_detected_change_log.append_array(change_log)
	return change_detected


func _on_item_selected(_idx: int) -> void:
	var bt := _bound_array
	var target = bt.get_target()
	var array_model = bt.get_value(target) if bt && target else null
	var items_target = _get_items_target()
	var selected = PackedByteArray()
	selected.resize(items_target.get_item_count())
	if items_target.has_method("get_selected_items"):
		for i in items_target.get_selected_items():
			selected[i] = 1
	else:
		for i in len(selected):
			selected[i] = 1 if _idx == i else 0
	if array_model && item_selected:
		for i in range(items_target.get_item_count()):
			var model = array_model[i]
			var value = selected[i] == 1
			if model[item_selected] != value:
				model[item_selected] = value
	# Fake selected_changed signal
	if "selected" in get_parent() && "selected" in _binds && _binds.selected:
		_on_parent_prop_changed0("selected")
	if selected_item:
		bt = BindTarget.new(selected_item, owner)
		bt.set_value(target, array_model[_idx])
	DataBindings.detect_changes()


func _on_multi_selected(idx: int, _selected: bool) -> void:
	_on_item_selected(idx)


func _assign_item(items_target: Node, i: int, item) -> bool:
	var change_detected := false
	var pl = _script_property_list
	for p in pl:
		var set_method_name := "set_%s" % [p.name]
		var get_method_name := "get_%s" % [p.name]
		if p.name == "item_selected":
			# this property follows a different pattern and is only available
			# on ItemList
			set_method_name = "select"
			get_method_name = "is_selected"

		var bind_expr = self[p.name]
		var bt = _bound_item_props[bind_expr] if bind_expr else null
		var target = bt.get_target(item) if bt else null
		if bt && target && items_target.has_method(get_method_name):
			var new_value = bt.get_value(target)
			var update := true
			if items_target.has_method(set_method_name):
				var old_value = items_target.call(get_method_name, i)
				update = typeof(old_value) != typeof(new_value) || old_value != new_value
				change_detected = change_detected || update
				if update:
					_detected_change_log.append(
						"[%s].%s(): %s != %s" % [i, set_method_name, old_value, new_value]
					)
			if update:
				if set_method_name == "select":
					if new_value:
						# singleselect = false
						items_target.select(i, false)
					else:
						items_target.deselect(i)
				else:
					items_target.call(set_method_name, i, new_value)
	return change_detected


func _enter_tree():
	if Engine.is_editor_hint():
		return
	super._enter_tree()
	_bind_item_control()


func _exit_tree():
	if Engine.is_editor_hint():
		return
	super._enter_tree()
	_unbind_item_control()


func _bind_item_control():
	var items_target = _get_items_target()
	if items_target.has_signal("multi_selected"):
		var err = items_target.multi_selected.connect(_on_multi_selected)
		assert(err == OK)
	if items_target.has_signal("item_selected"):
		var err = items_target.item_selected.connect(_on_item_selected)
		assert(err == OK)
	elif items_target.has_signal("index_pressed"):
		# PopupMenu
		var err = items_target.index_pressed.connect(_on_item_selected)
		assert(err == OK)


func _unbind_item_control():
	var items_target = _get_items_target()
	if items_target.has_signal("multi_selected"):
		items_target.multi_selected.disconnect(_on_multi_selected)
	if items_target.has_signal("item_selected"):
		items_target.item_selected.disconnect(_on_item_selected)
	elif items_target.has_signal("index_pressed"):
		items_target.index_pressed.disconnect(_on_item_selected)


func get_desc():
	return "%s: Items\n%s" % [get_path(), "\n".join(_detected_change_log)]
