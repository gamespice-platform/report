class_name GSReportEvidenceRing
extends RefCounted

## The last log lines before a report, kept in a bounded ring so a bug report can say what just happened. It holds text and references only: a screenshot or replay clip is a path or id the game saved elsewhere, never bytes in this ring.

var capacity: int = 200
## Lines overwritten because the ring was full.
var dropped: int = 0

var _lines: Array = []   # [{"at": float, "line": String}]
var _screenshot := ""
var _replay := ""


## [param p_capacity] of 0 is unlimited.
func _init(p_capacity: int = 200) -> void:
	capacity = p_capacity


func add(line: String, now: float = -1.0) -> void:
	_lines.append({"at": now if now >= 0.0 else Time.get_ticks_msec() / 1000.0, "line": line})
	if capacity > 0:
		while _lines.size() > capacity:
			_lines.pop_front()
			dropped += 1


func size() -> int:
	return _lines.size()


## The kept lines, oldest first, as plain strings.
func lines() -> PackedStringArray:
	var out := PackedStringArray()
	for e in _lines:
		out.append(e["line"])
	return out


## Notes where the game saved a screenshot for this report.
func attach_screenshot(ref: String) -> void:
	_screenshot = ref


## Notes where the game saved a replay clip for this report.
func attach_replay(ref: String) -> void:
	_replay = ref


## A copy of what is held, ready to put on a report: {log, screenshot, replay, dropped}.
func snapshot() -> Dictionary:
	return {"log": lines(), "screenshot": _screenshot, "replay": _replay, "dropped": dropped}


func clear() -> void:
	_lines.clear()
	_screenshot = ""
	_replay = ""
