# TalentLoadoutDeleter

One-click and bulk-delete saved talent loadouts in World of Warcraft Retail.

## Why

Blizzard's built-in delete flow is 2–3 clicks per loadout. Cleaning up many at once gets old. TLD adds:

- A Shift-click `[X]` next to each loadout in the Blizzard talent loadout dropdown.
- A `Manage` button on the talent frame that opens a bulk-delete window with multi-select.

## How to use

1. Open your talent UI (`N` by default).
2. **Inline delete:** open the loadout dropdown — hovering a loadout row reveals an `[X]` on the right (same auto-hide style as Blizzard's edit-entry gear button). Hold **Shift** and click it to delete that loadout. The active loadout's `[X]` is greyed out; switch loadouts first to delete it.
3. **Bulk delete:** click the `Manage` button next to the search box. Check the rows you want to remove (or use `Select All`) and press `Delete Selected`. The active loadout is shown but cannot be selected.

Only combat loadouts for your current specialization are listed. Profession and Dragonriding loadouts are untouched.

## Compatibility

- Target client: **WoW Retail Patch 12.0.5** (Interface `120005`).
- No SavedVariables, no external libraries, no popup confirmations.

## License

TBD.
