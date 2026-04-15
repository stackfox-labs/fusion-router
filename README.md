<p align="center">
  <img src="./assets/FusionRouterBanner.png" width="540" />
</p>

A navigation and screen management library for Roblox UI built with Fusion.

FusionRouter helps you structure game interfaces using screens, modals, and navigation stacks instead of scattered state and conditionals.

---

## Features

* Screen-based navigation
* Stack-based routing (push, replace, back)
* Modal system with stacking support
* Route parameters
* Lifecycle hooks
* State retention (keep screens alive or destroy them)
* Router-controlled transitions
* Simple, game-focused API

---

## Installation

FusionRouter is still in early development, but you can install it by cloning the repository and using it as a local package in your Roblox project.

---

## Quick Example

```lua
local Fusion = require(Packages.Fusion)
local Router = require(Packages.FusionRouter)

local OnEvent = Fusion.OnEvent
local Children = Fusion.Children

local function MainMenu(ctx)
    local scope = ctx.scope
    local router = ctx.router

    return scope:New "Frame" {
        Size = UDim2.fromScale(1, 1),

        [Children] = {
            scope:New "TextButton" {
                Text = "Open Inventory",
                [OnEvent "Activated"] = function()
                    router:push("Inventory")
                end
            }
        }
    }
end

local function Inventory(ctx)
    local scope = ctx.scope
    local router = ctx.router

    return scope:New "Frame" {
        Size = UDim2.fromScale(1, 1),

        [Children] = {
            scope:New "TextButton" {
                Text = "Back",
                [OnEvent "Activated"] = function()
                    router:back()
                end
            }
        }
    }
end

local router = Router.create({
    initialScreen = "MainMenu",

    screens = {
        MainMenu = Router.screen(MainMenu),
        Inventory = Router.screen(Inventory),
    }
})

local scope = Fusion:scoped()
local app = Router.App(scope, router)
app.Parent = game.Players.LocalPlayer.PlayerGui
```

---

## Defining Screens

Screens represent full UI views.

```lua
local router = Router.create({
    initialScreen = "MainMenu",

    screens = {
        MainMenu = Router.screen(MainMenu),
        Inventory = Router.screen(Inventory, {
            retention = "keepAlive",
        }),
    }
})
```

### Retention options

* `destroy` (default) – unmount when left
* `keepAlive` – keep mounted and preserve state
* `singleton` – reuse a single persistent instance

---

## Navigation

```lua
router:push("Inventory")
router:push("Shop", { tab = "Featured" })

router:replace("MainMenu")

router:back()

router:reset("MainMenu")
```

---

## Modals

Define modals separately from screens.

```lua
local router = Router.create({
    initialScreen = "MainMenu",

    screens = {
        MainMenu = Router.screen(MainMenu),
    },

    modals = {
        ItemDetails = Router.modal(ItemDetails),
    }
})
```

Open and close modals:

```lua
router:pushModal("ItemDetails", {
    itemId = "sword_01"
})

router:popModal()
```

---

## Route Parameters

Pass data when navigating:

```lua
router:push("Inventory", {
    category = "Weapons"
})
```

Access inside a screen:

```lua
local function Inventory(ctx)
    local params = ctx.params

    print(params.category)
end
```

---

## Lifecycle Hooks

Attach lifecycle behavior to screens:

```lua
Inventory = Router.screen(InventoryScreen, {
    onEnter = function(ctx)
        print("entered inventory")
    end,

    onExit = function(ctx)
        print("left inventory")
    end,

    onPause = function(ctx)
        print("hidden")
    end,

    onResume = function(ctx)
        print("visible again")
    end,
})
```

---

## Transitions

Define global transitions:

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
    }
})
```

---

## Rendering

Mount the router into your UI:

```lua
local scope = Fusion:scoped()
local app = Router.App(scope, router)
app.Parent = game.Players.LocalPlayer.PlayerGui
```

---

## License

MIT - See [LICENSE](./LICENSE) for details.
