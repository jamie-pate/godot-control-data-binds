extends EditorInspectorPlugin

const BindEditor := preload("./bind_editor.gd")
const Binds := preload("./binds.gd")


func can_handle(object: Object):
	return object is Binds


func parse_property(
	_object: Object, type: int, path: String, _hint: int, hint_text: String, _usage: int
) -> bool:
	if type == TYPE_STRING && hint_text in ["BoundProperty", "BoundPropertyReadonly"]:
		print("parse_property %s %s %s" % [type, path, hint_text])
		add_property_editor(path, BindEditor.new())
		return true
	return false
