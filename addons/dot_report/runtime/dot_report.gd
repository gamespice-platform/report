class_name DotReport
extends Node

## The report node: it feeds the evidence ring, checks and rate-limits a submitted report, and emits it. It does not send anything: connect [signal submitted] to GameSpice Moderation's intake or to your own client for the TMC backbone.

## A report passed every check. [param report] is the form plus its evidence.
signal submitted(report: Dictionary)
## A report was refused. [param reason] is the message a player can be shown.
signal rejected(reason: String, code: String)

@export var config: DotReportConfig = null

var form: DotReportForm
var evidence: DotReportEvidenceRing
var limiter: DotReportLimiter

var _count: int = 0


func _ready() -> void:
	if config == null:
		config = DotReportConfig.new()
	form = DotReportForm.new(config)
	evidence = DotReportEvidenceRing.new(config.evidence_lines)
	limiter = DotReportLimiter.new(config)


## Adds a line to the evidence ring; the game's log handler calls this.
func log_line(line: String) -> void:
	if evidence == null:
		_ready()
	evidence.add(line)


## Checks, rate-limits and emits one report. Returns a DotResult whose value is the report dictionary.
func submit(fields: Dictionary, now: float = -1.0) -> DotResult:
	if form == null:
		_ready()
	var r := _submit(fields, now)
	if r.ok:
		submitted.emit(r.value)
	else:
		rejected.emit(r.error.message, r.error.code)
	return r


func count() -> int:
	return _count


func _submit(fields: Dictionary, now: float) -> DotResult:
	if not config.enabled:
		return DotResult.fail(DotError.CODE_STATE, "reporting is switched off")
	var built := form.build(fields)
	if not built.ok:
		return built
	var f: Dictionary = built.value
	var key := "%s|%s|%s" % [f["kind"], f["target"], f["text"]]
	var allowed := limiter.check(f["reporter"], key, now)
	if not allowed.ok:
		return allowed
	limiter.record(f["reporter"], key, now)
	_count += 1
	var report: Dictionary = f.duplicate()
	report["id"] = _count
	report["evidence"] = evidence.snapshot()
	if not config.include_screenshot:
		report["evidence"]["screenshot"] = ""
	if not config.include_replay:
		report["evidence"]["replay"] = ""
	return DotResult.success(report)
