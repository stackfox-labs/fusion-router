# FusionRouter

FusionRouter is a navigation library for Roblox UI built with Fusion. It provides screens, modals, overlays, params, retention, and router-owned transitions.

## Installation

```toml
[dependencies]
Fusion = "elttob/fusion@0.3.0"
FusionRouter = "stackfox-labs/fusion-router@0.1.0"
```

```lua
local Fusion = require(Packages.Fusion)
local Router = require(Packages.FusionRouter)
```

## Basic Usage

```lua
local Fusion = require(Packages.Fusion)
local Router = require(Packages.FusionRouter)

local Children = Fusion.Children
local OnEvent = Fusion.OnEvent
local appScope = Fusion:scoped()
local toastVisible = appScope:Value(false)

local function MainMenuScreen(ctx)
    return ctx.scope:New "Frame" {
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),

        [Children] = {
            ctx.scope:New "TextButton" {
                Size = UDim2.fromOffset(220, 44),
                Text = "Open Inventory",

                [OnEvent "Activated"] = function()
                    ctx.push("Inventory", {
                        category = "Weapons",
                    })
                end,
            },
        },
    }
end

local function InventoryScreen(ctx)
    local draftCount = ctx.scope:Value(0)

    return ctx.scope:New "Frame" {
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),

        [Children] = {
            ctx.scope:New "TextLabel" {
                AutomaticSize = Enum.AutomaticSize.XY,
                BackgroundTransparency = 1,
                Text = ctx.scope:Computed(function(use)
                    return ("Inventory %s | Draft count %d"):format(
                        tostring(ctx.params.category),
                        use(draftCount)
                    )
                end),
            },

            ctx.scope:New "TextButton" {
                Position = UDim2.fromOffset(0, 56),
                Size = UDim2.fromOffset(220, 44),
                Text = "Inspect Item",

                [OnEvent "Activated"] = function()
                    draftCount:set(Fusion.peek(draftCount) + 1)
                    ctx.pushModal("ItemDetails", {
                        itemId = "sword_01",
                    })
                end,
            },
        },
    }
end

local function ItemDetailsModal(ctx)
    return ctx.scope:New "Frame" {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(320, 220),
    }
end

local function ToastOverlay(ctx)
    return ctx.scope:New "Frame" {
        AnchorPoint = Vector2.new(0.5, 0),
        BackgroundColor3 = Color3.fromRGB(245, 197, 92),
        Position = UDim2.fromScale(0.5, 0.04),
        Size = UDim2.fromOffset(280, 44),
    }
end

local router = Router.create({
    initialScreen = "MainMenu",

    screens = {
        MainMenu = Router.screen(MainMenuScreen, {
            retention = "singleton",
        }),

        Inventory = Router.screen(InventoryScreen, {
            retention = "keepAlive",
            validateParams = function(params)
                assert(type(params.category) == "string", "category must be a string")
            end,
            onEnter = function()
                toastVisible:set(true)
            end,
            onExit = function()
                toastVisible:set(false)
            end,
        }),
    },

    modals = {
        ItemDetails = Router.modal(ItemDetailsModal, {
            barrierDismiss = true,
            transition = "fadeScaleIn",
        }),
    },

    overlays = {
        Toasts = Router.overlay(ToastOverlay, {
            persistent = false,
            visible = toastVisible,
        }),
    },

    transitions = {
        screenPush = "slideLeft",
        screenPop = "slideRight",
        modalOpen = "fadeScaleIn",
        modalClose = "fadeOut",
    },
})

local app = Router.App(appScope, router)
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

## Route Options

`Router.screen(component, options?)`

- `retention = "destroy" | "keepAlive" | "singleton"`
- `enterTransition`
- `exitTransition`
- `canEnter`
- `canExit`
- `onEnter`
- `onExit`
- `onPause`
- `onResume`
- `validateParams`

`Router.modal(component, options?)`

- `transition`
- `barrierDismiss`
- `canEnter`
- `canExit`
- `onEnter`
- `onExit`
- `validateParams`

`Router.overlay(component, options?)`

- `persistent`
- `visible`
- `onEnter`
- `onExit`

## License

MIT
