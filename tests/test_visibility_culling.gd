extends GutTest

const VISIBILITY_RIG_SCENE = preload("./visibility/visibility_rig.tscn")
const VisibilityRig = preload("./visibility/visibility_rig.gd")

var visibility_rig: VisibilityRig


func before_each():
	if get_viewport().size.x < 1024 || get_viewport().size.y < 600:
		get_viewport().size = Vector2i(1024, 600)
	var layer = CanvasLayer.new()
	visibility_rig = VISIBILITY_RIG_SCENE.instantiate()
	layer.add_child(visibility_rig)
	add_child_autofree(layer)
	await get_tree().process_frame
	assert(!DataBindings._change_detection_queued)


func _all_text_changed(changed_vrc, changed_svc = ""):
	if !changed_svc:
		changed_svc = changed_vrc
	return [
		"/VisibilityRigContent/../Label/Binds\nitem.text: " + changed_vrc,
		"/VisibilityRigContent/../TextEdit3/Binds\nitem.text: " + changed_vrc,
		"/VisibilityRigContent/../LineEdit/Binds\nitem.text: " + changed_vrc,
		(
			"/SubViewportContainer/SubViewport/VpVisibilityRigContent/../Label/Binds\nitem.text: "
			+ changed_svc
		),
		(
			"/SubViewportContainer/SubViewport/VpVisibilityRigContent/../TextEdit3/Binds\nitem.text: "
			+ changed_svc
		),
		(
			"/SubViewportContainer/SubViewport/VpVisibilityRigContent/../LineEdit/Binds\nitem.text: "
			+ changed_svc
		),
	]


func test_visibility_culling():
	var vrc_label = visibility_rig.get_node("%VisibilityRigContent").find_child(
		"Label", true, false
	)
	assert_true(vrc_label.is_visible_in_tree(), "Label is visible in tree")
	assert_true(
		vrc_label.get_node("Binds") in DataBindings._visible_binds,
		"Label/Binds is in _visible_binds"
	)

	var items = visibility_rig.get_items(false)
	items[0].text = "TEST1"
	DataBindings._detect_changes()
	assert_eq(vrc_label.text, "TEST1")
	var changed = visibility_rig.check_binds_ignoring_visibility()

	assert_eq(changed, [], "No .text binds should be 'changed'")
	assert_eq_deep(changed, [])

	# Hide /VisibilityRigContent
	await visibility_rig.rig_visibility(false, true)
	assert(!DataBindings._change_detection_queued)

	assert_false(vrc_label.is_visible_in_tree(), "Label is visible in tree")
	assert_false(
		vrc_label.get_node("Binds") in DataBindings._visible_binds,
		"Label/Binds is in _visible_binds"
	)

	items[0].text = "TEST2"
	DataBindings._detect_changes()
	assert_eq(vrc_label.text, "TEST1")

	items[0].text = "TEST2a"
	changed = visibility_rig.check_binds_ignoring_visibility()
	assert_eq(
		changed,
		_all_text_changed("TEST1 != TEST2a", "TEST2 != TEST2a"),
		"Hidden .text binds should not have been 'changed'"
	)
	assert_eq_deep(changed, _all_text_changed("TEST1 != TEST2a", "TEST2 != TEST2a"))

	items[0].text = "TEST3"
	await visibility_rig.rig_visibility(true, true, true)
	assert_true(vrc_label.is_visible_in_tree(), "Label is visible in tree")
	assert_true(
		vrc_label.get_node("Binds") in DataBindings._visible_binds,
		"Label/Binds is in _visible_binds"
	)

	assert_true(
		DataBindings._change_detection_queued,
		"Change detection should be queued by visibility changes"
	)
	await get_tree().process_frame
	assert_false(DataBindings._change_detection_queued, "Change detection should be done")

	assert_eq(vrc_label.text, "TEST3")
	items[0].text = "TEST3a"
	changed = visibility_rig.check_binds_ignoring_visibility()
	assert_eq_deep(changed, _all_text_changed("TEST3 != TEST3a"))
	# wait for change detection to happen before ending the test
	await get_tree().process_frame
	assert(!DataBindings._change_detection_queued)


