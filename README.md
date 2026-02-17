# Talented-turtle

Backport of Talented from 3.3.5 to 1.12.1, specifically adapted for Turtle WoW.

## Notes

- This addon requires SuperWoW and nampower to function properly.
- Vanilla/Turtle compatibility work is in progress and tracked in `TODO.md`.
- Addon folder name: `Talented-turtle`
- TOC file: `Talented-turtle.toc`

## Changelog

### v2.0-r20260217-4
- Major internal refactor: split monolithic `Talented.lua` into dedicated modules (`Core`, `Spell`, `View`, `EditMode`, `Check`, `Encode`, `ViewMode`, `Tips`, `Apply`, `Learn`, `Chat`, `Comm`, `InspectUI`).
- Preserved Vanilla 1.12 compatibility while modularizing (added safe wrappers/fallbacks where required for missing talent-group APIs).
- Fixed post-refactor regressions around template/action menus and active template guards.
- Improved internal cache bridge handling for spell record tooltip parsing after module split.

### v1.5-r20260217-3
- Added/expanded inspect integration with improved behavior in Turtle inspect flows and SuperInspect compatibility.
- Added "Open in Talented" integration path from inspect contexts.
- Added remaining points display and polished edit-state behavior when talents are immutable.
- Multiple stability improvements for apply/target overlays and template editing UX.

### v1.4-r20260217-2
- Reworked template send transport for Turtle WoW using robust addon comm paths.
- Improved send/receive handling and confirmation flows for shared templates.
- Continued fixes for menu interaction reliability and popup handling.

### v1.3 series (`v1.3-20260216-*`)
- Stabilized import/export StaticPopup dialogs (layout, focus, data capture, accept behavior).
- Improved Escape key close behavior for Talented and Talented dialogs.
- Fixed target/apply reliability and learn tooltip behavior.
- Improved hyperlink tooltip parity and metadata rendering.

### v1.2
- Stabilized template/menu interactions and edge-case menu refresh behavior.
- Improved frame close/open behavior and menu-state consistency.

### v1.1
- Established hard-fork versioning for Talented-turtle and renamed addon packaging to `Talented-turtle`.
- Added TODO tracking and project-specific maintenance workflow.

### Earlier Porting Work
- Ace3 dependency removal and migration to Ace2-compatible runtime path.
- Turtle/Vanilla compatibility fixes for unsupported Lua/API usage.
- Class data split into per-class files under `ClassData/`.
- Turtlecraft talents import/export support added.
- Tooltip system extensively adapted for Turtle + SuperWoW/nampower.
- Inspect template capture, class-colored menus, template colors, and UI behavior improvements.
