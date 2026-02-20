# Talented-turtle

Backport of Talented from 3.3.5 to 1.12.1, specifically adapted for Turtle WoW.

## Notes

- This addon requires SuperWoW and nampower to function properly.
- Vanilla/Turtle compatibility work is in progress and tracked in `TODO.md`.
- Addon folder name: `Talented-turtle`
- TOC file: `Talented-turtle.toc`

## Changelog

### v2.1-r20260219-1
- Fixed a runtime error in spell-record tooltip scoring (`attempt to call a nil value`).
- Improved tree title layering so talent tree headers reliably render above tree artwork with updated frame-level settings.
- Finalized layer/strata sync refinements for branch bodies, arrow tips, and talent buttons under the stabilized tree rendering model.

### v2.1-r20260218-2
- Reworked tree dimming to a unified, stable overlay path to avoid random dark/bright tile artifacts.
- Fixed chat-link spell resolution for edge cases where a linked talent could resolve to an incorrect spell tooltip.
- Added inspect-tab integration improvements and guards when inspecting players below level 10.
- Improved code documentation in regards to frame layer order as to prevent future regressions.

### v2.1-r20260218-1
- Added a new inspect integration option: `Use Inspect tab` (uses a real `InspectFrameTab4` on default Blizzard InspectFrame instead of the floating Talented button).
- Stabilized InspectFrame tab wiring for Vanilla/Turtle panel templates (fixed tab resize/signature issues and tab registration behavior).
- Improved inspect button/tab visibility switching logic between default InspectFrame and SuperInspect integration paths.
- Added a safe Vanilla fallback for missing `GetActiveTalentGroup` in inspect-open flow.
- Added a guard for sub-level-10 inspected targets: Talented now avoids opening and prints a clear informational message.

### v2.0-r20260217-6
- Stabilized Talented frame element z-order on focus swaps (prevents talent icons/branches from getting stuck above unrelated frames after foreground/background changes).
- Normalized pooled talent button parenting to the tree frame for consistent layering behavior.
- Improved Talented Options window stacking by making it open one strata above the main Talented frame.
- Updated display defaults/ranges:
  - Icon offset default: `60`
  - Icon offset range: `48..64` with step `2`
  - Frame scale max: `1.5`

### v2.0-r20260217-5
- Added a new "Dim tree backgrounds" display option.
- Reworked dimming implementation to tint tree artwork directly instead of using a black overlay texture.
- Fixed intermittent black/blocky artifacts on tree backgrounds caused by overlay clipping/transparent regions.

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
