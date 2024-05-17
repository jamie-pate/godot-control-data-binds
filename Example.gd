extends Panel

signal remove(model)

# Model classes here are named with the Model suffix but you could use any naming scheme
const BaseModel = preload("./BaseModel.gd")
const RootModel = preload("./RootModel.gd")
const ItemModel = preload("./ItemModel.gd")

var model = RootModel.new({text = "root1", pressed = false, array = [], time = "0", path = ""}):
	set = _set_model
var model_yaml := {value = ""}

var _next_id = 0


# Sample callable that returns only item models with an even value
func sample_callable():
	var sub_array = model.array.filter(func(n): return n.value % 2 == 0)
	return sub_array


func _ready():
	var a := model.array as Array
	model.path = str(get_path())
	a.append(ItemModel.new({text = "repeat0", pressed = false, icon = _get_icon(0), value = 1}))
	a.append(ItemModel.new({text = "repeat1", pressed = true, icon = _get_icon(1), value = 0}))
	a.append(ItemModel.new({text = "repeat2", pressed = true, icon = _get_icon(1), value = 0}))
	_next_id = 2
	print("model.array[0] = %s : %s" % [get_path(), a[0]])


func _set_model(value):
	model = value
	assert(model, "Model can't be null, invalid type assignment?")


func _get_icon(i: int):
	var icons = [
		preload("res://addons/DataBindControls/icons/link.svg"),
		preload("res://addons/DataBindControls/icons/links.svg"),
		preload("res://addons/DataBindControls/icons/list.svg")
	]
	return icons[i % len(icons)]


func _yaml(model, indent := "", indent_first := false) -> String:
	var result := PackedStringArray()
	if model is BaseModel:
		var first = true
		for k in model.keys():
			result.append(
				(
					"%s%s: %s"
					% [
						indent if !first || indent_first else "",
						k,
						_yaml(model[k], indent + "  ", false)
					]
				)
			)
			first = false
	elif model is Array:
		if !indent_first:
			result.append("")
		for item in model:
			result.append("%s- %s" % [indent, _yaml(item, indent + "  ", false)])
	else:
		return "%s%s" % [indent if indent_first else "", model]
	return "\n".join(result)


func _on_Button_pressed():
	emit_signal("remove", model)


func _on_RepeatPanel_remove(value):
	model.array.erase(value)


func _on_AddButton_pressed():
	model.array.append(
		ItemModel.new({text = "repeat%s" % [_next_id], pressed = false, icon = _get_icon(_next_id)})
	)
	_next_id += 1


func _on_Timer_timeout():
	## this is an example of when you need to call change detection.
	## Ideally we would be able to hook into some of these at the engine level
	## to automatically call detect_changes whenever a timeout or other async
	## action happens similar to NgZone
	model.time = str(Time.get_ticks_msec())
	DataBindings.detect_changes()


func _process(_delta: float):
	var new_value = _yaml(model)
	# we don't want to flood change detection
	if model_yaml.value != new_value:
		model_yaml.value = new_value
		DataBindings.detect_changes()
