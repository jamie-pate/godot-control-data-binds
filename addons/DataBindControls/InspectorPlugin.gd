extends EditorInspectorPlugin

const BindEditor := preload("./BindEditor.gd")
const Binds := preload("./Binds.gd")


func can_handle(object: Object):
	return object is Binds


func parse_property(
	_object: Object, type: int, path: String, _hint: int, hint_text: String, _usage: int
) -> bool:
	if type == TYPE_STRING and hint_text == "BoundProperty":
		print("parse_property %s %s %s" % [type, path, hint_text])
		add_property_editor(path, BindEditor.new())
		return true
	return false
