class_name GSReportForm
extends RefCounted

## The shape of a report and the one place it is checked. A player report names a target; a bug report does not. Text is cleaned of control characters and never silently cut: a field that is too long is refused with the limit, so the player sees why.

const PLAYER := "player"
const BUG := "bug"

var config: GSReportConfig


func _init(p_config: GSReportConfig = null) -> void:
	config = p_config if p_config != null else GSReportConfig.new()


## Checks [param fields] ({reporter, kind, category, target, text}) and returns a GSResult whose value is a cleaned copy.
func build(fields: Dictionary) -> GSResult:
	var reporter := clean(str(fields.get("reporter", "")))
	if reporter == "":
		return GSResult.fail(GSError.CODE_INVALID, "a report needs a reporter")
	var kind := clean(str(fields.get("kind", "")))
	if not config.kinds.has(kind):
		return GSResult.fail(GSError.CODE_INVALID, "report kind '%s' is not one of %s" % [kind, ", ".join(config.kinds)])
	var text := clean(str(fields.get("text", "")), true)
	if text.strip_edges() == "":
		return GSResult.fail(GSError.CODE_INVALID, "a report needs some text")
	if config.max_text > 0 and text.length() > config.max_text:
		return GSResult.fail(GSError.CODE_INVALID, "report text is %d characters, the limit is %d" % [text.length(), config.max_text])
	var target := clean(str(fields.get("target", "")))
	if kind == PLAYER and target == "":
		return GSResult.fail(GSError.CODE_INVALID, "a player report needs a target")
	if kind == PLAYER and target == reporter:
		return GSResult.fail(GSError.CODE_INVALID, "a player cannot report themselves")
	var category := clean(str(fields.get("category", "")))
	for field in [["target", target], ["category", category], ["reporter", reporter]]:
		if config.max_field > 0 and String(field[1]).length() > config.max_field:
			return GSResult.fail(GSError.CODE_INVALID, "report %s is longer than %d characters" % [field[0], config.max_field])
	return GSResult.success({
		"reporter": reporter, "kind": kind, "category": category, "target": target, "text": text.strip_edges(),
	})


## Removes control characters (newlines and tabs are kept in free text only) and trims the ends.
static func clean(s: String, keep_newlines: bool = false) -> String:
	var out := ""
	for i in s.length():
		var c := s.unicode_at(i)
		if c == 10 or c == 9:
			out += "\n" if (keep_newlines and c == 10) else (" " if c == 9 or not keep_newlines else "")
		elif c < 32 or c == 127:
			continue
		else:
			out += s[i]
	return out.strip_edges()
