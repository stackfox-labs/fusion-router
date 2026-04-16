local createRouter = require("./TestRouter").createRouter
local Router = require("../src")

return {
    name = "destroy screens tear down when hidden and remount before resume on back",
    run = function()
        local callLog = {}
        local mainMounts = 0
        local router = createRouter({
            initialScreen = "MainMenu",
            screens = {
                MainMenu = Router.screen(function()
                    mainMounts += 1
                    table.insert(callLog, "main:component")

                    return {
                        id = ("main-instance-%d"):format(mainMounts),
                    }
                end, {
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
            },
        })

        local mainEntry = router:getCurrentScreen()
        callLog = {}

        local inventoryEntry = router:push("Inventory")

        assert(
            not table.find(callLog, "main:onPause"),
            "destroy screens should not fire onPause when hidden by a push"
        )
        assert(
            mainEntry.scope == nil and mainEntry.instance == nil,
            "destroy screens should tear down when they stop being active"
        )

        callLog = {}

        local poppedEntry = router:back()

        assert(poppedEntry == inventoryEntry, "back should still pop the destroy top screen")
        assert(
            callLog[1] == "inventory:canExit"
                and callLog[2] == "inventory:onExit"
                and callLog[3] == "main:component"
                and callLog[4] == "main:onResume",
            "destroy-screen back should remount the previous screen before onResume"
        )
        assert(mainMounts == 2, "destroy screens should remount when revisited via back")
    end,
}
