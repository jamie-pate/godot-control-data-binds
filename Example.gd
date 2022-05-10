extends Panel

const DataModel := preload('res://addons/DataBindControls/DataModel.gd')


var model := DataModel.new({
	label='label',
	pressed=false,
})

func _ready():
	var err := model.connect("prop_changed", self, '_on_model_prop_changed')
	$TextEdit.text = 'prop_name: %s\n%s' % ['', model]


func _on_model_prop_changed(model, prop_name):
	$TextEdit.text = 'prop_name: %s\n%s' % [prop_name, model]
