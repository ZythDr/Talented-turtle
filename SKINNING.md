# Talented-turtle Skinning Notes

This file documents stable hooks and frame targets intended for external skinners
such as `pfUI-addonskinner`.

Talented does not apply any external skin itself. Use this as a reference layer.

## Runtime API

Talented now exposes a lightweight skinning API:

- `Talented:RegisterSkinCallback(id, fn)`
- `Talented:UnregisterSkinCallback(id)`
- `Talented:RunSkinCallbacks(reason)`
- `Talented:GetSkinTargets()`

### `RegisterSkinCallback`

Register once from your skinner addon:

```lua
if Talented and Talented.RegisterSkinCallback then
  Talented:RegisterSkinCallback("pfui_addonskinner", function(addon, reason)
    -- Re-scan and skin whenever Talented rebuilds UI parts.
    local targets = addon:GetSkinTargets()
    -- Your skinning logic here.
  end)
end
```

Callbacks are fired on:

- `"base-created"`
- `"view-set-class"`
- `"view-set-template"`

## `GetSkinTargets()` structure

Returns a table with raw widget references:

- `frames`
- `buttons`
- `edits`
- `fontStrings`
- `textures`
- `treeFrames`
- `talentButtons`

All lists are deduplicated and safe to iterate with `ipairs`.

## Recommended skinning flow

1. Ensure Talented is loaded.
2. Register callback once.
3. On callback:
   - get `targets = Talented:GetSkinTargets()`
   - strip/retexture `targets.frames` and `targets.treeFrames`
   - reskin button states in `targets.buttons` + `targets.talentButtons`
   - apply font styling to `targets.fontStrings`
   - apply texture replacements to `targets.textures`

## Important notes

- Many Talented child widgets are unnamed by design.
- Do not rely on global frame names except top-level frames (`TalentedFrame`, etc).
- Prefer the API lists over scanning `_G`.
- `GetSkinTargets()` may return an empty set before Talented creates base/view frames.

## Stable top-level references

- `Talented`
- `Talented.base` (after creation)
- `Talented.views` (view objects)

Use API methods as primary integration points to minimize breakage after refactors.
