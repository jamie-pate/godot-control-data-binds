tool
extends Panel

signal remove(model)

const DataModel := preload("res://addons/DataBindControls/DataModel.gd")
const ArrayModel := preload("res://addons/DataBindControls/ArrayModel.gd")

var model := DataModel.new({text = "root1", pressed = false, array = ArrayModel.new([])})
var model_yaml := DataModel.new({value = ""})

var _next_id = 0


func _ready():
	var a: ArrayModel = model.array
	model.path = str(get_path())
	a.append(DataModel.new({text = "repeat0", pressed = false, icon = _get_icon(0)}))
	a.append(DataModel.new({text = "repeat1", pressed = true, icon = _get_icon(1)}))
	_next_id = 2
	print(a.get_at(0))

	var err := model.connect("mutated", self, "_on_model_mutated")
	assert(err == OK)
	err = model.connect("deep_mutated", self, "_on_model_mutated")
	model_yaml.value = _yaml(model)


func _get_icon(i: int):
	var icons = [
		preload("res://addons/DataBindControls/icons/link.svg"),
		preload("res://addons/DataBindControls/icons/links.svg"),
		preload("res://addons/DataBindControls/icons/list.svg")
	]
	return icons[i % len(icons)]


func _on_model_mutated(e):
	model_yaml.value = "event: %s\n%s" % [e, _yaml(e.get_model())]


func _yaml(model, indent := "", indent_first := false) -> String:
	var result := PoolStringArray()
	if model is DataModel:
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
	elif model is ArrayModel:
		if !indent_first:
			result.append("")
		for item in model.values():
			result.append("%s- %s" % [indent, _yaml(item, indent + "  ", false)])
	else:
		return "%s%s" % [indent if indent_first else "", model]
	return result.join("\n")


func _on_Button_pressed():
	emit_signal("remove", model)


func _on_RepeatPanel_remove(value):
	model.array.erase(value)


func _on_AddButton_pressed():
	model.array.append(
		DataModel.new({text = "repeat%s" % [_next_id], pressed = false, icon = _get_icon(_next_id)})
	)
	_next_id += 1
