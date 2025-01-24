## Model for the root of the example
extends "./BaseModel.gd"

var text: String
var path: String
var pressed: bool
var array: Array
var time: String
var icon: Texture = null


func array_callable():
	return array


func _init(initial_value = {}):
	super(initial_value)
