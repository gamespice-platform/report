extends RefCounted

## GameSpice Report's API level. The rule for bumping it is on [DotAddonApi].

# 1: DotReport, DotReportConfig, DotReportForm, DotReportEvidenceRing, DotReportLimiter.
# 2: DotReportOutbox (undelivered reports, persistable), outbox_max.
const LEVEL := 2
const OLDEST := 1
