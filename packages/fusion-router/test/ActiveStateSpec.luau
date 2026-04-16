local createRouter = require("./TestRouter").createRouter
local Router = require("../src")

return {
    name = "ctx.isActive flips across screen and modal visibility changes",
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
                Inventory = Router.screen(function()
                    return {
                        id = "inventory-instance",
                    }
                end),
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
                end),
            },
        })

        local mainEntry = router:getCurrentScreen()
        assert(mainEntry.context.isActive.value == true, "bootstrapped screens should start active")

        local inventoryEntry = router:push("Inventory")

        assert(
            mainEntry.context.isActive.value == false,
            "pushing a screen should flip the previous retained screen inactive"
        )
        assert(
            inventoryEntry.context.isActive.value == true,
            "pushing a screen should make the new screen active"
        )

        local confirmEntry = router:pushModal("Confirm")

        assert(
            inventoryEntry.context.isActive.value == true,
            "screen isActive should remain true while modals stack above it"
        )
        assert(confirmEntry.context.isActive.value == true, "new modal should start active")

        local settingsEntry = router:pushModal("Settings")

        assert(
            confirmEntry.context.isActive.value == false,
            "pushing a modal should flip the previous modal inactive"
        )
        assert(settingsEntry.context.isActive.value == true, "top modal should be active")

        router:popModal()
        assert(
            confirmEntry.context.isActive.value == true,
            "popping a modal should reactivate the next modal underneath"
        )

        router:popModal()
        router:back()
        assert(
            mainEntry.context.isActive.value == true,
            "back should reactivate the previous retained screen"
        )
        assert(
            inventoryEntry.isMounted == false,
            "back should unmount exited destroy screens after they leave the stack"
        )
    end,
}
