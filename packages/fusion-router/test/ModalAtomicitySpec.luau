local createRouter = require("../src/runtime/createRouter")
local Router = require("../src")

return {
    name = "modal guard failures leave modal state unchanged across close paths",
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
                }),
            },
        })

        local confirmEntry = router:pushModal("Confirm")
        local blockingEntry = router:pushModal("Blocking")
        callLog = {}

        local closed = router:closeAllModals()

        assert(#closed == 0, "closeAllModals should abort atomically when any modal blocks exit")
        assert(
            #router._state.modalStack == 2,
            "closeAllModals guard failure should preserve modal stack depth"
        )
        assert(
            router:getCurrentModal() == blockingEntry,
            "closeAllModals guard failure should preserve the active modal"
        )
        assert(
            confirmEntry.context.isActive.value == false,
            "closeAllModals guard failure should preserve lower modal inactive state"
        )
        assert(
            blockingEntry.context.isActive.value == true,
            "closeAllModals guard failure should preserve top modal active state"
        )
        assert(
            callLog[1] == "blocking:canExit",
            "closeAllModals should check the topmost modal before mutating state"
        )
        assert(#callLog == 1, "closeAllModals should stop at the first blocking modal")
    end,
}
