local createRouter = require("../src/runtime/createRouter")
local Router = require("../src")

local function expectError(callback, expectedMessage)
    local ok, err = pcall(callback)

    assert(not ok, "Expected callback to throw")
    assert(
        string.find(tostring(err), expectedMessage, 1, true) ~= nil,
        ("Expected error containing %q, got %s"):format(expectedMessage, tostring(err))
    )
end

return {
    name = "router pushModal validates guards mounts and selects modal transitions",
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
                Confirm = Router.modal(function(ctx)
                    table.insert(callLog, "confirm:component")

                    return {
                        id = "confirm-instance",
                        context = ctx,
                    }
                end, {
                    validateParams = function(params)
                        table.insert(callLog, "confirm:validateParams")
                        assert(type(params.productId) == "number", "productId must be a number")
                    end,
                    canEnter = function(ctx)
                        table.insert(callLog, "confirm:canEnter")
                        assert(
                            ctx.routeName == "Confirm",
                            "modal canEnter should receive modal context"
                        )

                        return true
                    end,
                    onEnter = function()
                        table.insert(callLog, "confirm:onEnter")
                    end,
                    transition = "fadeScaleIn",
                }),
                Settings = Router.modal(function(ctx)
                    table.insert(callLog, "settings:component")

                    return {
                        id = "settings-instance",
                        context = ctx,
                    }
                end, {
                    onEnter = function()
                        table.insert(callLog, "settings:onEnter")
                    end,
                }),
                Locked = Router.modal(function()
                    table.insert(callLog, "locked:component")

                    return {
                        id = "locked-instance",
                    }
                end, {
                    canEnter = function()
                        table.insert(callLog, "locked:canEnter")

                        return false
                    end,
                    onEnter = function()
                        table.insert(callLog, "locked:onEnter")
                    end,
                }),
            },
            transitions = {
                modalOpen = "fade",
            },
        })

        callLog = {}

        local confirmEntry = router:pushModal("Confirm", {
            productId = 42,
        })

        assert(confirmEntry == router:getCurrentModal(), "pushModal should activate the new modal")
        assert(#router._state.modalStack == 1, "pushModal should append the modal to the stack")
        assert(
            callLog[1] == "confirm:validateParams"
                and callLog[2] == "confirm:canEnter"
                and callLog[3] == "confirm:component"
                and callLog[4] == "confirm:onEnter",
            "pushModal should validate, guard, mount, and then enter in order"
        )
        assert(confirmEntry.scope ~= nil, "pushModal should attach a scope to the modal entry")
        assert(confirmEntry.context ~= nil, "pushModal should create route context for the modal")
        assert(
            confirmEntry.context.params.productId == 42,
            "pushModal should expose modal params through context"
        )
        assert(confirmEntry.instance.id == "confirm-instance", "pushModal should mount the modal")
        assert(confirmEntry.isMounted == true, "pushModal should mark the modal mounted")
        assert(confirmEntry.state == "active", "pushModal should leave the modal active")
        assert(
            confirmEntry.context.isActive.value == true,
            "pushModal should mark the new modal as active"
        )
        assert(
            router._state.currentTransition == "fadeScaleIn",
            "pushModal should prefer the modal transition override when selecting transitions"
        )

        callLog = {}

        local settingsEntry = router:pushModal("Settings")

        assert(settingsEntry == router:getCurrentModal(), "pushModal should update the top modal")
        assert(#router._state.modalStack == 2, "pushModal should support modal stacking")
        assert(
            confirmEntry.context.isActive.value == false,
            "pushModal should deactivate the previously topmost modal"
        )
        assert(
            settingsEntry.context.isActive.value == true,
            "pushModal should activate the newly pushed topmost modal"
        )
        assert(
            router._state.currentTransition == "fade",
            "pushModal should fall back to the global modalOpen transition when no override exists"
        )
        assert(
            callLog[1] == "settings:component" and callLog[2] == "settings:onEnter",
            "pushModal should still mount and enter modals without extra guards"
        )

        callLog = {}

        local rejectedEntry = router:pushModal("Locked")

        assert(rejectedEntry == nil, "pushModal should return nil when canEnter blocks opening")
        assert(
            #router._state.modalStack == 2,
            "guard-blocked pushModal should not mutate the modal stack"
        )
        assert(
            router:getCurrentModal() == settingsEntry,
            "guard-blocked pushModal should preserve the active modal"
        )
        assert(
            callLog[1] == "locked:canEnter",
            "pushModal should run canEnter before mounting blocked modals"
        )
        assert(#callLog == 1, "guard-blocked pushModal should stop before mounting or onEnter")

        callLog = {}

        expectError(function()
            router:pushModal("Confirm", {
                productId = "bad",
            })
        end, "productId must be a number")

        assert(
            #router._state.modalStack == 2,
            "param validation failures should not mutate the modal stack"
        )
        assert(
            router:getCurrentModal() == settingsEntry,
            "param failures should preserve the active modal"
        )
        assert(
            callLog[1] == "confirm:validateParams",
            "pushModal should validate route params before guards or mount work"
        )
        assert(#callLog == 1, "param validation failures should stop before further modal work")
    end,
}
