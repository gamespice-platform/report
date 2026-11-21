class_name GSReportConfig
extends GSConfig

## Every tunable of reporting. Layers, weakest first: these defaults, `cfg/addon/dot_report/*.yml`, the game's files, the operator's files, `DOT_REPORT_*` environment variables, then `--report-*` flags. A limit of 0 is unlimited; nothing here is a hidden cap.

const ADDON := "dot-report"

## Master switch. Off, every submit is refused with a reason.
@export var enabled: bool = true
## Where a finished report goes (https, or http on localhost). The addon never sends it; the game's client does.
@export var endpoint: String = ""
## The report kinds the form accepts.
@export var kinds: PackedStringArray = PackedStringArray(["player", "bug"])

@export_group("Form")
## Longest report text, in characters; 0 is unlimited. A longer one is refused, not cut.
@export_range(0, 1000000, 1) var max_text: int = 2000
## Longest category or target string; 0 is unlimited.
@export_range(0, 65536, 1) var max_field: int = 128

@export_group("Rate limits")
## Seconds a reporter must wait between reports; 0 means no wait.
@export_range(0, 86400, 1) var cooldown_seconds: int = 60
## Reports one reporter may send per hour; 0 is unlimited.
@export_range(0, 100000, 1) var max_per_hour: int = 10
## Seconds in which the same reporter sending the same target and text is a duplicate; 0 turns the check off.
@export_range(0, 86400, 1) var duplicate_seconds: int = 300
## Reporters remembered by the limiter; 0 is unlimited. At the limit the oldest is forgotten and counted.
@export_range(0, 1000000, 1) var max_reporters: int = 0

@export_group("Outbox")
## Reports held until delivered; 0 is unlimited. When full a new report is refused with a quota error.
@export_range(0, 100000, 1) var outbox_max: int = 100

@export_group("Evidence")
## Log lines kept in the evidence ring; 0 is unlimited.
@export_range(0, 1000000, 1) var evidence_lines: int = 200
## Whether the game is asked for a screenshot reference with each report.
@export var include_screenshot: bool = true
## Whether the game is asked for a replay clip reference with each report.
@export var include_replay: bool = true


func env_prefix() -> String:
	return "DOT_REPORT_"


func cli_prefix() -> String:
	return "--report-"


func validate() -> GSResult:
	if endpoint != "" and not (endpoint.begins_with("https://") or endpoint.begins_with("http://localhost")):
		return GSResult.fail(GSError.CODE_INVALID, "report endpoint '%s' must be https (or http on localhost)" % endpoint)
	if outbox_max < 0 or max_text < 0 or max_field < 0:
		return GSResult.fail(GSError.CODE_INVALID, "report limits cannot be negative (0 is unlimited)")
	if kinds.is_empty():
		return GSResult.fail(GSError.CODE_INVALID, "report kinds is empty, so no report could ever be accepted")
	return GSResult.success(self)


## Defaults, then `cfg/addon/dot_report/*.yml` and the game tier, then environment and command line.
static func from_files() -> GSResult:
	var cfg := GSReportConfig.new()
	var files := GSAddonConfig.load_dir(ADDON)
	if not files.ok:
		return files
	cfg.apply_dictionary(files.value as Dictionary, "yml")
	return cfg.load_layered()


func describe() -> String:
	return "report %s cooldown %ds per hour %d evidence %d lines" % [
		"on" if enabled else "off", cooldown_seconds, max_per_hour, evidence_lines]
