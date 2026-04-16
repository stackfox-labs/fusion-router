local createRouter = require("../src/runtime/createRouter")
local Router = require("../src")

return {
    name = "screen retention reuses keepAlive and singleton entries while destroy tears down",
    run = function()
        local mainMounts = 0
        local inventoryMounts = 0
        local router = createRouter({
            initialScreen = "MainMenu",
            screens = {
                MainMenu = Router.screen(function()
                    mainMounts += 1

                    return {
                        id = ("main-instance-%d"):format(mainMounts),
                    }
                end, {
                    retention = "singleton",
                }),
                Inventory = Router.screen(function()
                    inventoryMounts += 1

                    return {
                        id = ("inventory-instance-%d"):format(inventoryMounts),
                    }
                end, {
                    retention = "keepAlive",
                }),
                Shop = Router.screen(function()
                    return {
                        id = "shop-instance",
                    }
                end),
            },
        })

        local mainEntry = router:getCurrentScreen()
        local mainInstance = mainEntry.instance

        local inventoryEntry = router:replace("Inventory")
        local inventoryInstance = inventoryEntry.instance

        assert(mainEntry.scope ~= nil, "singleton entries should stay mounted when replaced away")
        assert(mainMounts == 1, "singleton screens should mount once at bootstrap")

        local shopEntry = router:replace("Shop")

        assert(
            router._state.retainedScreens[inventoryEntry.key] == inventoryEntry,
            "keepAlive entries replaced away should be retained for reuse"
        )

        local reusedInventory = router:push("Inventory")

        assert(reusedInventory == inventoryEntry, "keepAlive pushes should reuse retained entries")
        assert(
            reusedInventory.instance == inventoryInstance,
            "keepAlive reuse should preserve the mounted instance"
        )
        assert(inventoryMounts == 1, "keepAlive screens should not remount when reused")
        assert(
            shopEntry.scope == nil and shopEntry.instance == nil,
            "destroy screens pushed away should tear down their mounted instance"
        )

        local reusedMain = router:replace("MainMenu")

        assert(reusedMain == mainEntry, "singleton replaces should reuse the singleton entry")
        assert(
            reusedMain.instance == mainInstance,
            "singleton reuse should preserve the mounted instance"
        )
        assert(mainMounts == 1, "singleton screens should not remount on reuse")
    end,
}
