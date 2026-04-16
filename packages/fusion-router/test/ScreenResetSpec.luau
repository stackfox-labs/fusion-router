local createRouter = require("../src/runtime/createRouter")
local Router = require("../src")

return {
    name = "router reset tears down old screens and mounts a fresh root screen",
    run = function()
        local callLog = {}
        local router = createRouter({
            initialScreen = "MainMenu",
            screens = {
                MainMenu = Router.screen(function()
                    table.insert(callLog, "main:component")

                    return {
                        id = "main-instance",
                    }
                end, {
                    retention = "keepAlive",
                    onExit = function()
                        table.insert(callLog, "main:onExit")
                    end,
                }),
                Inventory = Router.screen(function()
                    table.insert(callLog, "inventory:component")

                    return {
                        id = "inventory-instance",
                    }
                end, {
                    onExit = function()
                        table.insert(callLog, "inventory:onExit")
                    end,
                }),
                Shop = Router.screen(function()
                    table.insert(callLog, "shop:component")

                    return {
                        id = "shop-instance",
                    }
                end, {
                    validateParams = function(params)
                        table.insert(callLog, "shop:validateParams")
                        assert(type(params.tab) == "string", "tab must be a string")
                    end,
                    canEnter = function()
                        table.insert(callLog, "shop:canEnter")

                        return true
                    end,
                    onEnter = function()
                        table.insert(callLog, "shop:onEnter")
                    end,
                }),
                Locked = Router.screen(function()
                    table.insert(callLog, "locked:component")

                    return {
                        id = "locked-instance",
                    }
                end, {
                    canEnter = function()
                        table.insert(callLog, "locked:canEnter")

                        return false
                    end,
                    onEnter = function()
                        table.insert(callLog, "locked:onEnter")
                    end,
                }),
            },
            modals = {
                Confirm = Router.modal(function()
                    return {
                        id = "confirm-instance",
                    }
                end),
            },
        })

        local mainEntry = router:getCurrentScreen()
        local inventoryEntry = router:replace("Inventory")
        router:pushModal("Confirm")
        callLog = {}

        local resetEntry = router:reset("Shop", {
            tab = "Featured",
        })

        assert(resetEntry == router:getCurrentScreen(), "reset should make the new root active")
        assert(#router._state.screenStack == 1, "reset should replace the whole screen stack")
        assert(#router._state.modalStack == 0, "reset should clear active modals")
        assert(next(router._state.retainedScreens) == nil, "reset should clear retained screen state")
        assert(router._state.currentTransition == nil, "reset should clear current transition state")
        assert(
            callLog[1] == "shop:validateParams"
                and callLog[2] == "shop:canEnter"
                and callLog[3] == "inventory:onExit"
                and callLog[4] == "main:onExit"
                and callLog[5] == "shop:component"
                and callLog[6] == "shop:onEnter",
            "reset should validate the new root, tear down old screens, then mount and enter the replacement"
        )
        assert(
            mainEntry.scope == nil and mainEntry.context == nil and mainEntry.instance == nil,
            "reset should clean up retained screens that are no longer valid"
        )
        assert(
            inventoryEntry.scope == nil and inventoryEntry.context == nil and inventoryEntry.instance == nil,
            "reset should clean up the active replaced screen"
        )
        assert(mainEntry.isMounted == false, "reset should unmount retained screens")
        assert(inventoryEntry.isMounted == false, "reset should unmount the previous active screen")
        assert(resetEntry.state == "active", "reset should mount the new root as active")
        assert(resetEntry.scope ~= nil, "reset should attach a scope to the new root")
        assert(resetEntry.context ~= nil, "reset should create route context for the new root")
        assert(resetEntry.instance.id == "shop-instance", "reset should mount the new root instance")
        assert(
            resetEntry.context.params.tab == "Featured",
            "reset should expose new params through the new root context"
        )

        callLog = {}

        local blockedResult = router:reset("Locked")

        assert(blockedResult == nil, "reset should return nil when canEnter blocks the new root")
        assert(
            router:getCurrentScreen() == resetEntry,
            "canEnter-blocked reset should preserve the current active screen"
        )
        assert(#router._state.screenStack == 1, "canEnter-blocked reset should preserve stack depth")
        assert(
            callLog[1] == "locked:canEnter",
            "reset should check canEnter before tearing down existing screens"
        )
        assert(#callLog == 1, "canEnter-blocked reset should stop before teardown or mount")
    end,
}
