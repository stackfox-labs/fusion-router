local Router = require("../src")

local function createFakeScope()
    local scope = {}

    function scope:New(className)
        return function(props)
            local node = {
                ClassName = className,
            }

            for key, value in props do
                node[key] = value
            end

            return node
        end
    end

    return scope
end

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
        if child.Layer == name then
            return child
        end
    end

    error(("Expected layer %q to exist"):format(name))
end

local function findRouteNode(layer, routeName)
    for _, child in layer.Children do
        if child.RouteName == routeName and child.Barrier ~= true then
            return child
        end
    end

    return nil
end

return {
    name = "transition presets resolve in the app layer and delayed unmount lasts until the scheduler flushes",
    run = function()
        local scope = createFakeScope()
        local scheduler = createScheduler()
        local router = Router.create({
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
            scheduler = scheduler,
        })
        local screenLayer = getLayer(app, "screens")
        local modalLayer = getLayer(app, "modals")

        router:push("Inventory")

        local inventoryNode = findRouteNode(screenLayer, "Inventory")
        assert(
            inventoryNode.Transition.name == "slideLeft"
                and inventoryNode.Transition.style.offsetX == 1,
            "Global screenPush should resolve to the slideLeft preset style"
        )
        assert(
            scheduler.pendingCount() > 0,
            "Entering screen transitions should stay scheduled until the transition completes"
        )

        scheduler.flushAll()
        router:replace("Shop")

        local shopNode = findRouteNode(screenLayer, "Shop")
        assert(
            shopNode.Transition.name == "fade" and shopNode.Transition.style.opacity == 0.45,
            "Per-screen enterTransition should override the global screenPush preset"
        )

        scheduler.flushAll()
        router:back()

        shopNode = findRouteNode(screenLayer, "Shop")
        assert(
            shopNode ~= nil
                and shopNode.Transition.name == "fadeOut"
                and shopNode.Transition.style.opacity == 0,
            "Per-screen exitTransition should override the global screenPop preset"
        )

        scheduler.flushAll()
        router:pushModal("Confirm")

        local confirmNode = findRouteNode(modalLayer, "Confirm")
        assert(
            confirmNode.Transition.name == "fade" and confirmNode.Transition.style.opacity == 0.45,
            "Global modalOpen should resolve to the fade preset when no override exists"
        )

        scheduler.flushAll()
        router:pushModal("Settings")

        local settingsNode = findRouteNode(modalLayer, "Settings")
        assert(
            settingsNode.Transition.name == "fadeScaleIn"
                and settingsNode.Transition.style.scale == 0.92,
            "Per-modal transition should override the global modalOpen preset"
        )

        scheduler.flushAll()
        router:popModal()

        settingsNode = findRouteNode(modalLayer, "Settings")
        assert(
            settingsNode ~= nil
                and settingsNode.State == "exiting"
                and settingsNode.Transition.name == "fadeScaleIn",
            "Modal close should keep the exiting modal rendered until its scheduled transition finishes"
        )

        scheduler.flushAll()
        assert(
            findRouteNode(modalLayer, "Settings") == nil,
            "Exiting modals should disappear after the transition scheduler flushes"
        )
    end,
}
