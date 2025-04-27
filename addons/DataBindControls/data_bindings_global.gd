extends Node

const Util = preload("./util.gd")

const MAX_CHANGES = 100
const MAX_CHANGES_LOGGED = 20

var slow_detection_threshold := 2 if EngineDebugger.is_active() && !OS.has_feature("mobile") else 8
var vp_info := ViewportInfo.new()

var _change_detection_queued := false
var _vp_visibility_update_queued := false
var _changes_detected := 0
## Number of iterations taken in the most recent change detection
var _detection_iterations := 0
## number of times _detect_changes() has been called
var _detection_count := 0
var _visible_binds: Dictionary
## Hidden binds that still need to be checked because they bind visibility
var _hidden_binds: Dictionary
var _binds: Dictionary
# count how many bind visibility updates happened
var _vbind_plus: int
var _vbind_minus: int
var _vbind_time: int


class ViewportInfo:
	extends RefCounted

	signal vp_changed

	const OFFSET := 100000
	const MIN_SIZE := 128

	var _cache := {}
	var _seen := {}
	var _were_visible := {}
	var _frame := 0

	func get_were_visible():
		return _were_visible.duplicate()

	func is_visible(vp: Viewport) -> bool:
		var new_frame := Engine.get_frames_drawn()
		var rid := vp.get_viewport_rid()
		if _frame == new_frame:
			var result := _cache.get(rid)
		else:
			_frame = new_frame
			_cache.clear()
		var size := vp.size as Vector2i
		var result = 0
		# SubViewport must be a child of Node3D or CanvasItem
		var parent = vp.get_parent() as Node3D
		if !parent:
			parent = vp.get_parent() as CanvasItem
		if !parent && vp is Window:
			parent = vp
		assert(
			parent,
			"Any SubViewport that contains Binds must have a Node3D or CanvasItem for a parent"
		)
		var pid: int = parent.get_instance_id()
		var old_pid = _seen.get(rid, -1)
		if old_pid == -1:
			vp.size_changed.connect(_vp_changed)
		if pid != old_pid:
			if old_pid != -1:
				var obj = instance_from_id(old_pid)
				if obj && obj.has_signal("visibility_changed"):
					obj.visibility_changed.disconnect(_vp_changed)
			if parent.has_signal("visibility_changed"):
				parent.visibility_changed.connect(_vp_changed)
			_seen[rid] = pid
		var parent_visible = (
			parent.is_visible_in_tree() if parent is SubViewport else parent.visible
		)
		if parent && !parent_visible:
			result = 0
		elif vp is SubViewport && size.x < MIN_SIZE && size.y < MIN_SIZE:
			# Don't discard visible windows, even if they are tiny, but tiny subviewports
			# shouldn't be updated
			result = -(OFFSET + MIN_SIZE)
		elif vp is SubViewport:
			var svp: SubViewport = vp
			var mode := svp.render_target_update_mode
			result = OFFSET + mode
			if mode == SubViewport.UPDATE_DISABLED:
				result = 0
			elif mode in [SubViewport.UPDATE_WHEN_VISIBLE, SubViewport.UPDATE_WHEN_PARENT_VISIBLE]:
				var riv := RenderingServer.viewport_get_render_info(
					vp.get_viewport_rid(),
					RenderingServer.VIEWPORT_RENDER_INFO_TYPE_CANVAS,
					RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME
				)
				result = 1 if riv > 0 || Engine.get_frames_drawn() < 2 else 0
		else:
			# window always draws
			result = OFFSET + SubViewport.UPDATE_ALWAYS
		_cache[rid] = result
		_were_visible[rid] = result > 0
		return result > 0

	func _vp_changed():
		vp_changed.emit()

	func summary():
		var always := len(
			_cache.values().filter(func(v): return v == OFFSET + SubViewport.UPDATE_ALWAYS)
		)
		var count := len(_cache.values().filter(func(v): return v > 0))
		return "%s/%s viewports (%s ALWAYS)" % [count, len(_cache), always]


