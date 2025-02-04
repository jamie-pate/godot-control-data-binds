## Model for an item in the example list
extends "./example_model_base.gd"

var text: String
var pressed: bool
var icon: Texture2D
var value: int


func _init(initial_value = {}):
	super(initial_value)
