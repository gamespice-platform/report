extends RefCounted

## GameSpice Report's API level. The rule for bumping it is on [GSAddonApi].

# 1: GSReport, GSReportConfig, GSReportForm, GSReportEvidenceRing, GSReportLimiter.
# 2: GSReportOutbox (undelivered reports, persistable), outbox_max.
const LEVEL := 2
const OLDEST := 1
