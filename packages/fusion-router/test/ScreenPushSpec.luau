local createRouter = require("./TestRouter").createRouter
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
    name = "router push validates params runs guards and mounts screens in order",
    run = function()
        local callLog = {}
        local router = createRouter({
            initialScreen = "MainMenu",
            screens = {
                MainMenu = Router.screen(function(ctx)
                    table.insert(callLog, "main:component")

                    return {
                        id = "main-instance",
                        context = ctx,
                    }
                end, {
                    retention = "keepAlive",
                    onEnter = function()
                        table.insert(callLog, "main:onEnter")
                    end,
                    onPause = function()
                        table.insert(callLog, "main:onPause")
                    end,
                }),
                Inventory = Router.screen(function(ctx)
                    table.insert(callLog, "inventory:component")

                    return {
                        id = "inventory-instance",
                        context = ctx,
                    }
                end, {
                    validateParams = function(params)
                        table.insert(callLog, "inventory:validateParams")
                        assert(type(params.category) == "string", "category must be a string")
                    end,
                    canEnter = function(ctx)
                        table.insert(callLog, "inventory:canEnter")
                        assert(
                            ctx.routeName == "Inventory",
                            "canEnter should receive the entry context"
                        )

                        return true
                    end,
                    onEnter = function()
                        table.insert(callLog, "inventory:onEnter")
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
                    onEnter = function()
                        table.insert(callLog, "locked:onEnter")
                    end,
                }),
            },
        })

        local mainEntry = router:getCurrentScreen()
        callLog = {}

        local pushedEntry = router:push("Inventory", {
            category = "Weapons",
        })

        assert(pushedEntry ~= nil, "push should return the mounted screen entry on success")
        assert(#router._state.screenStack == 2, "push should add a second screen entry")
        assert(router:getCurrentScreen() == pushedEntry, "push should make the new screen active")
        assert(
            callLog[1] == "inventory:validateParams"
                and callLog[2] == "inventory:canEnter"
                and callLog[3] == "main:onPause"
                and callLog[4] == "inventory:component"
                and callLog[5] == "inventory:onEnter",
            "push should validate, guard, pause, mount, and then enter in order"
        )
        assert(mainEntry.state == "paused", "Retained outgoing screens should become paused")
        assert(mainEntry.isMounted == true, "Retained outgoing screens should stay mounted")
        assert(
            mainEntry.context.isActive.value == false,
            "Retained outgoing screens should become inactive"
        )
        assert(
            router._state.retainedScreens[mainEntry.key] == mainEntry,
            "Retained outgoing screens should be tracked in retainedScreens"
        )
        assert(pushedEntry.state == "active", "Mounted pushed screens should become active")
        assert(pushedEntry.scope ~= nil, "Mounted pushed screens should get a scope")
        assert(pushedEntry.context ~= nil, "Mounted pushed screens should get route context")
        assert(
            pushedEntry.context.params.category == "Weapons",
            "Mounted pushed screens should expose params through context"
        )
        assert(
            pushedEntry.context.isActive.value == true,
            "Mounted pushed screens should start active"
        )
        assert(
            pushedEntry.instance.id == "inventory-instance",
            "Mounted pushed screens should store the component return value as the instance"
        )
        assert(pushedEntry.isMounted == true, "Mounted pushed screens should be marked mounted")

        callLog = {}

        local rejectedEntry = router:push("Locked")

        assert(rejectedEntry == nil, "push should return nil when canEnter blocks navigation")
        assert(
            #router._state.screenStack == 2,
            "Guard-cancelled pushes should not mutate screen stack state"
        )
        assert(
            router:getCurrentScreen() == pushedEntry,
            "Guard-cancelled pushes should preserve the active screen"
        )
        assert(callLog[1] == "locked:canEnter", "push should run canEnter before mounting")
        assert(#callLog == 1, "Guard-cancelled pushes should not pause or mount anything")

        callLog = {}

        expectError(function()
            router:push("Inventory", {
                category = 10,
            })
        end, "category must be a string")

        assert(
            #router._state.screenStack == 2,
            "Param validation failures should not mutate screen stack state"
        )
        assert(
            router:getCurrentScreen() == pushedEntry,
            "Param validation failures should preserve the active screen"
        )
        assert(
            callLog[1] == "inventory:validateParams",
            "push should validate route params before guards or mounting"
        )
        assert(
            #callLog == 1,
            "Param validation failures should stop before further navigation work"
        )
    end,
}
