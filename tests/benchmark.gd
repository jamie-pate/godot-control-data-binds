extends Panel

const ITEM_COUNT = 100
const US_TO_MS = 1e-3


func _run_bench(force_changes: bool):
	await get_tree().process_frame
	assert(!DataBindings._change_detection_queued)
	DataBindings._detect_changes()
	if force_changes:
		$VisibilityRig.reverse_items()
	# Force a new frame to ensure that the viewport_info cache is cleared
	await get_tree().process_frame
	assert(!DataBindings._change_detection_queued)
	var d: int
	var start := Time.get_ticks_usec()
	DataBindings._detect_changes()
	d = Time.get_ticks_usec() - start
	return {
		it = DataBindings._detection_iterations,
		ch = DataBindings._changes_detected,
		duration_ms = d * US_TO_MS
	}


func _ready():
	assert(ITEM_COUNT > 1)
	var vp := get_viewport()
	if vp.size.x < 1024 || vp.size.y < 600:
		# --headless mode gives us a tiny window for some reason
		# even if we specify --resolution
		vp.size = Vector2i(1024, 600)
		assert(vp.size.x > 64)
	DataBindings.slow_detection_threshold = 0xFFFFFFF
	var times = {}
	var timestr = {}
	var results = []
	$VisibilityRig.fill_items(ITEM_COUNT)
	await get_tree().process_frame

	assert(!DataBindings._change_detection_queued)
	DataBindings._detect_changes()
	var binds = DataBindings._binds.duplicate()
	var bind_count = len(binds)

	times.no_changes = await _run_bench(false)

	times.with_changes = await _run_bench(true)

	$VisibilityRig.reverse_items()
	times.vp_vis = await $VisibilityRig.rig_visibility(true, false)
	times.hidden_viewport = await _run_bench(true)

	# reset visibility
	$VisibilityRig.reverse_items()
	times.all_vis1 = await $VisibilityRig.rig_visibility(true, true)
	# change detection maybe triggered by visibility changes!
	await get_tree().process_frame

	$VisibilityRig.reverse_items()
	times.hc_vis = await $VisibilityRig.rig_visibility(false, true)
	times.hidden_control = await _run_bench(true)

	$VisibilityRig.reverse_items()
	times.all_vis2 = await $VisibilityRig.rig_visibility(true, true)

	# Display results and write to file
	var max_name = times.keys().reduce(func(acc, n): return maxi(len(n), acc), 0)
	for t in times:
		var r = {name = t}
		r.merge(times[t])
		results.append(r)
		var dict = times[t].duplicate()
		dict.d = "%.2f" % [times[t].duration_ms]
		dict.name = t.rpad(max_name + 1)
		timestr[t] = "{name}: {it}it {ch}ch {d}ms".format(dict)
	print(
		(
			"CPU: %s %s %s threads"
			% [Engine.get_architecture_name(), OS.get_processor_name(), OS.get_processor_count()]
		)
	)
	print("Time taken (%s binds)\n%s" % [bind_count, "\n".join(timestr.values())])
	var max_ch = times.with_changes.ch
	var min_ch = times.no_changes.ch
	var hc_ch = times.hidden_control.ch
	var hv_ch = times.hidden_viewport.ch
	var result = true

	# some validation to make sure we're benchmarking what we think we are
	if hc_ch <= min_ch || hc_ch >= max_ch:
		printerr(
			(
				"ERROR: Hidden Control test should detect %s < %s < %s changes"
				% [min_ch, hc_ch, max_ch]
			)
		)
		result = false
	if hv_ch <= min_ch || hv_ch >= max_ch:
		printerr(
			(
				"ERROR: Hidden Viewport test should detect %s < %s < %s changes"
				% [min_ch, hv_ch, max_ch]
			)
		)
		result = false
	if times.all_vis1.it == 0 || times.all_vis1.ch == 0:
		printerr("Making viewport binds visible should trigger change detection")
		result = false
	if times.all_vis2.it == 0 || times.all_vis2.ch == 0:
		printerr("Making binds visible should trigger change detection")
		result = false
	if len(OS.get_cmdline_user_args()):
		var filename = OS.get_cmdline_user_args()[0]
		print("Writing results to %s" % [filename])
		var f := FileAccess.open(filename, FileAccess.WRITE)
		if !f:
			printerr("Unable to open %s: %s" % [filename, FileAccess.get_open_error()])
		else:
			f.store_string(JSON.stringify(results, " ", false))
			f.close()

	get_tree().quit(0 if result else 1)
