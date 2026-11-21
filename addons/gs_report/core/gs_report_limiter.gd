class_name GSReportLimiter
extends RefCounted

## Stops report floods: a wait between reports, a count per hour, and the same report sent twice. Every refusal is a GSResult with a reason that says how long to wait. Time is passed in as seconds so a test is repeatable.

var config: GSReportConfig
## Reporters forgotten to stay inside `max_reporters`.
var evicted: int = 0

var _history: Dictionary = {}   # reporter -> Array of {"at": float, "key": String}


func _init(p_config: GSReportConfig = null) -> void:
	config = p_config if p_config != null else GSReportConfig.new()


## Whether [param reporter] may send a report with this [param key] (target plus text) at [param now]. Does not record it.
func check(reporter: String, key: String, now: float = -1.0) -> GSResult:
	var t := _now(now)
	var sent: Array = _history.get(reporter, [])
	var last_at := -INF
	var in_hour := 0
	for e in sent:
		last_at = maxf(last_at, float(e["at"]))
		if t - float(e["at"]) < 3600.0:
			in_hour += 1
		if config.duplicate_seconds > 0 and e["key"] == key and t - float(e["at"]) < float(config.duplicate_seconds):
			return GSResult.fail(GSError.CODE_CONFLICT, "that report was already sent %d seconds ago" % int(t - float(e["at"])))
	if config.cooldown_seconds > 0 and t - last_at < float(config.cooldown_seconds):
		return GSResult.fail(GSError.CODE_RATE_LIMITED, "wait %d more seconds before another report" % ceili(float(config.cooldown_seconds) - (t - last_at)))
	if config.max_per_hour > 0 and in_hour >= config.max_per_hour:
		return GSResult.fail(GSError.CODE_RATE_LIMITED, "the limit is %d reports an hour" % config.max_per_hour)
	return GSResult.success(true)


## Notes that a report went out.
func record(reporter: String, key: String, now: float = -1.0) -> void:
	var t := _now(now)
	if not _history.has(reporter) and config.max_reporters > 0 and _history.size() >= config.max_reporters:
		_history.erase(_history.keys()[0])
		evicted += 1
	var sent: Array = _history.get(reporter, [])
	sent.append({"at": t, "key": key})
	var kept: Array = []
	var horizon := maxf(3600.0, float(config.duplicate_seconds))
	for e in sent:
		if t - float(e["at"]) < horizon:
			kept.append(e)
	_history[reporter] = kept


func size() -> int:
	return _history.size()


func forget(reporter: String) -> void:
	_history.erase(reporter)


func _now(now: float) -> float:
	return now if now >= 0.0 else Time.get_ticks_msec() / 1000.0
