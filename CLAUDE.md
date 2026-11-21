# GameSpice Report

Player reports and bug reports: form model, evidence ring, rate limits, hand-off. Read the family [CLAUDE.md](../../CLAUDE.md) first. **The distributable is `addons/dot_report/`**; it requires [GameSpice Core](../dot-core) only (`ln -s ../../dot-core/addons/dot_core addons/dot_core`, gitignored).

| Path | What |
| --- | --- |
| `core/dot_report_config.gd` | `GSReportConfig`: every tunable, `from_files()`, `validate()` |
| `core/dot_report_form.gd` | `GSReportForm`: validates and cleans one report |
| `core/dot_report_evidence_ring.gd` | `GSReportEvidenceRing`: bounded log lines plus screenshot and replay references |
| `core/dot_report_limiter.gd` | `GSReportLimiter`: cooldown, hourly count, duplicates |
| `runtime/dot_report.gd` | `GSReport`: the node; `submit`, `log_line`, `submitted` and `rejected` signals |
| `examples/report_selftest.tscn` | the suite |

## Boundary (what it is not)

- **dot-moderation** owns punishments, bans, appeals and its moderator tools (`GSModTools` has a moderator-side report). This addon is the player-facing intake that feeds it; do not add punishment logic here.
- **dot-log** owns sinks, shipping and its own ring. The evidence ring is a short window kept for one report; do not turn it into a logger.
- **dot-anticheat** and **dot-server-security** own detection. A detection can be attached as evidence by the game.
- No uploads and no HTTP client: references only, and `submitted` hands the report to the game.

## Rules

- No hard caps: text length, rate limits, ring size and reporter count are config, 0 is unlimited, and drops and evictions are counted, never silent.
- A refusal is a `GSResult` whose message a player can read and whose code is machine-readable (`rate_limited`, `conflict`, `invalid`).
- Over-long text is refused with the limit, never cut.
- Time is passed in (`now` seconds) so a test is repeatable; `-1` means the engine clock.
- No autoloads, no scene paths. Scripts keep `class_name` like the sibling addons, but nothing may be loaded by `uid://`.
- **Validate**: `--import`, parse every `.gd`, run the suite through `hv` (see the hv-routing skill).
