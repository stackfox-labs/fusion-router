local function mountHudShowcase(packages, parent)
    local Fusion = require(packages.Fusion)
    local Router = require(packages.FusionRouter)

    local Children = Fusion.Children
    local OnEvent = Fusion.OnEvent
    local rootScope = Fusion:scoped()
    local hudVisible = rootScope:Value(true)
    local trackerVisible = rootScope:Value(true)
    local statusText = rootScope:Value("Exploration")

    local function button(scope, layoutOrder, text, callback)
        return scope:New "TextButton" {
            AutoButtonColor = true,
            BackgroundColor3 = Color3.fromRGB(43, 64, 79),
            LayoutOrder = layoutOrder,
            Size = UDim2.fromOffset(220, 40),
            Text = text,
            TextColor3 = Color3.new(1, 1, 1),

            [OnEvent "Activated"] = callback,
        }
    end

    local function screenFrame(scope, children, backgroundColor)
        return scope:New "Frame" {
            BackgroundColor3 = backgroundColor,
            Size = UDim2.fromScale(1, 1),

            [Children] = {
                scope:New "UIPadding" {
                    PaddingLeft = UDim.new(0, 28),
                    PaddingTop = UDim.new(0, 28),
                },
                scope:New "UIListLayout" {
                    Padding = UDim.new(0, 12),
                    SortOrder = Enum.SortOrder.LayoutOrder,
                },
                children,
            },
        }
    end

    local function RootScreen(ctx)
        local scope = ctx.scope

        return screenFrame(scope, {
            scope:New "TextLabel" {
                AutomaticSize = Enum.AutomaticSize.XY,
                BackgroundTransparency = 1,
                LayoutOrder = 1,
                Text = "HUD Showcase",
                TextColor3 = Color3.new(1, 1, 1),
                TextSize = 28,
            },
            button(scope, 2, "Open Map", function()
                statusText:set("Map opened")
                ctx.push("Map")
            end),
            button(scope, 3, "Pause", function()
                statusText:set("Paused")
                ctx.pushModal("PauseMenu")
            end),
            button(scope, 4, "Toggle Tracker Overlay", function()
                trackerVisible:set(not Fusion.peek(trackerVisible))
            end),
        }, Color3.fromRGB(12, 23, 31))
    end

    local function MapScreen(ctx)
        local scope = ctx.scope
        local zoom = scope:Value(1)

        return screenFrame(scope, {
            scope:New "TextLabel" {
                AutomaticSize = Enum.AutomaticSize.XY,
                BackgroundTransparency = 1,
                LayoutOrder = 1,
                Text = scope:Computed(function(use)
                    return ("Map zoom: %d"):format(use(zoom))
                end),
                TextColor3 = Color3.new(1, 1, 1),
                TextSize = 24,
            },
            button(scope, 2, "Zoom In", function()
                zoom:set(Fusion.peek(zoom) + 1)
            end),
            button(scope, 3, "Open Settings Modal", function()
                statusText:set("Settings open")
                ctx.pushModal("Settings")
            end),
            button(scope, 4, "Back", function()
                ctx.close()
            end),
        }, Color3.fromRGB(19, 37, 51))
    end

    local function modalFrame(scope, title, buttons)
        return scope:New "Frame" {
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundColor3 = Color3.fromRGB(247, 239, 228),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromOffset(360, 240),

            [Children] = {
                scope:New "UIPadding" {
                    PaddingLeft = UDim.new(0, 20),
                    PaddingRight = UDim.new(0, 20),
                    PaddingTop = UDim.new(0, 20),
                    PaddingBottom = UDim.new(0, 20),
                },
                scope:New "UIListLayout" {
                    Padding = UDim.new(0, 12),
                    SortOrder = Enum.SortOrder.LayoutOrder,
                },
                scope:New "TextLabel" {
                    AutomaticSize = Enum.AutomaticSize.XY,
                    BackgroundTransparency = 1,
                    LayoutOrder = 1,
                    Text = title,
                    TextColor3 = Color3.fromRGB(24, 28, 34),
                },
                buttons,
            },
        }
    end

    local function PauseMenuModal(ctx)
        local scope = ctx.scope

        return modalFrame(scope, "Pause Menu", {
            button(scope, 2, "Open Settings", function()
                ctx.pushModal("Settings")
            end),
            button(scope, 3, "Resume", function()
                statusText:set("Exploration")
                ctx.close()
            end),
        })
    end

    local function SettingsModal(ctx)
        local scope = ctx.scope

        return modalFrame(scope, "Settings", {
            button(scope, 2, "Toggle HUD Overlay", function()
                hudVisible:set(not Fusion.peek(hudVisible))
            end),
            button(scope, 3, "Close All Modals", function()
                statusText:set("Exploration")
                ctx.router:closeAllModals()
            end),
            button(scope, 4, "Close", function()
                ctx.close()
            end),
        })
    end

    local function HudOverlay(ctx)
        local scope = ctx.scope

        return scope:New "Frame" {
            BackgroundColor3 = Color3.fromRGB(37, 63, 78),
            Position = UDim2.fromOffset(20, 20),
            Size = UDim2.fromOffset(260, 72),

            [Children] = {
                scope:New "UIPadding" {
                    PaddingLeft = UDim.new(0, 14),
                    PaddingTop = UDim.new(0, 10),
                },
                scope:New "UIListLayout" {
                    Padding = UDim.new(0, 6),
                    SortOrder = Enum.SortOrder.LayoutOrder,
                },
                scope:New "TextLabel" {
                    AutomaticSize = Enum.AutomaticSize.XY,
                    BackgroundTransparency = 1,
                    LayoutOrder = 1,
                    Text = "HUD active",
                    TextColor3 = Color3.new(1, 1, 1),
                },
                scope:New "TextLabel" {
                    AutomaticSize = Enum.AutomaticSize.XY,
                    BackgroundTransparency = 1,
                    LayoutOrder = 2,
                    Text = rootScope:Computed(function(use)
                        return "State: " .. use(statusText)
                    end),
                    TextColor3 = Color3.fromRGB(211, 223, 235),
                },
            },
        }
    end

    local function TrackerOverlay(ctx)
        local scope = ctx.scope

        return scope:New "Frame" {
            AnchorPoint = Vector2.new(1, 0),
            BackgroundColor3 = Color3.fromRGB(223, 190, 116),
            Position = UDim2.fromScale(1, 0),
            Size = UDim2.fromOffset(280, 88),

            [Children] = {
                scope:New "UIPadding" {
                    PaddingLeft = UDim.new(0, 16),
                    PaddingTop = UDim.new(0, 12),
                },
                scope:New "UIListLayout" {
                    Padding = UDim.new(0, 6),
                    SortOrder = Enum.SortOrder.LayoutOrder,
                },
                scope:New "TextLabel" {
                    AutomaticSize = Enum.AutomaticSize.XY,
                    BackgroundTransparency = 1,
                    LayoutOrder = 1,
                    Text = "Quest Tracker",
                    TextColor3 = Color3.fromRGB(30, 24, 18),
                },
                scope:New "TextLabel" {
                    AutomaticSize = Enum.AutomaticSize.XY,
                    BackgroundTransparency = 1,
                    LayoutOrder = 2,
                    Text = "Overlay route: " .. tostring(ctx.routeName),
                    TextColor3 = Color3.fromRGB(30, 24, 18),
                },
            },
        }
    end

    local router = Router.create({
        initialScreen = "Root",
        screens = {
            Root = Router.screen(RootScreen, {
                retention = "singleton",
            }),
            Map = Router.screen(MapScreen, {
                retention = "keepAlive",
            }),
        },
        modals = {
            PauseMenu = Router.modal(PauseMenuModal, {
                barrierDismiss = true,
                transition = "fadeScaleIn",
            }),
            Settings = Router.modal(SettingsModal, {
                barrierDismiss = true,
            }),
        },
        overlays = {
            HUD = Router.overlay(HudOverlay, {
                visible = hudVisible,
            }),
            Tracker = Router.overlay(TrackerOverlay, {
                visible = trackerVisible,
            }),
        },
        transitions = {
            screenPush = "slideLeft",
            screenPop = "slideRight",
            modalOpen = "fadeScaleIn",
            modalClose = "fadeOut",
        },
    })

    local screenGui = rootScope:New "ScreenGui" {
        IgnoreGuiInset = true,
        Name = "FusionRouterHudShowcase",
        ResetOnSpawn = false,
    }
    local app = Router.App(rootScope, router)
    app.Parent = screenGui
    screenGui.Parent = parent

    return function()
        rootScope:doCleanup()
    end
end

return mountHudShowcase
