local Router = require("../src")

local function noop() end

local function createConfig()
    return {
        initialScreen = "MainMenu",
        screens = {
            MainMenu = Router.screen(noop),
            Inventory = Router.screen(noop),
            Shop = Router.screen(noop),
        },
        modals = {
            ConfirmPurchase = Router.modal(noop),
            Settings = Router.modal(noop),
        },
    }
end

return {
    name = "router inspection helpers reflect screen and modal stack state",
    run = function()
        local router = Router.create(createConfig())

        assert(
            router:getCurrentScreen().name == "MainMenu",
            "getCurrentScreen should return the bootstrapped screen"
        )
        assert(
            router:getCurrentModal() == nil,
            "getCurrentModal should return nil when no modals are open"
        )
        assert(
            router:getScreenParams() == nil,
            "getScreenParams should return nil when the active screen has no params"
        )
        assert(
            router:canGoBack() == false,
            "canGoBack should be false with one screen and no modals"
        )

        local inventoryEntry = router:push("Inventory", {
            tab = "Weapons",
        })

        assert(
            router:getCurrentScreen() == inventoryEntry,
            "getCurrentScreen should track the top screen entry after push"
        )
        assert(
            router:getScreenParams().tab == "Weapons",
            "getScreenParams should expose params for the active screen"
        )
        assert(router:canGoBack() == true, "canGoBack should be true with two screens")

        local shopEntry = router:replace("Shop", {
            section = "Featured",
        })

        assert(
            router:getCurrentScreen() == shopEntry,
            "getCurrentScreen should update when the active screen is replaced"
        )
        assert(
            router:getCurrentScreen().name == "Shop",
            "replace should make the replacement screen active"
        )
        assert(
            router:getScreenParams().section == "Featured",
            "getScreenParams should update after replace"
        )
        assert(router:canGoBack() == true, "canGoBack should remain true after replace")

        local confirmModal = router:pushModal("ConfirmPurchase", {
            productId = 42,
        })

        assert(
            router:getCurrentModal() == confirmModal,
            "getCurrentModal should return the top modal after pushModal"
        )
        assert(
            router:getCurrentModal().params.productId == 42,
            "getCurrentModal should preserve modal params"
        )
        assert(
            router:canGoBack() == true,
            "canGoBack should stay true while a modal is open"
        )

        local settingsModal = router:pushModal("Settings")

        assert(
            router:getCurrentModal() == settingsModal,
            "getCurrentModal should follow the topmost modal"
        )

        local poppedModal = router:back()

        assert(poppedModal == settingsModal, "back should close the topmost modal first")
        assert(
            router:getCurrentModal() == confirmModal,
            "getCurrentModal should fall back to the next modal after back"
        )
        assert(
            router:getCurrentScreen() == shopEntry,
            "Closing a modal should not change the active screen"
        )

        local closedModals = router:closeAllModals()

        assert(#closedModals == 1, "closeAllModals should close every remaining modal")
        assert(
            closedModals[1] == confirmModal,
            "closeAllModals should return the closed modal entries in top-down order"
        )
        assert(
            router:getCurrentModal() == nil,
            "getCurrentModal should return nil after all modals are closed"
        )
        assert(
            router:canGoBack() == true,
            "canGoBack should still reflect screen history after modals close"
        )

        local resetEntry = router:reset("MainMenu", {
            source = "reset",
        })

        assert(
            router:getCurrentScreen() == resetEntry,
            "getCurrentScreen should return the reset screen after reset"
        )
        assert(
            router:getScreenParams().source == "reset",
            "getScreenParams should return params for the reset screen"
        )
        assert(
            router:getCurrentModal() == nil,
            "reset should clear all active modals for inspection helpers"
        )
        assert(
            router:canGoBack() == false,
            "canGoBack should be false after reset returns to one screen and no modals"
        )
    end,
}
