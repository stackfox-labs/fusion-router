local Router = require("../src")
local createRouter = require("./TestRouter").createRouter

return {
    name = "modal navigation semantics cover stacking modal-first back pop closeAll close context and guarded cancellation",
    run = function()
        local router = createRouter({
            initialScreen = "MainMenu",
            screens = {
                MainMenu = Router.screen(function()
                    return {
                        id = "main-instance",
                    }
                end),
                Inventory = Router.screen(function()
                    return {
                        id = "inventory-instance",
                    }
                end),
            },
            modals = {
                Confirm = Router.modal(function(ctx)
                    return {
                        id = "confirm-instance",
                        params = ctx.params,
                    }
                end),
                Settings = Router.modal(function(ctx)
                    return {
                        id = "settings-instance",
                        params = ctx.params,
                    }
                end),
                Blocking = Router.modal(function()
                    return {
                        id = "blocking-instance",
                    }
                end, {
                    canExit = function()
                        return false
                    end,
                }),
            },
        })

        local inventoryEntry = router:push("Inventory")

        assert(router:popModal() == nil, "popModal should return nil when no modal is active")

        local confirmEntry = router:pushModal("Confirm", {
            productId = 1,
        })
        local settingsEntry = router:pushModal("Settings", {
            page = "Audio",
        })

        assert(#router._state.modalStack == 2, "pushModal should support stacking")
        assert(
            router:getCurrentModal() == settingsEntry
                and router:getCurrentScreen() == inventoryEntry,
            "Modal pushes should only change the modal layer"
        )
        assert(
            not confirmEntry.context.isActive.value and settingsEntry.context.isActive.value,
            "Only the topmost modal should be active"
        )
        assert(
            settingsEntry.params.page == "Audio" and confirmEntry.params.productId == 1,
            "Modal params should be preserved on their entries"
        )

        local closedByBack = router:back()

        assert(closedByBack == settingsEntry, "back should close the topmost modal before screens")
        assert(
            router:getCurrentModal() == confirmEntry and router:getCurrentScreen() == inventoryEntry,
            "Modal-first back should leave screen history untouched"
        )
        assert(confirmEntry.context.isActive.value, "The modal underneath should reactivate")

        local closedByContext = confirmEntry.context:close()

        assert(closedByContext == confirmEntry, "Modal ctx.close should close the current modal")
        assert(
            router:getCurrentModal() == nil,
            "Modal ctx.close should empty the modal layer when it closes the last modal"
        )
        assert(
            router:getCurrentScreen() == inventoryEntry,
            "Modal ctx.close should not change the screen stack"
        )

        local reopenConfirm = router:pushModal("Confirm")
        local reopenSettings = router:pushModal("Settings")
        local closedModals = router:closeAllModals()

        assert(#closedModals == 2, "closeAllModals should close every active modal")
        assert(
            closedModals[1] == reopenSettings and closedModals[2] == reopenConfirm,
            "closeAllModals should close modals in top-down order"
        )
        assert(router:getCurrentModal() == nil, "closeAllModals should leave no active modals")
        assert(
            router:getCurrentScreen() == inventoryEntry,
            "closeAllModals should preserve the active screen"
        )

        local guardedConfirm = router:pushModal("Confirm")
        local blockingEntry = router:pushModal("Blocking")

        assert(router:popModal() == nil, "popModal should return nil when canExit blocks the modal")
        assert(router:back() == nil, "back should return nil when the active modal blocks exit")
        assert(
            blockingEntry.context:close() == nil,
            "Modal ctx.close should surface the same guarded nil result"
        )

        local guardedCloseAll = router:closeAllModals()

        assert(
            #guardedCloseAll == 0,
            "closeAllModals should abort atomically when a modal blocks exit"
        )
        assert(
            router:getCurrentModal() == blockingEntry
                and router:getCurrentScreen() == inventoryEntry,
            "Guarded modal cancellation should preserve the current screen and modal"
        )
        assert(
            #router._state.modalStack == 2 and not guardedConfirm.context.isActive.value,
            "Guarded modal cancellation should preserve the existing modal stack state"
        )
    end,
}
