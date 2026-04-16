local Router = require("../src")
local TestRouter = require("./TestRouter")

local createRouter = TestRouter.createRouter
local fusion = TestRouter.fusion

local function createScheduler()
    local queue = {}
    local nextId = 0
    local scheduler = {}

    function scheduler.delay(duration, callback)
        nextId += 1

        local handle = {
            callback = callback,
            cancelled = false,
            duration = duration,
            id = nextId,
        }

        table.insert(queue, handle)

        return handle
    end

    function scheduler.cancel(handle)
        if handle ~= nil then
            handle.cancelled = true
        end
    end

    function scheduler.flushNext()
        while #queue > 0 do
            local handle = table.remove(queue, 1)

            if not handle.cancelled then
                handle.callback()

                return handle
            end
        end

        return nil
    end

    function scheduler.flushAll()
        while scheduler.flushNext() ~= nil do
            local _ = 0
        end
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

local function findBarrierNode(layer, routeName)
    for _, child in layer.Children do
        if child.Attributes.BarrierRouteName == routeName then
            return child
        end
    end

    return nil
end

return {
    name = "Router.App renders screens modals and overlays in layer order with retained and exiting state",
    run = function()
        local scope = fusion:scoped()
        local scheduler = createScheduler()
        local overlayVisible = fusion:scoped():Value(true)
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
                end, {
                    barrierDismiss = true,
                }),
            },
            overlays = {
                Toasts = Router.overlay(function()
                    return {
                        id = "toasts-instance",
                    }
                end, {
                    visible = overlayVisible,
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

        assert(type(Router.App) == "function", "Router.App should be exported")
        assert(
            app.Children[1].Attributes.LayerName == "FusionRouterScreens",
            "App should render the screen layer first"
        )
        assert(
            app.Children[2].Attributes.LayerName == "FusionRouterModals",
            "App should render the modal layer second"
        )
        assert(
            app.Children[3].Attributes.LayerName == "FusionRouterOverlays",
            "App should render the overlay layer third"
        )

        local screenLayer = getLayer(app, "FusionRouterScreens")
        local modalLayer = getLayer(app, "FusionRouterModals")
        local overlayLayer = getLayer(app, "FusionRouterOverlays")

        assert(
            findRouteNode(screenLayer, "MainMenu") ~= nil,
            "The initial screen should render into the screen layer"
        )
        assert(
            findRouteNode(overlayLayer, "Toasts") ~= nil,
            "Mounted overlays should render into the overlay layer"
        )
        assert(#modalLayer.Children == 0, "The modal layer should start empty")

        router:push("Inventory")

        local mainNode = findRouteNode(screenLayer, "MainMenu")
        local inventoryNode = findRouteNode(screenLayer, "Inventory")

        assert(mainNode ~= nil, "Retained previous screens should remain rendered")
        assert(mainNode.Visible == false, "Retained paused screens should render hidden")
        assert(
            inventoryNode.Attributes.RouteState == "entering"
                and inventoryNode.Attributes.TransitionName == "slideLeft",
            "New pushed screens should render with the entering transition metadata"
        )

        scheduler.flushAll()
        inventoryNode = findRouteNode(screenLayer, "Inventory")
        assert(
            inventoryNode.Attributes.RouteState == "active"
                and inventoryNode.Attributes.TransitionName == nil,
            "Entering screens should settle to active after their transition completes"
        )

        router:pushModal("Confirm")

        local barrierNode = findBarrierNode(modalLayer, "Confirm")
        local confirmNode = findRouteNode(modalLayer, "Confirm")

        assert(barrierNode ~= nil, "Active modals should render a router-owned barrier")
        assert(
            barrierNode.Attributes.BarrierDismiss == true,
            "Barrier dismissibility should follow modal config"
        )
        assert(confirmNode ~= nil, "Active modals should render into the modal layer")

        barrierNode.OnActivated()
        confirmNode = findRouteNode(modalLayer, "Confirm")

        assert(
            confirmNode ~= nil and confirmNode.Attributes.RouteState == "exiting",
            "Dismissed modals should remain rendered long enough to complete exit transitions"
        )

        scheduler.flushAll()
        assert(#modalLayer.Children == 0, "Exited modals should unmount after their transition")

        router:back()

        inventoryNode = findRouteNode(screenLayer, "Inventory")
        mainNode = findRouteNode(screenLayer, "MainMenu")

        assert(
            inventoryNode ~= nil and inventoryNode.Attributes.RouteState == "exiting",
            "Back should keep the popped screen rendered while its exit transition runs"
        )
        assert(
            mainNode ~= nil
                and mainNode.Attributes.RouteState == "active"
                and mainNode.Visible == true,
            "Back should reactivate the previous retained screen in place"
        )

        scheduler.flushAll()
        assert(
            findRouteNode(screenLayer, "Inventory") == nil,
            "Exited screens should be removed from the render layer after transition completion"
        )
    end,
}
