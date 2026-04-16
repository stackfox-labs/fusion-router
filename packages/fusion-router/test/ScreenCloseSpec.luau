local createRouter = require("./TestRouter").createRouter
local Router = require("../src")

return {
    name = "screen ctx.close mirrors back semantics and is safe at root depth",
    run = function()
        local callLog = {}
        local router = createRouter({
            initialScreen = "MainMenu",
            screens = {
                MainMenu = Router.screen(function()
                    return {
                        id = "main-instance",
                    }
                end, {
                    retention = "keepAlive",
                    onResume = function()
                        table.insert(callLog, "main:onResume")
                    end,
                }),
                Inventory = Router.screen(function()
                    return {
                        id = "inventory-instance",
                    }
                end, {
                    canExit = function()
                        table.insert(callLog, "inventory:canExit")

                        return true
                    end,
                    onExit = function()
                        table.insert(callLog, "inventory:onExit")
                    end,
                }),
            },
        })

        local mainEntry = router:getCurrentScreen()
        local inventoryEntry = router:push("Inventory")
        callLog = {}

        local closedEntry = inventoryEntry.context:close()

        assert(
            closedEntry == inventoryEntry,
            "screen ctx.close should return the same popped entry as router.back"
        )
        assert(
            router:getCurrentScreen() == mainEntry,
            "screen ctx.close should reactivate the previous screen"
        )
        assert(
            #router._state.screenStack == 1,
            "screen ctx.close should pop the top screen when back is possible"
        )
        assert(
            callLog[1] == "inventory:canExit"
                and callLog[2] == "inventory:onExit"
                and callLog[3] == "main:onResume",
            "screen ctx.close should follow the same lifecycle order as router.back"
        )

        callLog = {}

        local rootClose = mainEntry.context:close()

        assert(rootClose == nil, "screen ctx.close should be a no-op at root depth")
        assert(
            router:getCurrentScreen() == mainEntry,
            "screen ctx.close at root should preserve the current screen"
        )
        assert(
            #router._state.screenStack == 1,
            "screen ctx.close at root should not mutate stack depth"
        )
        assert(#callLog == 0, "screen ctx.close at root should not run lifecycle hooks")
    end,
}
