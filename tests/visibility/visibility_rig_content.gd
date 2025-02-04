extends ScrollContainer

const ExampleItem = preload("res://example_item.gd")

var items: Array[ExampleItem]


## Check binds for items that haven't been updated to match.
## Each non-matching item appends it's path to the result
## we can just call detect_changes() because DataBindings._detect_changes()
## would skip any hidden controls and that's what we're interested in.
func check_binds() -> Array[String]:
	var result: Array[String]
	for bind in DataBindings._binds:
		if bind.detect_changes():
			result.append(bind.get_desc())
	return result
