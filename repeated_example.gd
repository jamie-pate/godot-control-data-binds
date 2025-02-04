extends Panel

signal remove(item: ExampleItem)

const ExampleItem = preload("res://example_item.gd")

var item: ExampleItem


func _on_Button_pressed():
	emit_signal("remove", item)