func test_vp_visibility_culling():
	DataBindings._detect_changes()
	var svp_label = visibility_rig.get_node("%SubViewportContainer").find_child(
		"Label", true, false
	)

	assert_true(svp_label.is_visible_in_tree(), "Label is visible in tree")
	assert_true(
		svp_label.get_node("Binds") in DataBindings._visible_binds,
		"Label/Binds is in _visible_binds"
	)

	var items = visibility_rig.get_items(false)
	items[0].text = "TEST1"
	DataBindings._detect_changes()
	assert_eq(svp_label.text, "TEST1")
	var changed = visibility_rig.check_binds_ignoring_visibility()

	assert_eq(changed, [], "No .text binds should be 'changed'")
	assert_eq_deep(changed, [])

	# Hide /SubViewportContainer
	await visibility_rig.rig_visibility(true, false)
	assert(!DataBindings._change_detection_queued)
	assert(!DataBindings._vp_visibility_update_queued)
	assert_false(
		svp_label.get_viewport().get_parent().is_visible_in_tree(),
		"Label's viewport is not visible in tree"
	)
	assert_false(
		svp_label.get_node("Binds") in DataBindings._visible_binds,
		"Label/Binds should not be in _visible_binds"
	)

	items[0].text = "TEST2"
	DataBindings._detect_changes()
	assert_eq(svp_label.text, "TEST1")

	items[0].text = "TEST2a"
	changed = visibility_rig.check_binds_ignoring_visibility()
	assert_eq(
		changed,
		_all_text_changed("TEST2 != TEST2a", "TEST1 != TEST2a"),
		"Hidden .text binds should not have been 'changed'"
	)
	assert_eq_deep(changed, _all_text_changed("TEST2 != TEST2a", "TEST1 != TEST2a"))

	items[0].text = "TEST3"
	await visibility_rig.rig_visibility(true, true, true)
	assert_true(svp_label.is_visible_in_tree(), "Label is visible in tree")

	var dc = DataBindings._detection_count
	if !DataBindings._change_detection_queued:
		await get_tree().process_frame
	# it doesn't seem like we can actually catch the queued change detection when a viewport
	# queues it, but we can check _detection_count to ensure it's actually happened.
	if !DataBindings._change_detection_queued:
		assert_lt(
			dc,
			DataBindings._detection_count,
			"Change detection should be queued by visibility changes"
		)
	await get_tree().process_frame
	assert_true(
		svp_label.get_node("Binds") in DataBindings._visible_binds,
		"Label/Binds should be in _visible_binds"
	)
	assert_false(DataBindings._change_detection_queued, "Change detection should be done")

	assert_eq(svp_label.text, "TEST3")
	items[0].text = "TEST3a"
	changed = visibility_rig.check_binds_ignoring_visibility()
	assert_eq_deep(changed, _all_text_changed("TEST3 != TEST3a"))
	# wait for change detection to happen before ending the test
	await get_tree().process_frame
	assert(!DataBindings._change_detection_queued)


func test_hidden_vis_bound():
	# test the special behavior of the visibility bind to be checked when
	# the parent node is hidden
	var vb_node = visibility_rig.get_node("%VisibilityRigContent").find_child(
		"TextureRectVisibilityBound", true, false
	)
	var items = visibility_rig.get_items(false)
	assert_true(vb_node.is_visible_in_tree())
	assert_true(items[0].pressed)
	items[0].pressed = false
	DataBindings._detect_changes()
	assert_false(vb_node.is_visible_in_tree())
	items[0].pressed = true
	DataBindings._detect_changes()
	assert_true(vb_node.is_visible_in_tree())
