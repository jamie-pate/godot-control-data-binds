extends EditorProperty

var suggestions := OptionButton.new()

func _init():
	print('EditorProperty init')
	add_child(suggestions)
	set_bottom_editor(suggestions)

