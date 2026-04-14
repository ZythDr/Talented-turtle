# Talented-turtle

Backport of Talented from [WotLK 3.3.5](https://github.com/bkader/Talented_WoTLK) to Vanilla 1.12.1, specifically adapted for Turtle WoW.

**Fully supports Turtle WoW patch 1.18.1**, including inspection of other players' talents.

Inspect talent fetching has been restored without relying on clicking the Inspect talents tab, and compatibility with `SuperInspect` / `SuperInspect_UI` is working again.

<img width="1154" height="713" alt="image" src="https://github.com/user-attachments/assets/a3e2964b-4ee2-4b95-a171-76a4785db829" />


## Changelog

### v3.1.3
- Fixed the talent data scraper so it once again discovers and writes all three talent trees per class.
- Removed legacy unused calculator-generator files from the repository.

### v3.1.2-r20260404-2
- Restored the `Dim tree backgrounds` option by returning to the stable direct background tinting path.
- Restored automatic cleanup of empty saved templates: templates with `0` spent points are now deleted when you switch away from them or close Talented.

### v3.1.1-r20260404-1
- Restored the pre-tab-click inspect flow for Turtle WoW 1.18.1 by preloading inspect support and sending the live inspect request directly.
- Updated Talented's inspect transport to use Turtle WoW 1.18.1's `INSTalentShow` request path instead of the stale pre-patch `INSShowTalents` path.
- Talented now maintains its own inspect talent cache from `CHAT_MSG_ADDON`, instead of depending on Blizzard's private inspect cache.
- Restored compatibility with `SuperInspect` and `SuperInspect_UI`.



<details>
<summary>Previous Changes / Full Changelog</summary>

### v3.1-r20260323-1
- Fixed player inspect being completely non-functional in Turtle WoW 1.18.1 — talents now load and display correctly when inspecting other players.
- Added `TriggerInspectTab4Preload()` Workaround: when `InspectFrame` opens, click `InspectFrameTab4` to trigger a talent data request, then return to `InspectFrameTab1` on next frame.  
- Added **Debug Inspect** option in settings: prints the full inspect pipeline state (`inspectCom.SPEC` / `turtleInspectSpec` contents and `useTurtleInspect` flag) to chat at each stage, for troubleshooting inspect issues.

### v3.1-r20260322-1
- Fixed player inspect being completely broken after Turtle WoW patch 1.18.1.
  - Patch 1.18.1 inserted an **Arena** tab at `InspectFrameTab3`, shifting the Talents tab from Tab3 to Tab4. All of Talented's inspect hooks were hardcoded to `InspectFrameTab3`, causing three simultaneous failures: clicking Talents never sent the whisper request, the Talented button was hidden when Talents was active (and shown for Arena), and the hook sentinel fired on the wrong tab.
  - Added `Talented.GetInspectTalentsTab()` which scans `InspectFrameTab3`–`Tab8` for the tab whose text matches the `TALENTS` locale string (with Tab4→Tab3 as a name-blind fallback), so the correct tab is always found regardless of future tab insertions.
  - `HookInspectUI`/`UnhookInspectUI` now use `GetInspectTalentsTab()` and store the hooked tab reference so `UnhookInspectUI` always restores the correct tab.
  - `UpdateInspectButtons` now uses `GetInspectTalentsTab()` to determine Talented button visibility.
- Removed the "Use Inspect tab" option (`inspect_open_as_tab`). The old `InspectFrameTab4` Talented tab conflicted with Turtle WoW's own tabs after 1.18.1. The inspect frame now exclusively uses the floating Talented button (`TalentedInspectOpenButton`).
- When the Talented button is clicked before the whisper response arrives, the view now auto-opens as soon as `INSTalentEND` is received, instead of requiring a second click.

### v3.0-r20260320
- Updated talent data for Turtle WoW Patch 1.18.1.
- Replaced the old manual ClassData generation workflow with a fully automated scraper (`tools/fetch_talent_data.py`).
  - Discovers all 27 talent trees from `talent-builder.dev/collections/1.18.1` automatically.
  - Fetches each tree and extracts talent data (name, icon, description, spell IDs, prerequisites) from the site's React server-component HTML.
  - Writes one `ClassData/<CLASS>.lua` per class, directly replacing the old hand-maintained files.
  - Run with `python3 tools/fetch_talent_data.py` (or pass a collection slug: `python3 tools/fetch_talent_data.py 1.18.2`).
- ClassData files now include `icon` and `req` (prerequisite) fields sourced from the calculator, where previously these came from an in-game `/talented dumpdata` capture.
- Removed the old `CalculatorData.lua` generator workflow entirely. The `ClassData/*.lua` files are now the single authoritative data source.
- Fixed tooltip descriptions being blank for new 1.18.1 talents whose spell IDs are not yet in the calculator database. Sequential placeholder IDs (e.g. `{1, 2}`) are now correctly detected and bypassed so `GetTalentDesc` falls through to the description text from ClassData.

  
### v2.5-r20260310-1
- Added calculator-backed talent data so template and inspected tooltips can use class-specific descriptions and rank spell IDs from Turtle’s talent calculator data.
- Reduced reliance on the old spell-ID resolver for non-live talent views, improving tooltip accuracy for shared-name talents such as `Lightning Reflexes`.
- Added a configurable `Show all ranks modifier` option with `Disabled`, `Alt`, `Shift`, and `Ctrl` choices.
- Replaced the hardcoded `Alt` all-ranks tooltip behavior with the new configurable modifier setting.
- Kept live player talent tooltips on the native client path while improving fallback selection for templates and inspected talents.
- Performed a small internal cleanup in `Spell.lua` by centralizing generated talent-data lookup logic.


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
