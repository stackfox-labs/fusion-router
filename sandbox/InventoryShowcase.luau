local function mountInventoryShowcase(packages, parent)
    local Fusion = require(packages.Fusion)
    local Router = require(packages.FusionRouter)

    local Children = Fusion.Children
    local OnEvent = Fusion.OnEvent
    local rootScope = Fusion:scoped()
    local toastVisible = rootScope:Value(false)
    local toastText = rootScope:Value("Welcome to FusionRouter")

    local function textButton(scope, layoutOrder, text, callback)
        return scope:New "TextButton" {
            AutoButtonColor = true,
            BackgroundColor3 = Color3.fromRGB(28, 32, 38),
            LayoutOrder = layoutOrder,
            Size = UDim2.fromOffset(240, 42),
            Text = text,
            TextColor3 = Color3.new(1, 1, 1),

            [OnEvent "Activated"] = callback,
        }
    end

    local function stackFrame(scope, children)
        return scope:New "Frame" {
            BackgroundColor3 = Color3.fromRGB(11, 15, 20),
            Size = UDim2.fromScale(1, 1),

            [Children] = {
                scope:New "UIPadding" {
                    PaddingLeft = UDim.new(0, 32),
                    PaddingTop = UDim.new(0, 32),
                },
                scope:New "UIListLayout" {
                    Padding = UDim.new(0, 12),
                    SortOrder = Enum.SortOrder.LayoutOrder,
                },
                children,
            },
        }
    end

    local function MainMenuScreen(ctx)
        local scope = ctx.scope

        return stackFrame(scope, {
            scope:New "TextLabel" {
                AutomaticSize = Enum.AutomaticSize.XY,
                BackgroundTransparency = 1,
                LayoutOrder = 1,
                Text = "Main Menu",
                TextColor3 = Color3.new(1, 1, 1),
                TextSize = 28,
            },
            textButton(scope, 2, "Open Inventory", function()
                ctx.push("Inventory", {
                    category = "Weapons",
                })
            end),
            textButton(scope, 3, "Open Shop", function()
                ctx.push("Shop", {
                    tab = "Featured",
                })
            end),
            textButton(scope, 4, "Reset To Main Menu", function()
                ctx.reset("MainMenu")
            end),
        })
    end

    local function InventoryScreen(ctx)
        local scope = ctx.scope
        local draft = scope:Value("Sword")
        local count = scope:Value(0)

        return stackFrame(scope, {
            scope:New "TextLabel" {
                AutomaticSize = Enum.AutomaticSize.XY,
                BackgroundTransparency = 1,
                LayoutOrder = 1,
                Text = "Inventory category: " .. tostring(ctx.params.category),
                TextColor3 = Color3.new(1, 1, 1),
                TextSize = 24,
            },
            scope:New "TextLabel" {
                AutomaticSize = Enum.AutomaticSize.XY,
                BackgroundTransparency = 1,
                LayoutOrder = 2,
                Text = scope:Computed(function(use)
                    return ("Draft item: %s | Count: %d"):format(use(draft), use(count))
                end),
                TextColor3 = Color3.fromRGB(194, 204, 214),
            },
            textButton(scope, 3, "Increment Count", function()
                count:set(Fusion.peek(count) + 1)
                toastText:set("Inventory count updated")
                toastVisible:set(true)
            end),
            textButton(scope, 4, "Inspect Draft Item", function()
                ctx.pushModal("ItemDetails", {
                    itemId = Fusion.peek(draft),
                })
            end),
            textButton(scope, 5, "Replace With Shop", function()
                ctx.replace("Shop", {
                    tab = "Deals",
                })
            end),
            textButton(scope, 6, "Back", function()
                ctx.back()
            end),
        })
    end

    local function ShopScreen(ctx)
        local scope = ctx.scope

        return stackFrame(scope, {
            scope:New "TextLabel" {
                AutomaticSize = Enum.AutomaticSize.XY,
                BackgroundTransparency = 1,
                LayoutOrder = 1,
                Text = "Shop tab: " .. tostring(ctx.params.tab),
                TextColor3 = Color3.new(1, 1, 1),
                TextSize = 24,
            },
            textButton(scope, 2, "Confirm Purchase", function()
                ctx.pushModal("PurchaseConfirm", {
                    itemId = "bundle_01",
                })
            end),
            textButton(scope, 3, "Close Shop", function()
                ctx.close()
            end),
        })
    end

    local function modalFrame(scope, title, buttons)
        return scope:New "Frame" {
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundColor3 = Color3.fromRGB(245, 242, 232),
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
                    TextColor3 = Color3.fromRGB(26, 28, 32),
                },
                buttons,
            },
        }
    end

    local function ItemDetailsModal(ctx)
        local scope = ctx.scope

        return modalFrame(scope, "Inspecting item: " .. tostring(ctx.params.itemId), {
            textButton(scope, 2, "Close", function()
                ctx.close()
            end),
        })
    end

    local function PurchaseConfirmModal(ctx)
        local scope = ctx.scope

        return modalFrame(scope, "Purchase item: " .. tostring(ctx.params.itemId), {
            textButton(scope, 2, "Accept Purchase", function()
                toastText:set("Purchase accepted for " .. tostring(ctx.params.itemId))
                toastVisible:set(true)
                ctx.close()
            end),
            textButton(scope, 3, "Cancel", function()
                ctx.close()
            end),
        })
    end

    local function ToastOverlay(ctx)
        local scope = ctx.scope

        return scope:New "Frame" {
            AnchorPoint = Vector2.new(0.5, 0),
            BackgroundColor3 = Color3.fromRGB(240, 188, 94),
            Position = UDim2.fromScale(0.5, 0.04),
            Size = UDim2.fromOffset(300, 52),

            [Children] = {
                scope:New "TextLabel" {
                    BackgroundTransparency = 1,
                    Size = UDim2.fromScale(1, 1),
                    Text = rootScope:Computed(function(use)
                        return "Toast: " .. use(toastText)
                    end),
                    TextColor3 = Color3.fromRGB(30, 24, 18),
                },
            },
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
                    toastText:set("Inventory opened")
                    toastVisible:set(true)
                end,
                onExit = function()
                    toastVisible:set(false)
                end,
            }),
            Shop = Router.screen(ShopScreen, {
                validateParams = function(params)
                    assert(type(params.tab) == "string", "tab must be a string")
                end,
            }),
        },
        modals = {
            ItemDetails = Router.modal(ItemDetailsModal, {
                barrierDismiss = true,
                transition = "fadeScaleIn",
            }),
            PurchaseConfirm = Router.modal(PurchaseConfirmModal, {
                barrierDismiss = true,
                transition = "fadeScaleIn",
            }),
        },
        overlays = {
            Toasts = Router.overlay(ToastOverlay, {
                persistent = false,
                visible = toastVisible,
                onExit = function()
                    toastText:set("Welcome to FusionRouter")
                end,
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
        Name = "FusionRouterInventoryShowcase",
        ResetOnSpawn = false,
    }
    local app = Router.App(rootScope, router)
    app.Parent = screenGui
    screenGui.Parent = parent

    return function()
        rootScope:doCleanup()
    end
end

return mountInventoryShowcase
