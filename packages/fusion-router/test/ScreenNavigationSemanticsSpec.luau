local Router = require("../src")
local createRouter = require("./TestRouter").createRouter

return {
    name = "screen navigation semantics keep params stack shape and inspection helpers coherent across push replace back and reset",
    run = function()
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
                Inventory = Router.screen(function(ctx)
                    return {
                        id = "inventory-instance",
                        params = ctx.params,
                    }
                end),
                Shop = Router.screen(function(ctx)
                    return {
                        id = "shop-instance",
                        params = ctx.params,
                    }
                end),
            },
        })

        local mainEntry = router:getCurrentScreen()

        assert(
            mainEntry.name == "MainMenu",
            "Initial screen should bootstrap as the current screen"
        )
        assert(
            router:getScreenParams() == nil,
            "Initial screen should expose nil params by default"
        )
        assert(router:getCurrentModal() == nil, "Screen navigation should not create modals")
        assert(router:canGoBack() == false, "A fresh router should not allow back navigation")

        local inventoryEntry = router:push("Inventory", {
            tab = "Weapons",
        })

        assert(router:getCurrentScreen() == inventoryEntry, "push should activate the new screen")
        assert(#router._state.screenStack == 2, "push should append one screen entry")
        assert(
            router:getScreenParams().tab == "Weapons" and inventoryEntry.params.tab == "Weapons",
            "push should preserve screen params on the entry and helper surface"
        )
        assert(router:canGoBack() == true, "Two screens should make back available")

        local shopEntry = router:replace("Shop", {
            section = "Featured",
        })

        assert(
            router:getCurrentScreen() == shopEntry,
            "replace should activate the replacement screen"
        )
        assert(#router._state.screenStack == 2, "replace should preserve screen stack depth")
        assert(
            router._state.screenStack[1] == mainEntry and router._state.screenStack[2] == shopEntry,
            "replace should swap only the top screen entry"
        )
        assert(
            router:getScreenParams().section == "Featured"
                and shopEntry.params.section == "Featured",
            "replace should update current screen params"
        )

        local poppedShop = router:back()

        assert(poppedShop == shopEntry, "back should return the popped top screen")
        assert(router:getCurrentScreen() == mainEntry, "back should reactivate the previous screen")
        assert(#router._state.screenStack == 1, "back should reduce the screen stack depth")
        assert(router:getScreenParams() == nil, "back to the root should restore root params")
        assert(router:canGoBack() == false, "Back at root depth should no longer be available")

        local rootBack = router:back()

        assert(rootBack == nil, "Root back should be a no-op")
        assert(
            router:getCurrentScreen() == mainEntry,
            "Root back should preserve the active screen"
        )
        assert(#router._state.screenStack == 1, "Root back should preserve stack depth")

        local secondInventory = router:push("Inventory", {
            tab = "Armor",
        })
        local resetEntry = router:reset("Shop", {
            section = "Deals",
        })

        assert(secondInventory ~= nil, "push should still work after returning to root")
        assert(resetEntry == router:getCurrentScreen(), "reset should activate the new root screen")
        assert(#router._state.screenStack == 1, "reset should replace the full screen stack")
        assert(
            router:getScreenParams().section == "Deals" and resetEntry.params.section == "Deals",
            "reset should replace the helper params with the new root params"
        )
        assert(router:getCurrentModal() == nil, "reset should keep modal inspection empty")
        assert(router:canGoBack() == false, "reset to one screen should clear back availability")
    end,
}
