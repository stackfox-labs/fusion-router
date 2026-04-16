local createRouter = require("../src/runtime/createRouter")
local Router = require("../src")

return {
    name = "router back exits the top screen and resumes the retained previous screen",
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
                    onPause = function()
                        table.insert(callLog, "main:onPause")
                    end,
                    onResume = function()
                        table.insert(callLog, "main:onResume")
                    end,
                }),
                Inventory = Router.screen(function()
                    table.insert(callLog, "inventory:component")

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
                Locked = Router.screen(function()
                    table.insert(callLog, "locked:component")

                    return {
                        id = "locked-instance",
                    }
                end, {
                    canExit = function()
                        table.insert(callLog, "locked:canExit")

                        return false
                    end,
                    onExit = function()
                        table.insert(callLog, "locked:onExit")
                    end,
                }),
            },
        })

        local mainEntry = router:getCurrentScreen()
        callLog = {}

        local inventoryEntry = router:push("Inventory")
        callLog = {}

        local poppedEntry = router:back()

        assert(poppedEntry == inventoryEntry, "back should return the popped screen entry")
        assert(#router._state.screenStack == 1, "back should pop the top screen entry")
        assert(router:getCurrentScreen() == mainEntry, "back should reactivate the previous screen")
        assert(
            callLog[1] == "inventory:canExit"
                and callLog[2] == "inventory:onExit"
                and callLog[3] == "main:onResume",
            "back should check canExit, exit the top screen, and then resume the previous screen"
        )
        assert(mainEntry.state == "active", "back should restore the previous screen to active")
        assert(mainEntry.isMounted == true, "retained previous screens should stay mounted")
        assert(
            mainEntry.context.isActive.value == true,
            "back should restore the previous screen active state"
        )
        assert(
            inventoryEntry.scope == nil
                and inventoryEntry.context == nil
                and inventoryEntry.instance == nil,
            "back should clean up the popped screen when it exits"
        )
        assert(inventoryEntry.isMounted == false, "back should unmount the popped screen")
        assert(
            router._state.retainedScreens[inventoryEntry.key] == nil,
            "back should not leave the popped screen in retainedScreens"
        )
        assert(router:canGoBack() == false, "back to root should clear back availability")

        callLog = {}

        local rootBack = router:back()

        assert(rootBack == nil, "back at root depth should be a no-op")
        assert(#router._state.screenStack == 1, "root back should preserve the screen stack")
        assert(#callLog == 0, "root back should not run lifecycle hooks")

        local blockedRouter = createRouter({
            initialScreen = "MainMenu",
            screens = {
                MainMenu = Router.screen(function()
                    return {
                        id = "main-instance",
                    }
                end, {
                    retention = "keepAlive",
                }),
                Locked = Router.screen(function()
                    return {
                        id = "locked-instance",
                    }
                end, {
                    canExit = function()
                        table.insert(callLog, "locked:canExit")

                        return false
                    end,
                    onExit = function()
                        table.insert(callLog, "locked:onExit")
                    end,
                }),
            },
        })

        local blockedMainEntry = blockedRouter:getCurrentScreen()
        local lockedEntry = blockedRouter:push("Locked")
        callLog = {}

        local blockedResult = blockedRouter:back()

        assert(blockedResult == nil, "back should return nil when canExit blocks exit")
        assert(
            blockedRouter:getCurrentScreen() == lockedEntry,
            "canExit-blocked back should preserve the current top screen"
        )
        assert(
            #blockedRouter._state.screenStack == 2,
            "canExit-blocked back should preserve stack depth"
        )
        assert(
            blockedMainEntry.state == "paused",
            "canExit-blocked back should leave the previous screen paused"
        )
        assert(
            callLog[1] == "locked:canExit",
            "back should ask the active screen for exit permission first"
        )
        assert(#callLog == 1, "canExit-blocked back should stop before cleanup or resume")
    end,
}
