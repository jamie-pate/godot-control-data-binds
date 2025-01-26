extends Node

const Util = preload("./util.gd")

const MAX_CHANGES = 100
const MAX_CHANGES_LOGGED = 20

var slow_detection_threshold := 2 if EngineDebugger.is_active() && !OS.has_feature("mobile") else 8

var _change_detection_queued := false


class DrawDetector:
	extends Control

	const META_KEY = "data_bindings_draw_detector"
	var last_frame := 0

	static func ensure(vp: SubViewport):
		if !vp.has_meta(META_KEY):
			var dd := DrawDetector.new()
			vp.set_meta(META_KEY, dd.get_instance_id())
			vp.add_child(dd)

	static func drawn(vp: SubViewport):
		var id := vp.get_meta(META_KEY, null)
		if id != null:
			var dd = instance_from_id(id)
			if !dd || dd is not DrawDetector:
				vp.remove_meta(META_KEY)
			else:
				var fd := Engine.get_frames_drawn()
				# was it drawn in the last few frames?
				if dd.last_frame < fd - 2:
					pass
				return dd.last_frame >= fd - 2
		return false

	func _notification(what: int) -> void:
		if what == NOTIFICATION_DRAW:
			last_frame = Engine.get_frames_drawn()


static var vp_info := ViewportInfo.new()


class ViewportInfo:
	extends RefCounted

	const OFFSET := 100000
	const MIN_SIZE := 128

	var _cache := {}
	var _frame := 0

	func is_visible(vp: SubViewport) -> bool:
		var new_frame := Engine.get_frames_drawn()
		var rid := vp.get_viewport_rid()
		if _frame == new_frame:
			var result := _cache.get(rid)
		else:
			_frame = new_frame
			_cache.clear()
		var size := vp.size
		var result = 0
		var parent := vp.get_parent() as Node3D
		if parent && !parent.is_visible_in_tree():
			result = 0
		elif size.x < MIN_SIZE && size.y < MIN_SIZE:
			result = -(OFFSET + MIN_SIZE)
		else:
			var mode := vp.render_target_update_mode
			result = OFFSET + mode
			if mode == SubViewport.UPDATE_DISABLED:
				result = 0
			elif mode in [SubViewport.UPDATE_WHEN_VISIBLE, SubViewport.UPDATE_WHEN_PARENT_VISIBLE]:
				DrawDetector.ensure(vp)
				result = 1 if DrawDetector.drawn(vp) else 0
				if result == 0:
					pass
		_cache[rid] = result
		return result > 0

	func summary():
		var always := len(
			_cache.values().filter(func(v): return v == OFFSET + SubViewport.UPDATE_ALWAYS)
		)
		var count := len(_cache.values().filter(func(v): return v > 0))
		return "%s/%s viewports (%s ALWAYS)" % [count, len(_cache), always]


## queue change detection
func detect_changes() -> void:
	if _change_detection_queued:
		return
	_change_detection_queued = true
	call_deferred("_detect_changes")


func _detect_changes():
	# TODO: queue change detection per viewport root or control root?
	# each piece of 2d UI change detection could happen on a separate frame, spreading out the load..
	# 50 binds can take 1ms to check
	_change_detection_queued = false
	var change_log := []
	var i := 0
	var changes_detected := true
	var result := false
	while changes_detected || _change_detection_queued:
		var start := Time.get_ticks_usec()
		_change_detection_queued = false
		changes_detected = false
		var timings: Array[String]
		var binds := get_tree().get_nodes_in_group(Util.BIND_GROUP)
		for bind in binds:
			var b_start := Time.get_ticks_usec()
			if !_should_detect_changes(bind):
				continue
			var cd := bind.detect_changes() as bool
			if cd:
				while len(change_log) > MAX_CHANGES_LOGGED:
					change_log.pop_front()
				change_log.append(bind.get_desc())
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
					"Change detection was slow. %s/%s changes took %.2fms!\n%s\n%s"
					% [
						len(timings),
						len(binds),
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
	_change_detection_queued = false
	return result


func _should_detect_changes(bind: Node):
	var p := bind.get_parent()
	if p:
		var gp := p.get_parent()
		if (gp is Node3D || gp is Control) && !gp.is_visible_in_tree():
			return false
	var vp := p.get_viewport() as SubViewport
	if vp:
		return vp_info.is_visible(vp)
	return true
