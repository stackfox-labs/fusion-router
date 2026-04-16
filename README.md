# FusionRouter

<p align="center">
  <img src="./assets/FusionRouterBanner.png" width="540" />
</p>

FusionRouter is a navigation library for Roblox UI built with Fusion.

It provides screens, modals, overlays, route params, lifecycle hooks, retention, and transitions.

## Installation

FusionRouter is still in early development, but you can install it by cloning the repository and using it as a local package in your Roblox project.

## Quick Start

```lua
local Fusion = require(Packages.Fusion)
local Router = require(Packages.FusionRouter)

local Children = Fusion.Children
local OnEvent = Fusion.OnEvent

local function MainMenu(ctx)
    return ctx.scope:New "Frame" {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,

        [Children] = {
            ctx.scope:New "TextButton" {
                Text = "Open Inventory",
                Size = UDim2.fromOffset(220, 44),
                [OnEvent "Activated"] = function()
                    ctx.push("Inventory", {
                        category = "Weapons",
                    })
                end,
            },
        },
    }
end

local function Inventory(ctx)
    return ctx.scope:New "Frame" {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,

        [Children] = {
            ctx.scope:New "TextLabel" {
                BackgroundTransparency = 1,
                Text = "Inventory: " .. tostring(ctx.params.category),
            },

            ctx.scope:New "TextButton" {
                Position = UDim2.fromOffset(0, 48),
                Size = UDim2.fromOffset(220, 44),
                Text = "Inspect Item",
                [OnEvent "Activated"] = function()
                    ctx.pushModal("ItemDetails", {
                        itemId = "sword_01",
                    })
                end,
            },

            ctx.scope:New "TextButton" {
                Position = UDim2.fromOffset(0, 96),
                Size = UDim2.fromOffset(220, 44),
                Text = "Back",
                [OnEvent "Activated"] = function()
                    ctx.back()
                end,
            },
        },
    }
end

local function ItemDetails(ctx)
    return ctx.scope:New "Frame" {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(320, 220),

        [Children] = {
            ctx.scope:New "TextLabel" {
                BackgroundTransparency = 1,
                Text = "Item: " .. tostring(ctx.params.itemId),
            },

            ctx.scope:New "TextButton" {
                Position = UDim2.fromOffset(0, 48),
                Size = UDim2.fromOffset(180, 40),
                Text = "Close",
                [OnEvent "Activated"] = function()
                    ctx.close()
                end,
            },
        },
    }
end

local router = Router.create({
    initialScreen = "MainMenu",

    screens = {
        MainMenu = Router.screen(MainMenu),
        Inventory = Router.screen(Inventory, {
            retention = "keepAlive",
        }),
    },

    modals = {
        ItemDetails = Router.modal(ItemDetails),
    },

    transitions = {
        screenPush = "slideLeft",
        screenPop = "slideRight",
        modalOpen = "fadeScaleIn",
        modalClose = "fadeOut",
    },
})

local scope = Fusion:scoped()
local app = Router.App(scope, router)
app.Parent = game.Players.LocalPlayer.PlayerGui
```

## Navigation

```lua
router:push("Inventory", {
    category = "Weapons",
})

router:replace("Shop")
router:back()
router:reset("MainMenu")
```

## Modals

```lua
router:pushModal("ItemDetails", {
    itemId = "sword_01",
})

router:popModal()
router:closeAllModals()
```

Inside a route context:

```lua
ctx.close()
```

## Route Params

Pass params when navigating:

```lua
router:push("Inventory", {
    category = "Weapons",
})
```

Read them inside a route:

```lua
local function Inventory(ctx)
    print(ctx.params.category)
end
```

## Retention

Screen retention controls what happens when leaving a screen.

* `destroy` — unmount the screen when it is left
* `keepAlive` — keep the screen mounted and preserve its state
* `singleton` — reuse one persistent screen instance

```lua
Inventory = Router.screen(Inventory, {
    retention = "keepAlive",
})
```

## Lifecycle Hooks

```lua
Inventory = Router.screen(Inventory, {
    onEnter = function(ctx)
        print("entered inventory")
    end,

    onExit = function(ctx)
        print("left inventory")
    end,

    onPause = function(ctx)
        print("inventory hidden")
    end,

    onResume = function(ctx)
        print("inventory resumed")
    end,
})
```

## Transitions

```lua
local router = Router.create({
    transitions = {
        screenPush = "slideLeft",
        screenPop = "slideRight",
        modalOpen = "fadeScaleIn",
        modalClose = "fadeOut",
    },

    screens = {
        MainMenu = Router.screen(MainMenu),
    },
})
```

## Route Options

### `Router.screen(component, options?)`

* `retention`
* `enterTransition`
* `exitTransition`
* `canEnter`
* `canExit`
* `onEnter`
* `onExit`
* `onPause`
* `onResume`
* `validateParams`

### `Router.modal(component, options?)`

* `transition`
* `barrierDismiss`
* `canEnter`
* `canExit`
* `onEnter`
* `onExit`
* `validateParams`

### `Router.overlay(component, options?)`

* `persistent`
* `visible`
* `onEnter`
* `onExit`

## License

MIT License. See [LICENSE](./LICENSE) for details.
