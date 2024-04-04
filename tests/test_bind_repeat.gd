extends GutTest

const REPEATED_CONTROL_HOST = preload("./RepeatedControlHost.tscn")

func test_bind_repeat():
	var repeated_control_host = REPEATED_CONTROL_HOST.instantiate()
	add_child_autoqfree(repeated_control_host)

	# not sure why this takes 2 frames to call the deferred method
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	
	assert_eq(repeated_control_host.get_child_count(), 0)
	repeated_control_host.model.append("text")
	DataBindings.detect_changes()
	await RenderingServer.frame_post_draw
	assert_eq(repeated_control_host.get_child_count(), 1)
	var label = repeated_control_host.get_child(0)
	assert_eq(label.text if label else null, "text")
