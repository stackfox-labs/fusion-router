local createRouter = require("../src/runtime/createRouter")
local Router = require("../src")

return {
    name = "router replace checks canExit and applies destroy versus retained behavior",
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
                    canExit = function()
                        table.insert(callLog, "main:canExit")

                        return true
                    end,
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
                    validateParams = function(params)
                        table.insert(callLog, "inventory:validateParams")
                        assert(type(params.category) == "string", "category must be a string")
                    end,
                    canEnter = function()
                        table.insert(callLog, "inventory:canEnter")

                        return true
                    end,
                    canExit = function()
                        table.insert(callLog, "inventory:canExit")

                        return true
                    end,
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
                    canEnter = function()
                        table.insert(callLog, "shop:canEnter")

                        return true
                    end,
                    onEnter = function()
                        table.insert(callLog, "shop:onEnter")
                    end,
                }),
            },
        })

        local mainEntry = router:getCurrentScreen()
        callLog = {}

        local inventoryEntry = router:replace("Inventory", {
            category = "Weapons",
        })

        assert(
            inventoryEntry == router:getCurrentScreen(),
            "replace should make the new screen the active top entry"
        )
        assert(#router._state.screenStack == 1, "replace should keep screen stack depth stable")
        assert(
            callLog[1] == "inventory:validateParams"
                and callLog[2] == "inventory:canEnter"
                and callLog[3] == "main:canExit"
                and callLog[4] == "inventory:component",
            "replace should validate and guard before mounting the replacement"
        )
        assert(
            not table.find(callLog, "main:onExit"),
            "Retained outgoing screens should not run onExit during replace"
        )
        assert(mainEntry.state == "paused", "Retained replaced screens should become paused")
        assert(mainEntry.isMounted == true, "Retained replaced screens should remain mounted")
        assert(
            mainEntry.context.isActive.value == false,
            "Retained replaced screens should become inactive"
        )
        assert(
            router._state.retainedScreens[mainEntry.key] == mainEntry,
            "Retained replaced screens should be tracked for later reuse"
        )

        callLog = {}

        local shopEntry = router:replace("Shop")

        assert(shopEntry == router:getCurrentScreen(), "replace should activate the next screen")
        assert(#router._state.screenStack == 1, "replace should still keep one top screen")
        assert(
            callLog[1] == "shop:canEnter"
                and callLog[2] == "inventory:canExit"
                and callLog[3] == "inventory:onExit"
                and callLog[4] == "shop:component"
                and callLog[5] == "shop:onEnter",
            "replace should exit destroy screens before mounting and entering the replacement"
        )
        assert(
            inventoryEntry.scope == nil and inventoryEntry.context == nil and inventoryEntry.instance == nil,
            "Destroy replaced screens should clean up scope, context, and instance"
        )
        assert(
            inventoryEntry.isMounted == false,
            "Destroy replaced screens should no longer be mounted after replace"
        )
        assert(
            router._state.retainedScreens[inventoryEntry.key] == nil,
            "Destroy replaced screens should not remain retained"
        )

        local blockedCalls = {}
        local blockedRouter = createRouter({
            initialScreen = "Locked",
            screens = {
                Locked = Router.screen(function()
                    table.insert(blockedCalls, "locked:component")

                    return {
                        id = "locked-instance",
                    }
                end, {
                    canExit = function()
                        table.insert(blockedCalls, "locked:canExit")

                        return false
                    end,
                }),
                Shop = Router.screen(function()
                    table.insert(blockedCalls, "shop:component")

                    return {
                        id = "shop-instance",
                    }
                end, {
                    canEnter = function()
                        table.insert(blockedCalls, "shop:canEnter")

                        return true
                    end,
                }),
            },
        })

        local lockedEntry = blockedRouter:getCurrentScreen()
        blockedCalls = {}

        local blockedResult = blockedRouter:replace("Shop")

        assert(blockedResult == nil, "replace should return nil when canExit blocks navigation")
        assert(
            blockedRouter:getCurrentScreen() == lockedEntry,
            "canExit-blocked replace should preserve the active screen"
        )
        assert(
            #blockedRouter._state.screenStack == 1,
            "canExit-blocked replace should not mutate stack depth"
        )
        assert(
            blockedCalls[1] == "shop:canEnter" and blockedCalls[2] == "locked:canExit",
            "replace should check the replacement before asking the current screen to exit"
        )
        assert(#blockedCalls == 2, "canExit-blocked replace should stop before mounting")
    end,
}
