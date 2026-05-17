# Changelog

## [0.1.1] - 2026-05-17

First CurseForge release. No gameplay-affecting changes from `0.1.0`.

### Added
- CurseForge release pipeline (`.pkgmeta` + GitHub Actions) — tag pushes now auto-publish to CurseForge.

## [0.1.0] - 2026-05-16

Initial release. Target client: WoW Retail Patch 12.0.5 (Interface `120005`).

### Added
- Inline `[X]` button on each saved loadout row in the Blizzard talent loadout dropdown. Shift-click to delete.
- Active loadout's `[X]` is desaturated and not clickable, with a tooltip explaining the user must switch first.
- `Manage` button on the talent frame opens a bulk-delete window with multi-select, `Select All`, and `Delete Selected`.
- Only combat loadouts for the current specialization are shown; profession/Dragonriding loadouts are excluded.
- Bulk-delete suppresses Blizzard's per-delete refresh churn while it runs, then refreshes once at the end.
