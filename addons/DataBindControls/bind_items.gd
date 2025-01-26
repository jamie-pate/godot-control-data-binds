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
	var value = _get_value()
	if value:
		detect_changes(value)


func _get_target():
	## target can be the parent, but if it's a MenuButton or something similar
	## try the `get_popup()` method to get the 'real' target
	var parent := get_parent()
	if parent is OptionButton:
		return parent
	return parent.get_popup() if parent.has_method("get_popup") else parent


func _get_value(silent := false):
	var bt = BindTarget.new(array_bind, owner, silent)
	return bt.get_value()


func detect_changes(new_array := []) -> bool:
	var change_log := []
	if len(new_array) == 0:
		var v = _get_value()
		new_array = v if v != null else []
	var size = len(new_array)
	var t = _get_target()
	# TODO: maybe just check for has_method(`get_item_*`)?
	assert(t is ItemList || t is PopupMenu || t is OptionButton)
	# Todo: track items so we don't have to assign the entire array
	var change_detected = false

	while size > t.get_item_count():
		change_detected = true
		t.add_item("")
	while size < t.get_item_count():
		change_detected = true
		t.remove_item(t.get_item_count() - 1)

	for i in range(size):
		change_detected = _assign_item(t, i, new_array[i]) || change_detected
	var parent = get_parent()
	if selected_item && "selected" in parent:
		var bt := BindTarget.new(selected_item, owner)
		var item = new_array[parent.selected] if parent.selected >= 0 else null
		var model_item = bt.get_value()
		if !_equal_approx(model_item, item):
			var idx = new_array.find(model_item)
			parent.selected = idx
			var new_item = new_array[idx] if idx >= 0 else null
			bt.set_value(new_item)
			model_item = bt.get_value()
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
	var bt := BindTarget.new(array_bind, owner)
	var array_model = bt.get_value() if bt else null
	var target = _get_target()
	var selected = PackedByteArray()
	selected.resize(target.get_item_count())
	if target.has_method("get_selected_items"):
		for i in target.get_selected_items():
			selected[i] = 1
	else:
		for i in len(selected):
			selected[i] = 1 if _idx == i else 0
	if array_model && item_selected:
		for i in range(target.get_item_count()):
			var model = array_model[i]
			var value = selected[i] == 1
			if model[item_selected] != value:
				model[item_selected] = value
	# Fake selected_changed signal
	if "selected" in get_parent() && "selected" in _binds && _binds.selected:
		_on_parent_prop_changed0("selected")
	if selected_item:
		bt = BindTarget.new(selected_item, owner)
		bt.set_value(array_model[_idx])
	DataBindings.detect_changes()


func _on_multi_selected(idx: int, _selected: bool) -> void:
	_on_item_selected(idx)


func _assign_item(target: Node, i: int, item) -> bool:
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

		var bt := BindTarget.new(bind_expr, item) if bind_expr else null
		if bt && bt.target && target.has_method(get_method_name):
			var new_value = bt.get_value()
			var update := true
			if target.has_method(set_method_name):
				var old_value = target.call(get_method_name, i)
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
						target.select(i, false)
					else:
						target.deselect(i)
				else:
					target.call(set_method_name, i, new_value)
	return change_detected


func _enter_tree():
	_bind_item_control()


func _exit_tree():
	_unbind_item_control()


func _bind_item_control():
	var target = _get_target()
	if target.has_signal("multi_selected"):
		var err = target.multi_selected.connect(_on_multi_selected)
		assert(err == OK)
	if target.has_signal("item_selected"):
		var err = target.item_selected.connect(_on_item_selected)
		assert(err == OK)
	elif target.has_signal("index_pressed"):
		# PopupMenu
		var err = target.index_pressed.connect(_on_item_selected)
		assert(err == OK)


func _unbind_item_control():
	var target = _get_target()
	if target.has_signal("multi_selected"):
		target.multi_selected.disconnect(_on_multi_selected)
	if target.has_signal("item_selected"):
		target.item_selected.disconnect(_on_item_selected)
	elif target.has_signal("index_pressed"):
		target.index_pressed.disconnect(_on_item_selected)


func get_desc():
	return "%s: Items\n%s" % [get_path(), "\n".join(_detected_change_log)]
