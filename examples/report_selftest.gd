extends Node

## dot-report's headless suite (res://examples/report_selftest.tscn).
## Counts sections run to their last line as well as checks, because a script error
## aborts a section and not the run.

const EXPECTED_SECTIONS := 7
const EXPECTED_CHECKS := 52

var _passed := 0
var _failed := 0
var _sections := 0
var _got: Array = []
var _refused: Array = []


func _ready() -> void:
	print("dot-report")
	_config()
	_form()
	_ring()
	_limiter()
	_node()
	_layers()
	_outbox()
	print("")
	_check(_sections == EXPECTED_SECTIONS, "every section ran to its last line (%d of %d)" % [_sections, EXPECTED_SECTIONS])
	_check(_passed + _failed == EXPECTED_CHECKS, "and the suite ran all %d of its checks (%d)" % [EXPECTED_CHECKS, _passed + _failed])
	print("%d passed, %d failed" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


func _config() -> void:
	var c := GSReportConfig.new()
	_check(c.validate().ok, "defaults validate")
	c.endpoint = "http://example.com/r"
	_check(not c.validate().ok, "a plain http endpoint is refused")
	c.endpoint = "https://example.com/r"
	_check(c.validate().ok, "an https endpoint is fine")
	c.kinds = PackedStringArray()
	_check(not c.validate().ok, "no kinds at all is refused")
	_check(c.has_key("cooldown_seconds") and c.has_key("max_text") and c.has_key("evidence_lines"), "the tunables are config keys")
	_sections += 1


func _form() -> void:
	var f := GSReportForm.new()
	var ok := f.build({"reporter": "a", "kind": "player", "target": "b", "category": "cheating", "text": "  aimbot  "})
	_check(ok.ok and ok.value["text"] == "aimbot", "a player report builds and trims", str(ok.code()))
	_check(f.build({"reporter": "a", "kind": "bug", "text": "it crashed"}).ok, "a bug report needs no target")
	_check(not f.build({"reporter": "a", "kind": "player", "text": "x"}).ok, "a player report needs a target")
	_check(not f.build({"reporter": "a", "kind": "player", "target": "a", "text": "x"}).ok, "reporting yourself is refused")
	_check(not f.build({"kind": "bug", "text": "x"}).ok, "a missing reporter is refused")
	_check(not f.build({"reporter": "a", "kind": "spam", "text": "x"}).ok, "an unknown kind is refused")
	_check(not f.build({"reporter": "a", "kind": "bug", "text": "   "}).ok, "empty text is refused")
	var long := "x".repeat(2001)
	var r := f.build({"reporter": "a", "kind": "bug", "text": long})
	_check(not r.ok and r.error.message.contains("2000"), "text over the limit is refused with the limit, not cut")
	var cfg := GSReportConfig.new()
	cfg.max_text = 0
	_check(GSReportForm.new(cfg).build({"reporter": "a", "kind": "bug", "text": long}).ok, "max_text 0 is unlimited")
	var ctl := f.build({"reporter": "a", "kind": "bug", "text": "a\u0001b\nc\u007f"})
	_check(ctl.ok and ctl.value["text"] == "ab\nc", "control characters go, newlines stay in text", str(ctl.value if ctl.ok else ""))
	_check(GSReportForm.clean("a\tb\nc") == "a b c", "tabs and newlines in a short field become spaces")
	_sections += 1


func _ring() -> void:
	var r := GSReportEvidenceRing.new(3)
	for i in 5:
		r.add("line %d" % i, float(i))
	_check(r.size() == 3 and r.lines()[0] == "line 2" and r.lines()[2] == "line 4", "the ring keeps the newest lines")
	_check(r.dropped == 2, "and counts what it overwrote")
	r.attach_screenshot("user://shots/1.png")
	r.attach_replay("replay:42")
	var snap := r.snapshot()
	_check(snap["screenshot"] == "user://shots/1.png" and snap["replay"] == "replay:42", "screenshot and replay are references")
	_check((snap["log"] as PackedStringArray).size() == 3 and snap["dropped"] == 2, "the snapshot carries the log and the drop count")
	r.clear()
	_check(r.size() == 0 and r.snapshot()["screenshot"] == "", "clear empties it")
	var u := GSReportEvidenceRing.new(0)
	for i in 1000:
		u.add("x", 0.0)
	_check(u.size() == 1000 and u.dropped == 0, "capacity 0 is unlimited")
	_sections += 1


func _limiter() -> void:
	var cfg := GSReportConfig.new()
	cfg.cooldown_seconds = 10
	cfg.max_per_hour = 3
	cfg.duplicate_seconds = 100
	var l := GSReportLimiter.new(cfg)
	_check(l.check("a", "k1", 0.0).ok, "the first report passes")
	l.record("a", "k1", 0.0)
	var cool := l.check("a", "k2", 5.0)
	_check(not cool.ok and cool.error.code == GSError.CODE_RATE_LIMITED and cool.error.message.contains("5"), "inside the cooldown it says how long to wait")
	_check(l.check("a", "k2", 10.0).ok, "after the cooldown it passes")
	var dup := l.check("a", "k1", 20.0)
	_check(not dup.ok and dup.error.code == GSError.CODE_CONFLICT, "the same report again is a duplicate")
	_check(l.check("a", "k1", 200.0).ok, "a duplicate is allowed once its window passes")
	l.record("a", "k2", 10.0)
	l.record("a", "k3", 30.0)
	var hour := l.check("a", "k4", 50.0)
	_check(not hour.ok and hour.error.message.contains("3 reports"), "the hourly count is enforced")
	_check(l.check("a", "k4", 3700.0).ok, "and the hour slides")
	_check(l.check("b", "k1", 0.0).ok, "another reporter has their own limits")
	var open := GSReportConfig.new()
	open.cooldown_seconds = 0
	open.max_per_hour = 0
	open.duplicate_seconds = 0
	var o := GSReportLimiter.new(open)
	for i in 50:
		o.record("a", "same", 0.0)
	_check(o.check("a", "same", 0.0).ok, "limits of 0 turn each check off")
	var cap := GSReportConfig.new()
	cap.max_reporters = 2
	var c := GSReportLimiter.new(cap)
	c.record("x", "k", 0.0)
	c.record("y", "k", 0.0)
	c.record("z", "k", 0.0)
	_check(c.size() == 2 and c.evicted == 1, "max_reporters evicts the oldest and counts it")
	_sections += 1


func _node() -> void:
	var cfg := GSReportConfig.new()
	cfg.include_replay = false
	var n := GSReport.new()
	n.config = cfg
	add_child(n)
	n.submitted.connect(func(rep): _got.append(rep))
	n.rejected.connect(func(reason, code): _refused.append([reason, code]))
	n.log_line("boot ok")
	n.log_line("hit a wall")
	n.evidence.attach_screenshot("shot.png")
	n.evidence.attach_replay("clip.dem")
	var r := n.submit({"reporter": "a", "kind": "bug", "text": "stuck in the wall"}, 0.0)
	_check(r.ok and _got.size() == 1 and _got[0]["id"] == 1, "a good report is emitted with an id")
	var ev: Dictionary = _got[0]["evidence"]
	_check((ev["log"] as PackedStringArray).size() == 2 and ev["screenshot"] == "shot.png", "it carries the evidence")
	_check(ev["replay"] == "", "include_replay off leaves the replay reference out")
	var again := n.submit({"reporter": "a", "kind": "bug", "text": "another one"}, 1.0)
	_check(not again.ok and _refused.size() == 1 and _refused[0][1] == GSError.CODE_RATE_LIMITED, "a second report inside the cooldown is refused and signalled")
	_check(not n.submit({"reporter": "z", "kind": "player", "text": "x"}, 0.0).ok, "a bad form is refused and signalled")
	_check(_refused.size() == 2 and n.count() == 1, "only accepted reports are counted")
	cfg.enabled = false
	_check(not n.submit({"reporter": "q", "kind": "bug", "text": "x"}, 0.0).ok, "switched off, nothing is accepted")
	_sections += 1


func _layers() -> void:
	var r := GSReportConfig.from_files()
	_check(r.ok and (r.value as GSReportConfig).validate().ok, "the layered config loads and validates", str(r.code()))
	_check(GSReportConfig.new().describe().contains("cooldown"), "describe names the cooldown")
	_sections += 1


func _outbox() -> void:
	var o := GSReportOutbox.new(2)
	_check(o.push({"id": 1}).ok and o.push({"id": 2}).ok, "the box takes reports up to its capacity")
	_check(o.push({"id": 3}).code() == GSError.CODE_QUOTA, "a full box refuses loudly")
	_check(o.peek(1).size() == 1 and o.size() == 2, "peek does not remove")
	o.ack(1)
	_check(o.size() == 1 and o.peek()[0]["id"] == 2, "ack removes the oldest delivered")
	var saved := o.to_array()
	var o2 := GSReportOutbox.new(0)
	_check(o2.load_array(saved + ["junk", {"nope": 1}]).value == 2 and o2.size() == 1, "load_array skips junk and counts it")
	for i in 500:
		o2.push({"id": i})
	_check(o2.size() == 501, "capacity 0 is unlimited")
	var cfg := GSReportConfig.new()
	cfg.outbox_max = 1
	cfg.cooldown_seconds = 0
	cfg.duplicate_seconds = 0
	var n := GSReport.new()
	n.config = cfg
	n._ready()
	var f := {"reporter": "a", "kind": "bug", "text": "x"}
	_check(n.submit(f, 1.0).ok and n.outbox.size() == 1, "a passed report lands in the outbox")
	_check(n.submit(f, 2.0).code() == GSError.CODE_QUOTA and n.count() == 1, "a full outbox refuses and does not use the rate limit")
	n.outbox.ack(1)
	_check(n.submit(f, 3.0).ok, "room again after delivery")
	n.free()
	cfg.outbox_max = -1
	_check(not cfg.validate().ok, "a negative limit is refused")
	_sections += 1


func _check(ok: bool, what: String, extra: String = "") -> void:
	if ok:
		_passed += 1
		print("  ok    ", what)
	else:
		_failed += 1
		print("  FAIL  ", what, "  ", extra)
