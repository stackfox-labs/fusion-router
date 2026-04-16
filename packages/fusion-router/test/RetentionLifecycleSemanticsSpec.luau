local Router = require("../src")
local createRouter = require("./TestRouter").createRouter

return {
    name = "retention and lifecycle semantics preserve or clean route-local Fusion state across destroy keepAlive singleton and cancellation",
    run = function()
        local callLog = {}
        local mainMounts = 0
        local inventoryMounts = 0
        local shopMounts = 0

        local router = createRouter({
            initialScreen = "MainMenu",
            screens = {
                MainMenu = Router.screen(function(ctx)
                    mainMounts += 1
                    table.insert(callLog, "main:component")

                    return {
                        id = ("main-instance-%d"):format(mainMounts),
                        state = ctx.scope:Value("main-default"),
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
                Inventory = Router.screen(function(ctx)
                    inventoryMounts += 1
                    table.insert(callLog, "inventory:component")

                    return {
                        id = ("inventory-instance-%d"):format(inventoryMounts),
                        state = ctx.scope:Value(0),
                    }
                end, {
                    retention = "keepAlive",
                    canEnter = function()
                        table.insert(callLog, "inventory:canEnter")

                        return true
                    end,
                    onEnter = function()
                        table.insert(callLog, "inventory:onEnter")
                    end,
                    onPause = function()
                        table.insert(callLog, "inventory:onPause")
                    end,
                    onResume = function()
                        table.insert(callLog, "inventory:onResume")
                    end,
                }),
                Shop = Router.screen(function(ctx)
                    shopMounts += 1
                    table.insert(callLog, "shop:component")

                    return {
                        id = ("shop-instance-%d"):format(shopMounts),
                        state = ctx.scope:Value(100),
                    }
                end, {
                    canExit = function()
                        table.insert(callLog, "shop:canExit")

                        return true
                    end,
                    onEnter = function()
                        table.insert(callLog, "shop:onEnter")
                    end,
                    onExit = function()
                        table.insert(callLog, "shop:onExit")
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
                }),
            },
        })

        local mainEntry = router:getCurrentScreen()
        mainEntry.instance.state:set("main-persisted")
        callLog = {}

        local inventoryEntry = router:push("Inventory")
        inventoryEntry.instance.state:set(5)

        assert(
            callLog[1] == "inventory:canEnter"
                and callLog[2] == "main:onPause"
                and callLog[3] == "inventory:component"
                and callLog[4] == "inventory:onEnter",
            "keepAlive pushes should guard pause mount and enter in order"
        )
        assert(
            mainMounts == 1 and inventoryMounts == 1,
            "Initial keepAlive mounts should happen once"
        )
        assert(mainEntry.state == "paused", "Pushed-over keepAlive screens should become paused")
        assert(
            mainEntry.instance.state.value == "main-persisted",
            "Paused keepAlive screens should preserve route-local Fusion state"
        )

        callLog = {}

        local blockedEntry = router:push("Locked")

        assert(blockedEntry == nil, "canEnter should cancel the push")
        assert(
            router:getCurrentScreen() == inventoryEntry and inventoryEntry.instance.state.value == 5,
            "Cancelled pushes should leave the current keepAlive screen and its state intact"
        )
        assert(
            #callLog == 1 and callLog[1] == "locked:canEnter",
            "Cancelled pushes should stop before pause or mount work"
        )

        callLog = {}

        local shopEntry = router:push("Shop")
        shopEntry.instance.state:set(130)

        assert(
            callLog[1] == "inventory:onPause"
                and callLog[2] == "shop:component"
                and callLog[3] == "shop:onEnter",
            "Pushing over a keepAlive screen should pause it before mounting the destroy screen"
        )

        callLog = {}

        local poppedShop = router:back()

        assert(poppedShop == shopEntry, "back should pop the destroy screen")
        assert(
            callLog[1] == "shop:canExit"
                and callLog[2] == "shop:onExit"
                and callLog[3] == "inventory:onResume",
            "Destroy-screen back should exit the top screen before resuming the retained screen"
        )
        assert(
            shopEntry.scope == nil and shopEntry.instance == nil,
            "Destroy screens should clean up on exit"
        )
        assert(shopMounts == 1, "Destroy screens should have mounted once so far")
        assert(
            router:getCurrentScreen() == inventoryEntry and inventoryEntry.instance.state.value == 5,
            "Resumed keepAlive screens should reuse their original Fusion state"
        )

        callLog = {}

        local poppedInventory = router:back()

        assert(
            poppedInventory == inventoryEntry,
            "back should pop the retained keepAlive screen entry"
        )
        assert(
            #callLog == 1 and callLog[1] == "main:onResume",
            "Returning to the previous keepAlive screen should resume it without remounting the popped keepAlive entry"
        )
        assert(
            router:getCurrentScreen() == mainEntry
                and mainEntry.instance.state.value == "main-persisted",
            "The resumed previous keepAlive screen should preserve its Fusion state"
        )
        assert(
            router._state.retainedScreens[inventoryEntry.key] == inventoryEntry
                and inventoryEntry.instance.state.value == 5,
            "Popped keepAlive screens should stay retained with their preserved state"
        )

        callLog = {}

        local reusedInventory = router:push("Inventory")

        assert(
            reusedInventory == inventoryEntry,
            "Re-entering a keepAlive route should reuse the retained entry"
        )
        assert(inventoryMounts == 1, "Reused keepAlive routes should not remount")
        assert(
            reusedInventory.instance.state.value == 5,
            "Reused keepAlive routes should preserve their route-local Fusion state"
        )
        assert(
            callLog[1] == "inventory:canEnter"
                and callLog[2] == "main:onPause"
                and callLog[3] == "inventory:onEnter",
            "Re-entering a keepAlive route should re-run lifecycle entry without remounting"
        )

        local singletonMounts = 0
        local singletonRouter = createRouter({
            initialScreen = "Dashboard",
            screens = {
                Dashboard = Router.screen(function(ctx)
                    singletonMounts += 1

                    return {
                        id = ("dashboard-instance-%d"):format(singletonMounts),
                        state = ctx.scope:Value("dashboard-default"),
                    }
                end, {
                    retention = "singleton",
                }),
                Shop = Router.screen(function(ctx)
                    return {
                        id = "shop-instance",
                        state = ctx.scope:Value("shop-default"),
                    }
                end),
            },
        })

        local dashboardEntry = singletonRouter:getCurrentScreen()
        dashboardEntry.instance.state:set("dashboard-persisted")
        local transientShop = singletonRouter:replace("Shop")
        local reusedDashboard = singletonRouter:replace("Dashboard")

        assert(
            reusedDashboard == dashboardEntry,
            "Singleton routes should reuse their single retained entry"
        )
        assert(singletonMounts == 1, "Singleton routes should mount only once")
        assert(
            reusedDashboard.instance.state.value == "dashboard-persisted",
            "Singleton reuse should preserve route-local Fusion state"
        )
        assert(
            transientShop.scope == nil and transientShop.instance == nil,
            "Destroy routes replaced away from a singleton should still clean up"
        )
    end,
}
