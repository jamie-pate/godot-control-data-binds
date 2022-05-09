tool
extends EditorPlugin

const InspectorPlugin := preload('./InspectorPlugin.gd')

var inspector: InspectorPlugin = null


func _enter_tree():
	assert(!inspector)
	inspector = InspectorPlugin.new()
	add_inspector_plugin(inspector)


func _exit_tree():
	remove_inspector_plugin(inspector)
	inspector = null


func handles(object: Object) -> bool:
	return false


func make_visible(show: bool) -> void:
	pass


func edit(object: Object) -> void:
	pass
