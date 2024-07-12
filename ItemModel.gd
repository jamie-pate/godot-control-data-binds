## Model for an item in the example list
extends "./BaseModel.gd"

var text: String
var pressed: bool
var icon: Texture2D
var value: int


func _init(initial_value = {}):
	super(initial_value)
