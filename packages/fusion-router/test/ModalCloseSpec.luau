local createRouter = require("../src/runtime/createRouter")
local Router = require("../src")

return {
    name = "modal pop closeAll back and ctx.close share guarded top-down shutdown semantics",
    run = function()
        local callLog = {}
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
                Confirm = Router.modal(function()
                    return {
                        id = "confirm-instance",
                    }
                end, {
                    canExit = function()
                        table.insert(callLog, "confirm:canExit")

                        return true
                    end,
                    onExit = function()
                        table.insert(callLog, "confirm:onExit")
                    end,
                    transition = "fadeScaleIn",
                }),
                Settings = Router.modal(function()
                    return {
                        id = "settings-instance",
                    }
                end, {
                    canExit = function()
                        table.insert(callLog, "settings:canExit")

                        return true
                    end,
                    onExit = function()
                        table.insert(callLog, "settings:onExit")
                    end,
                }),
                Blocking = Router.modal(function()
                    return {
                        id = "blocking-instance",
                    }
                end, {
                    canExit = function()
                        table.insert(callLog, "blocking:canExit")

                        return false
                    end,
                    onExit = function()
                        table.insert(callLog, "blocking:onExit")
                    end,
                }),
            },
            transitions = {
                modalOpen = "fade",
                modalClose = "fadeOut",
            },
        })

        local screenEntry = router:getCurrentScreen()
        local confirmEntry = router:pushModal("Confirm")
        local settingsEntry = router:pushModal("Settings")
        callLog = {}

        local poppedSettings = router:popModal()

        assert(poppedSettings == settingsEntry, "popModal should return the closed topmost modal")
        assert(router:getCurrentModal() == confirmEntry, "popModal should reactivate the modal underneath")
        assert(#router._state.modalStack == 1, "popModal should remove exactly one modal")
        assert(
            callLog[1] == "settings:canExit" and callLog[2] == "settings:onExit",
            "popModal should run canExit before onExit for the active modal"
        )
        assert(
            settingsEntry.scope == nil and settingsEntry.context == nil and settingsEntry.instance == nil,
            "popModal should clean up the closed modal"
        )
        assert(settingsEntry.isMounted == false, "popModal should unmount the closed modal")
        assert(
            confirmEntry.context.isActive.value == true,
            "popModal should reactivate the next modal underneath"
        )
        assert(
            router._state.currentTransition == "fadeOut",
            "popModal should use the global modalClose transition when no override exists"
        )

        local inventoryEntry = router:push("Inventory")
        local blockingEntry = router:pushModal("Blocking")
        callLog = {}

        local backResult = router:back()

        assert(backResult == nil, "back should return nil when the active modal blocks exit")
        assert(
            router:getCurrentModal() == blockingEntry,
            "modal-first back should preserve the current modal when canExit blocks it"
        )
        assert(
            router:getCurrentScreen() == inventoryEntry,
            "modal-first back should not touch screen history while a modal is active"
        )
        assert(
            callLog[1] == "blocking:canExit",
            "back should check the top modal before considering screen history"
        )
        assert(#callLog == 1, "blocked modal back should stop before cleanup or screen pops")

        callLog = {}

        local closeResult = blockingEntry.context:close()

        assert(closeResult == nil, "modal ctx.close should return nil when popModal is blocked")
        assert(
            router:getCurrentModal() == blockingEntry,
            "modal ctx.close should only target the current modal layer"
        )
        assert(
            router:getCurrentScreen() == inventoryEntry,
            "modal ctx.close should never pop the screen while a modal is active"
        )
        assert(
            callLog[1] == "blocking:canExit",
            "modal ctx.close should delegate to the same guarded modal pop path"
        )
        assert(#callLog == 1, "blocked modal ctx.close should stop before cleanup")

        local closeAllRouter = createRouter({
            initialScreen = "MainMenu",
            screens = {
                MainMenu = Router.screen(function()
                    return {
                        id = "main-instance",
                    }
                end),
            },
            modals = {
                Confirm = Router.modal(function()
                    return {
                        id = "confirm-instance",
                    }
                end, {
                    onExit = function()
                        table.insert(callLog, "confirm:onExit")
                    end,
                    transition = "fadeScaleIn",
                }),
                Settings = Router.modal(function()
                    return {
                        id = "settings-instance",
                    }
                end, {
                    onExit = function()
                        table.insert(callLog, "settings:onExit")
                    end,
                }),
            },
            transitions = {
                modalOpen = "fade",
                modalClose = "fadeOut",
            },
        })

        local closeAllConfirm = closeAllRouter:pushModal("Confirm")
        local closeAllSettings = closeAllRouter:pushModal("Settings")
        callLog = {}

        local closedModals = closeAllRouter:closeAllModals()

        assert(#closedModals == 2, "closeAllModals should close every active modal")
        assert(
            closedModals[1] == closeAllSettings and closedModals[2] == closeAllConfirm,
            "closeAllModals should close modals in deterministic top-down order"
        )
        assert(closeAllRouter:getCurrentModal() == nil, "closeAllModals should leave no active modals")
        assert(#closeAllRouter._state.modalStack == 0, "closeAllModals should empty the modal stack")
        assert(
            callLog[1] == "settings:onExit" and callLog[2] == "confirm:onExit",
            "closeAllModals should run modal exit hooks in top-down order"
        )
        assert(
            closeAllSettings.scope == nil and closeAllConfirm.scope == nil,
            "closeAllModals should clean up all closed modal scopes"
        )
        assert(
            closeAllRouter._state.currentTransition == "fadeScaleIn",
            "closeAllModals should use the modal override when selecting close transitions"
        )

        local closeActiveRouter = createRouter({
            initialScreen = "MainMenu",
            screens = {
                MainMenu = Router.screen(function()
                    return {
                        id = "main-instance",
                    }
                end),
            },
            modals = {
                Confirm = Router.modal(function()
                    return {
                        id = "confirm-instance",
                    }
                end),
            },
        })

        local closeActiveModal = closeActiveRouter:pushModal("Confirm")
        local closeActiveScreen = closeActiveRouter:getCurrentScreen()

        local successfulClose = closeActiveModal.context:close()

        assert(successfulClose == closeActiveModal, "modal ctx.close should return the popped modal")
        assert(
            closeActiveRouter:getCurrentModal() == nil,
            "modal ctx.close should close only the active modal layer"
        )
        assert(
            closeActiveRouter:getCurrentScreen() == closeActiveScreen,
            "modal ctx.close should leave the screen stack untouched"
        )
    end,
}
