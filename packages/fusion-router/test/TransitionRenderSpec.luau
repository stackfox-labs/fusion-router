local Router = require("../src")
local TestRouter = require("./TestRouter")

local createRouter = TestRouter.createRouter
local fusion = TestRouter.fusion

local function createScheduler()
    local queue = {}
    local scheduler = {}

    function scheduler.delay(duration, callback)
        local handle = {
            callback = callback,
            cancelled = false,
            duration = duration,
        }

        table.insert(queue, handle)

        return handle
    end

    function scheduler.cancel(handle)
        if handle ~= nil then
            handle.cancelled = true
        end
    end

    function scheduler.flushAll()
        while #queue > 0 do
            local handle = table.remove(queue, 1)

            if not handle.cancelled then
                handle.callback()
            end
        end
    end

    function scheduler.pendingCount()
        local count = 0

        for _, handle in queue do
            if not handle.cancelled then
                count += 1
            end
        end

        return count
    end

    return scheduler
end

local function getLayer(root, name)
    for _, child in root.Children do
        if child.Attributes.LayerName == name then
            return child
        end
    end

    error(("Expected layer %q to exist"):format(name))
end

local function findRouteNode(layer, routeName)
    for _, child in layer.Children do
        if child.Attributes.RouteName == routeName then
            return child
        end
    end

    return nil
end

return {
    name = "transition presets resolve in the app layer and delayed unmount lasts until the scheduler flushes",
    run = function()
        local scope = fusion:scoped()
        local scheduler = createScheduler()
        local router = createRouter({
            initialScreen = "MainMenu",
            screens = {
                MainMenu = Router.screen(function()
                    return {
                        id = "main-instance",
                    }
                end, {
                    retention = "keepAlive",
                }),
                Inventory = Router.screen(function()
                    return {
                        id = "inventory-instance",
                    }
                end),
                Shop = Router.screen(function()
                    return {
                        id = "shop-instance",
                    }
                end, {
                    enterTransition = "fade",
                    exitTransition = "fadeOut",
                }),
            },
            modals = {
                Confirm = Router.modal(function()
                    return {
                        id = "confirm-instance",
                    }
                end),
                Settings = Router.modal(function()
                    return {
                        id = "settings-instance",
                    }
                end, {
                    transition = "fadeScaleIn",
                }),
            },
            transitions = {
                screenPush = "slideLeft",
                screenPop = "slideRight",
                modalOpen = "fade",
                modalClose = "fadeOut",
            },
        })

        local app = Router.App(scope, router, {
            fusion = fusion,
            scheduler = scheduler,
        })
        local screenLayer = getLayer(app, "FusionRouterScreens")
        local modalLayer = getLayer(app, "FusionRouterModals")

        router:push("Inventory")

        local inventoryNode = findRouteNode(screenLayer, "Inventory")
        assert(
            inventoryNode.Attributes.TransitionName == "slideLeft"
                and inventoryNode.Attributes.TransitionPhase == "entering",
            "Global screenPush should resolve to the slideLeft preset in the app layer"
        )
        assert(
            scheduler.pendingCount() > 0,
            "Entering screen transitions should stay scheduled until the transition completes"
        )

        scheduler.flushAll()
        router:replace("Shop")

        local shopNode = findRouteNode(screenLayer, "Shop")
        assert(
            shopNode.Attributes.TransitionName == "fade",
            "Per-screen enterTransition should override the global screenPush preset"
        )

        scheduler.flushAll()
        router:back()

        shopNode = findRouteNode(screenLayer, "Shop")
        assert(
            shopNode ~= nil
                and shopNode.Attributes.RouteState == "exiting"
                and shopNode.Attributes.TransitionName == "fadeOut",
            "Per-screen exitTransition should override the global screenPop preset"
        )

        scheduler.flushAll()
        router:pushModal("Confirm")

        local confirmNode = findRouteNode(modalLayer, "Confirm")
        assert(
            confirmNode.Attributes.TransitionName == "fade",
            "Global modalOpen should resolve to the fade preset when no override exists"
        )

        scheduler.flushAll()
        router:pushModal("Settings")

        local settingsNode = findRouteNode(modalLayer, "Settings")
        assert(
            settingsNode.Attributes.TransitionName == "fadeScaleIn",
            "Per-modal transition should override the global modalOpen preset"
        )

        scheduler.flushAll()
        router:popModal()

        settingsNode = findRouteNode(modalLayer, "Settings")
        assert(
            settingsNode ~= nil
                and settingsNode.Attributes.RouteState == "exiting"
                and settingsNode.Attributes.TransitionName == "fadeScaleIn",
            "Modal close should keep the exiting modal rendered until its scheduled transition finishes"
        )

        scheduler.flushAll()
        assert(
            findRouteNode(modalLayer, "Settings") == nil,
            "Exiting modals should disappear after the transition scheduler flushes"
        )
    end,
}
