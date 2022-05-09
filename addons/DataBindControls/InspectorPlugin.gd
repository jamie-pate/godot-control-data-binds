extends EditorInspectorPlugin

const BindEditor := preload('./BindEditor.gd')
const DataBinds := preload('./DataBinds.gd')

func can_handle(object: Object):
	return object is DataBinds


func parse_property(object: Object, type: int, path: String, hint: int, hint_text: String, usage: int) -> bool:
	print('parse_property %s %s %s' % [type, path, hint_text])
	if type == TYPE_STRING and hint_text == 'BoundProperty':
		add_property_editor(path, BindEditor.new())
		return true
	return false
