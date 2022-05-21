tool
extends Panel

signal remove(model)

const DataModel := preload("res://addons/DataBindControls/DataModel.gd")
const ArrayModel := preload("res://addons/DataBindControls/ArrayModel.gd")

var model := DataModel.new({text = "root1", pressed = false, array = ArrayModel.new([])})

var _next_id = 0


func _ready():
	var a: ArrayModel = model.array
	model.path = str(get_path())
	a.append(DataModel.new({text = "repeat0", pressed = false}))
	a.append(DataModel.new({text = "repeat1", pressed = true}))
	_next_id = 2
	print(a.get_i(0))

	var err := model.connect("mutated", self, "_on_model_mutated")
	assert(err == OK)
	err = model.connect("deep_mutated", self, "_on_model_mutated")
	$VBoxContainer/TextEdit.text = _yaml(model)


func _on_model_mutated(e):
	$VBoxContainer/TextEdit.text = "event: %s\n%s" % [e, _yaml(e.get_model())]


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
	model.array.append(DataModel.new({text = "repeat%s" % [_next_id], pressed = false}))
	_next_id += 1