func _init():
	vp_info.vp_changed.connect(_vp_visibility_updated)


func _vp_visibility_updated():
	if !_vp_visibility_update_queued:
		_vp_visibility_update_queued = true
	_vp_visibility_update.call_deferred(vp_info.get_were_visible())


func _vp_visibility_update(were_visible: Dictionary):
	# this can happen frequently even though we debounce it.
	# Check to make sure the visibility of each vp actually changed since the last time
	# it was checked during detect_changes
	var vp_vis_same := {}
	for bind in _binds:
		var vp := bind.get_viewport() as Viewport
		var same = vp_vis_same.get(vp, null) if vp else null
		if !vp || same:
			continue
		if same == null:
			# we don't want to do this part for every bind, try to do it once per viewport
			var was_visible = were_visible.get(vp.get_viewport_rid(), null)
			same = was_visible == vp_info.is_visible(vp)
			vp_vis_same[vp] = same
			if same:
				continue
		update_bind_visibility(bind)
	_vp_visibility_update_queued = false


func add_bind(bind):
	_binds[bind] = true
	update_bind_visibility(bind)


func remove_bind(bind):
	_binds.erase(bind)
	_visible_binds.erase(bind)
	_hidden_binds.erase(bind)


func update_bind_visibility(bind):
	var start = Time.get_ticks_usec()
	var p = bind.get_parent()
	var vp := bind.get_viewport() as Viewport
	if p && p.is_visible_in_tree() && (!vp || vp_info.is_visible(vp)):
		_vbind_plus += 1
		if bind not in _visible_binds:
			_visible_binds[bind] = true
			_hidden_binds.erase(bind)
			detect_changes()
	else:
		_vbind_minus += 1
		_visible_binds.erase(bind)
		if bind.has_visibility_bind():
			_hidden_binds[bind] = true
			detect_changes()
	_vbind_time += Time.get_ticks_usec() - start


## queue change detection
func detect_changes() -> void:
	if _change_detection_queued:
		return
	_change_detection_queued = true
	_detect_changes.call_deferred()


func _detect_changes():
	_detection_count += 1
	# TODO: queue change detection per viewport root or control root?
	# each piece of 2d UI change detection could happen on a separate frame, spreading out the load..
	# 50 binds can take 1ms to check
	_change_detection_queued = false
	_changes_detected = 0
	var change_log := []
	var i := 0
	var changes_detected := true
	var result := false
	while changes_detected || _change_detection_queued:
		var start := Time.get_ticks_usec()
		_change_detection_queued = false
		changes_detected = false
		var timings: Array[String]
		var hidden: Array
		for bind in _hidden_binds.keys():
			if bind.should_be_visible():
				hidden.append(bind)

		for bind in _visible_binds.keys() + hidden:
			var b_start := Time.get_ticks_usec()
			var cd := bind.detect_changes() as bool
			if cd:
				while len(change_log) > MAX_CHANGES_LOGGED:
					change_log.pop_front()
				change_log.append(bind.get_desc())
				_changes_detected += bind.change_count()
			changes_detected = changes_detected || cd
			var duration = float(Time.get_ticks_usec() - b_start) * 0.001
			timings.append("%.2f %s" % [duration, bind.get_desc()])
		i += 1
		result = i > 1
		var duration := float(Time.get_ticks_usec() - start) * 0.001
		if duration > slow_detection_threshold:
			timings.sort()
			timings.reverse()
			printerr(
				(
					"Change detection was slow. %s/%s/%s changes took %.2fms!\n%s\n%s"
					% [
						len(timings),
						len(_visible_binds),
						len(_binds),
						duration,
						vp_info.summary(),
						"\n".join(timings.slice(0, 3))
					]
				)
			)
		if i > MAX_CHANGES:
			printerr(
				(
					"Maximum changes detected.. change log:\n%s"
					% ["\n".join(PackedStringArray(change_log))]
				)
			)
			breakpoint
			result = true
			break
	_detection_iterations = i
	_change_detection_queued = false
	return result
