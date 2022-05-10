tool
extends EditorPlugin

const InspectorPlugin := preload('./InspectorPlugin.gd')


var inspector: EditorInspectorPlugin = null


func _enter_tree():
	assert(!inspector)
	# can't use preload because the resource will stick in the cache otherwise
	inspector = InspectorPlugin.new()
	add_inspector_plugin(inspector)


func _exit_tree():
	remove_inspector_plugin(inspector)
	var s: GDScript = inspector.get_script() if inspector else null
	inspector = null
	if s:
		print('script reload!')
		s.reload()


func handles(object: Object) -> bool:
	return false


func make_visible(show: bool) -> void:
	pass


func edit(object: Object) -> void:
	pass
