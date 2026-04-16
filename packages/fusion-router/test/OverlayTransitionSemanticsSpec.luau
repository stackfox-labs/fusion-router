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
    name = "overlay and transition semantics keep overlay visibility reactive and delay unmounts until transition completion",
    run = function()
        local scope = fusion:scoped()
        local scheduler = createScheduler()
        local hudVisible = fusion:scoped():Value(false)
        local toastVisible = fusion:scoped():Value(false)
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
            },
            modals = {
                Confirm = Router.modal(function()
                    return {
                        id = "confirm-instance",
                    }
                end),
            },
            overlays = {
                HUD = Router.overlay(function()
                    return {
                        id = "hud-instance",
                    }
                end, {
                    visible = hudVisible,
                }),
                Toasts = Router.overlay(function()
                    return {
                        id = "toast-instance",
                    }
                end, {
                    persistent = false,
                    visible = toastVisible,
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
        local overlayLayer = getLayer(app, "FusionRouterOverlays")

        local hudNode = findRouteNode(overlayLayer, "HUD")

        assert(
            hudNode ~= nil
                and hudNode.Visible == false
                and hudNode.Attributes.RouteState == "hidden",
            "Persistent hidden overlays should stay rendered but hidden in the overlay layer"
        )
        assert(
            findRouteNode(overlayLayer, "Toasts") == nil,
            "Non-persistent hidden overlays should not render until visible"
        )

        hudVisible:set(true)
        toastVisible:set(true)

        hudNode = findRouteNode(overlayLayer, "HUD")
        local toastNode = findRouteNode(overlayLayer, "Toasts")

        assert(
            hudNode ~= nil and hudNode.Visible == true and hudNode.Attributes.RouteState == "active",
            "Persistent overlays should flip visible without remounting their render node"
        )
        assert(
            toastNode ~= nil
                and toastNode.Visible == true
                and toastNode.Attributes.RouteState == "active",
            "Non-persistent overlays should render when their reactive visible source turns true"
        )

        toastVisible:set(false)
        assert(
            findRouteNode(overlayLayer, "Toasts") == nil,
            "Non-persistent overlays should disappear from the overlay layer when hidden again"
        )

        router:push("Inventory")

        local inventoryNode = findRouteNode(screenLayer, "Inventory")

        assert(
            inventoryNode ~= nil
                and inventoryNode.Attributes.RouteState == "entering"
                and inventoryNode.Attributes.TransitionName == "slideLeft",
            "Entering screens should expose transition state and preset metadata in Router.App"
        )
        assert(
            scheduler.pendingCount() > 0,
            "Screen enter transitions should stay scheduled until completion"
        )

        scheduler.flushAll()
        inventoryNode = findRouteNode(screenLayer, "Inventory")
        assert(
            inventoryNode ~= nil
                and inventoryNode.Attributes.RouteState == "active"
                and inventoryNode.Attributes.TransitionName == nil,
            "Completed screen transitions should settle to active state"
        )

        router:pushModal("Confirm")
        local confirmNode = findRouteNode(modalLayer, "Confirm")

        assert(
            confirmNode ~= nil
                and confirmNode.Attributes.RouteState == "entering"
                and confirmNode.Attributes.TransitionName == "fade",
            "Entering modals should expose transition state and preset metadata in Router.App"
        )

        scheduler.flushAll()
        router:popModal()
        confirmNode = findRouteNode(modalLayer, "Confirm")

        assert(
            confirmNode ~= nil
                and confirmNode.Attributes.RouteState == "exiting"
                and confirmNode.Attributes.TransitionName == "fadeOut",
            "Exiting modals should remain rendered until their delayed unmount completes"
        )

        scheduler.flushAll()
        assert(
            findRouteNode(modalLayer, "Confirm") == nil,
            "Flushing modal exit transitions should remove the modal render node"
        )

        router:back()
        inventoryNode = findRouteNode(screenLayer, "Inventory")

        assert(
            inventoryNode ~= nil
                and inventoryNode.Attributes.RouteState == "exiting"
                and inventoryNode.Attributes.TransitionName == "slideRight",
            "Exiting screens should remain rendered until their delayed unmount completes"
        )

        scheduler.flushAll()
        assert(
            findRouteNode(screenLayer, "Inventory") == nil,
            "Flushing screen exit transitions should remove the exited screen render node"
        )
    end,
}
