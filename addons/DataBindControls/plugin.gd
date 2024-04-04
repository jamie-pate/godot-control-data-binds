tool
extends EditorPlugin

const InspectorPlugin := preload("./InspectorPlugin.gd")

var inspector: EditorInspectorPlugin = null


func _enter_tree():
	assert(!inspector)
	# can't use preload because the resource will stick in the cache otherwise
	inspector = InspectorPlugin.new()
	add_inspector_plugin(inspector)
	var path = get_script().resource_path.get_base_dir()
	add_autoload_singleton("DataBindings", "%s/DataBindingsGlobal.gd" % [ path ])


func _exit_tree():
	remove_autoload_singleton("DataBindings")
	remove_inspector_plugin(inspector)
	var s: GDScript = inspector.get_script() if inspector else null
	inspector = null
	if s:
		print("script reload!")
		s.reload()


func handles(_object: Object) -> bool:
	return false


func make_visible(_show: bool) -> void:
	pass


func edit(_object: Object) -> void:
	pass
