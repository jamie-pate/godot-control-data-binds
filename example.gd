extends Panel

const ExampleItem = preload("./example_item.gd")

var text = "root1"
var array: Array[ExampleItem]
var time = "0"
var path = ""
var model_yaml := ""
var pressed := false

var _next_id = 0


# Sample callable that returns only item models with an even value
func filtered_array():
	var sub_array: Array[ExampleItem] = array.filter(func(n): return n.value % 2 == 0)
	return sub_array


func _ready():
	path = str(get_path())
	array.append(
		ExampleItem.new({text = "repeat0", pressed = false, icon = _get_icon(0), value = 1})
	)
	array.append(
		ExampleItem.new({text = "repeat1", pressed = true, icon = _get_icon(1), value = 0})
	)
	array.append(
		ExampleItem.new({text = "repeat2", pressed = true, icon = _get_icon(1), value = 0})
	)
	_next_id = 2
	print("model.array[0] = %s : %s" % [get_path(), array[0]])


func _get_icon(i: int):
	var icons = [
		preload("res://addons/DataBindControls/icons/link.svg"),
		preload("res://addons/DataBindControls/icons/links.svg"),
		preload("res://addons/DataBindControls/icons/list.svg")
	]
	return icons[i % len(icons)]


func _yaml(obj, indent := "", indent_first := false) -> String:
	var result := PackedStringArray()
	if obj is ExampleItem or obj is Dictionary:
		var first = true
		for k in obj.keys():
			result.append(
				(
					"%s%s: %s"
					% [
						indent if !first || indent_first else "",
						k,
						_yaml(obj[k], indent + "  ", false)
					]
				)
			)
			first = false
	elif obj is Array:
		if !indent_first:
			result.append("")
		for item in obj:
			result.append("%s- %s" % [indent, _yaml(item, indent + "  ", false)])
	else:
		return "%s%s" % [indent if indent_first else "", obj]
	return "\n".join(result)


func _on_RepeatPanel_remove(value):
	array.erase(value)


func _on_AddButton_pressed():
	array.append(
		ExampleItem.new(
			{text = "repeat%s" % [_next_id], pressed = false, icon = _get_icon(_next_id)}
		)
	)
	_next_id += 1


func _on_Timer_timeout():
	## this is an example of when you need to call change detection.
	## Ideally we would be able to hook into some of these at the engine level
	## to automatically call detect_changes whenever a timeout or other async
	## action happens similar to NgZone
	time = str(Time.get_ticks_msec())
	DataBindings.detect_changes()


func _process(_delta: float):
	var new_value = _yaml({text = text, time = time, path = path, array = array})
	# we don't want to flood change detection
	if model_yaml != new_value:
		model_yaml = new_value
		DataBindings.detect_changes()
