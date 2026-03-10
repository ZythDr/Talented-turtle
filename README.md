# Talented-turtle

Backport of Talented from 3.3.5 to 1.12.1, specifically adapted for Turtle WoW.

<img width="1154" height="713" alt="image" src="https://github.com/user-attachments/assets/a3e2964b-4ee2-4b95-a171-76a4785db829" />


## Changelog

### v2.5-r20260310-1
- Added calculator-backed talent data so template and inspected tooltips can use class-specific descriptions and rank spell IDs from Turtle’s talent calculator data.
- Reduced reliance on the old spell-ID resolver for non-live talent views, improving tooltip accuracy for shared-name talents such as `Lightning Reflexes`.
- Added a configurable `Show all ranks modifier` option with `Disabled`, `Alt`, `Shift`, and `Ctrl` choices.
- Replaced the hardcoded `Alt` all-ranks tooltip behavior with the new configurable modifier setting.
- Kept live player talent tooltips on the native client path while improving fallback selection for templates and inspected talents.
- Performed a small internal cleanup in `Spell.lua` by centralizing generated talent-data lookup logic.

<details>
<summary>Full Changelog</summary>

### v2.4-r20260305-1
- Fixed talent tooltips being wrong for other players who click a talent chat link (self-describing `EncodeCustomTalentLink` encoding — no sender-side session state required).
- Fixed talent descriptions missing for non-player classes: `MergeEmbeddedSpellIDs` now backfills real DBC spell IDs from `Data.lua` into ClassData override tables after `ApplyRuntimeClassOverride`, so `GetTalentSpellID` returns valid IDs without requiring a live nampower scan.
- Fixed DBC developer-note strings (`Designer Note: only purpose of this aura is to...`) leaking as talent descriptions. Added a fourth filter layer: `GetTalentDesc` now checks `IsSuspiciousTalentSpellText` before returning the nampower `recDesc`, silently skipping helper-spell tooltip text that exists due to internal `effectTriggerSpell`/`modalNextSpell` DBC spell chains.
- Fixed `SetEnchantSpell` in `CreateSpellLinkTooltip` not checking `SUPERWOW_VERSION` (was only checking `SetHyperlink` presence, inconsistent with `Tips.lua`).
- Added `Talented.hasNamepower` and `Talented.hasSuperWoW` flags set once at load time using each DLL's official probe (`GetNampowerVersion()` and `SUPERWOW_VERSION` respectively).
- Improved `ResolveTemplateSpellIDs` error messages to distinguish "nampower not installed" from "older nampower version without `GetSpellRecField`".

### v2.3-r20260221-1
- Improved inspect-template point budgeting UX:
  - `Remaining points` now uses the inspected player level budget.
  - top-right spent/max counter now also uses the inspected player level budget.
  - `Remaining points` is hidden for non-live, non-inspect templates.
- Fixed tree title layering to stay above tree artwork with the current HIGH-strata frame model.
- Fixed spell-record tooltip scoring crash (`attempt to call a nil value` at `Talented.lua:813`).

### v2.2-r20260219-2
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

</details>
