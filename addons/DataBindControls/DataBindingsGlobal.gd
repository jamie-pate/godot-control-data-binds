extends Node

const Util = preload("./Util.gd")

const MAX_CHANGES = 100
const MAX_CHANGES_LOGGED = 20

var _change_detection_queued := false


## queue change detection
func detect_changes(ancestor: Node = null) -> void:
	if _change_detection_queued:
		return
	_change_detection_queued = true
	call_deferred("_detect_changes", ancestor)


func _detect_changes(ancestor: Node):
	# TODO: queue change detection per viewport root or control root?
	# each piece of 2d UI change detection could happen on a separate frame, spreading out the load..
	# 50 binds can take 1ms to check
	_change_detection_queued = false
	var change_log := []
	var i := 0
	var changes_detected := true
	var result := false
	while changes_detected || _change_detection_queued:
		_change_detection_queued = false
		changes_detected = false
		if i > MAX_CHANGES:
			printerr(
				(
					"Maximum changes detected.. change log:\n%s"
					% ["\n".join(PackedStringArray(change_log))]
				)
			)
			result = true
			break
		var binds := get_tree().get_nodes_in_group(Util.BIND_GROUP)
		if ancestor:
			binds = binds.filter(ancestor.is_ancestor_of)
		for bind in binds:
			var cd := bind.detect_changes() as bool
			if cd:
				while len(change_log) > MAX_CHANGES_LOGGED:
					change_log.pop_front()
				change_log.append(bind.get_desc())
			changes_detected = changes_detected || cd
		i += 1
		result = i > 1
	_change_detection_queued = false
	return result
