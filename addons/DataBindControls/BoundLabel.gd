tool
extends Label
class_name BoundLabel

const DataBinds := preload('./DataBinds.gd')


func _init():
	add_child(DataBinds.new())
