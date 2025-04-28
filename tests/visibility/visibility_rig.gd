extends Panel

const ExampleItem = preload("res://example_item.gd")
const US_TO_MS = 1e-3

var icons = [
	preload("res://addons/DataBindControls/icons/link.svg"),
	preload("res://addons/DataBindControls/icons/links.svg"),
	preload("res://addons/DataBindControls/icons/list.svg")
]


func _ready():
	fill_items(1)
	DataBindings.detect_changes()


func fill_items(count: int):
	%VisibilityRigContent.items.clear()
	%VpVisibilityRigContent.items.clear()
	for i in range(count):
		var item = ExampleItem.new(
			{
				text = "%sth item" % [count],
				pressed = i % 2 == 0,
				icon = icons[i % len(icons)],
				value = i
			}
		)
		%VisibilityRigContent.items.append(item)
		%VpVisibilityRigContent.items.append(item)


func reverse_items():
	%VisibilityRigContent.items.reverse()
	%VpVisibilityRigContent.items.reverse()


func get_items(vr: bool) -> Array[ExampleItem]:
	if vr:
		return %VpVisibilityRigContent.items
	return %VisibilityRigContent.items


func rig_visibility(content: bool, viewport: bool, dont_wait := false):
	DataBindings._vbind_minus = 0
	DataBindings._vbind_plus = 0
	DataBindings._vbind_time = 0
	var d: int
	var start = Time.get_ticks_usec()
	var vr_content = %VisibilityRigContent
	var vp_container = %SubViewportContainer
	var make_visible = content && !vr_content.visible || viewport && !vp_container.visible
	var last_dc := DataBindings._detection_count
	vr_content.visible = content
	vp_container.visible = viewport
	d = Time.get_ticks_usec() - start
	if dont_wait:
		return
	var vbind_time = DataBindings._vbind_time
	# reset _vbind_time so we don't double count time taken before this line
	DataBindings._vbind_time = 0
	var change_detected = (
		DataBindings._change_detection_requested || DataBindings._detection_count > last_dc
	)
	if !change_detected:
		# may take 2 frames if it's a viewport update
		await get_tree().process_frame
		change_detected = (
			DataBindings._change_detection_requested || DataBindings._detection_count > last_dc
		)
	assert(!make_visible || change_detected)
	if change_detected:
		await get_tree().process_frame
	assert(!DataBindings._change_detection_requested)

	# Print how many binds are checked for visibility changes
	# Note that viewport ancestor binds make be checked more than expected
	print_verbose(
		(
			"rig_visibility, making visible: %s %s"
			% [
				make_visible,
				" ".join(
					[
						"+:",
						DataBindings._vbind_plus,
						"-:",
						DataBindings._vbind_minus,
						"us:",
						DataBindings._vbind_time + vbind_time
					]
				)
			]
		)
	)
	d += DataBindings._vbind_time
	return {
		desc = "Time to toggle visibility (not counting change detection)",
		it = DataBindings._detection_iterations if change_detected else 0,
		ch = DataBindings._changes_detected if change_detected else 0,
		dc = DataBindings._detection_count - last_dc,
		duration_ms = d * US_TO_MS
	}


## Check binds for items that haven't been updated to match.
## Each non-matching item appends it's path to the result
func check_binds_ignoring_visibility() -> Array[String]:
	var result = %VisibilityRigContent.check_binds() + %VpVisibilityRigContent.check_binds()
	var shorten = func(s):
		return s.replace(str($BoxContainer.get_path()), "").replace(
			"VBoxContainer/RepeatedControl/VBoxContainer", ".."
		)
	result.assign(result.map(shorten))
	return result
