# Sandbox Examples

These sandbox modules are written against the `FusionRouter` API and are meant to be mounted into a Roblox `PlayerGui` during local experimentation.

Each module exports:

```lua
(packages: Folder, parent: Instance) -> () -> ()
```

Pass a `Packages` folder that contains `Fusion` and `FusionRouter`, plus a GUI parent such as `Players.LocalPlayer.PlayerGui`. The returned function cleans up the mounted example.

## InventoryShowcase

Exercises:

- screen push, replace, back, and reset
- screen params
- `keepAlive` and `singleton`
- modal open and close
- overlay visibility
- lifecycle-driven toast behavior
- global and per-route transitions

## HudShowcase

Exercises:

- persistent HUD overlays
- modal stacking
- `closeAllModals`
- `ctx.close()`
- pause/settings style flows
- overlay visibility driven by Fusion values
- retained and destroy screen behavior together
