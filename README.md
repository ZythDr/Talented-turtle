# Talented-turtle

Backport of Talented from 3.3.5 to 1.12.1, specifically adapted for Turtle WoW.

## Notes

- This addon requires SuperWoW and nampower to function properly.
- Vanilla/Turtle compatibility work is in progress and tracked in `TODO.md`.
- Addon folder name: `Talented-turtle`
- TOC file: `Talented-turtle.toc`

## Recent Changes

- Standardized versioning to short `v1.x` format for this hard-forked Turtle branch.
- Improved Escape handling reliability (Talented frame and Talented dialogs now close consistently via `CloseSpecialWindows` flow).
- Fixed modified-click talent linking behavior when chat edit box is not active (no unintended URL popup).
- Restored Templates menu to selection-only workflow; template deletion remains via `Actions -> Delete template`.
- Reworked talent chat hyperlink handling for Turtle WoW compatibility:
  - native `talent:` transport for non-SuperWoW clickers
  - Talented-side enhanced tooltip handling when available
- Fixed stale tooltip line leakage in parser/cache paths that caused incorrect right-column metadata (e.g. phantom range/cooldown).
- Improved tooltip line rendering parity with native behavior:
  - right-column alignment via double-line rendering
  - metadata preservation for cost/range/cast/cooldown lines
  - removed `Next rank` block from chat hyperlink tooltips
- Added Turtle inspect template capture improvements (no forced Talented popup, safer inspect data handling).
- Added level-aware inspected template labels and ignored known sub-level-10 inspect targets.
- Improved menu class coloring (including modern blue shaman color).
