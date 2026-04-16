local TestRouter = require("./TestRouter")
local createRouter = TestRouter.createRouter
local fusion = TestRouter.fusion
local Router = require("../src")

local function findOverlay(router, routeName)
    for _, entry in router._state.overlayEntries do
        if entry.name == routeName then
            return entry
        end
    end

    error(("Expected overlay entry %q to exist"):format(routeName))
end

return {
    name = "overlay runtime registration visibility lifecycle and back behavior work independently",
    run = function()
        local callLog = {}
        local hudVisible = fusion:scoped():Value(false)
        local toastVisible = fusion:scoped():Value(false)
        local screenCalls = 0

        local router = createRouter({
            initialScreen = "MainMenu",
            screens = {
                MainMenu = Router.screen(function()
                    screenCalls += 1

                    return {
                        id = ("screen-%d"):format(screenCalls),
                    }
                end),
                Inventory = Router.screen(function()
                    screenCalls += 1

                    return {
                        id = ("screen-%d"):format(screenCalls),
                    }
                end),
            },
            overlays = {
                HUD = Router.overlay(function(context)
                    table.insert(
                        callLog,
                        ("hud:component:%s"):format(tostring(context.isActive.value))
                    )

                    return {
                        id = "hud-instance",
                    }
                end, {
                    visible = hudVisible,
                    onEnter = function(context)
                        table.insert(
                            callLog,
                            ("hud:onEnter:%s"):format(tostring(context.isActive.value))
                        )
                    end,
                    onExit = function()
                        table.insert(callLog, "hud:onExit")
                    end,
                }),
                Toasts = Router.overlay(function(context)
                    table.insert(
                        callLog,
                        ("toasts:component:%s"):format(tostring(context.isActive.value))
                    )

                    return {
                        id = "toasts-instance",
                    }
                end, {
                    persistent = false,
                    visible = toastVisible,
                    onEnter = function(context)
                        table.insert(
                            callLog,
                            ("toasts:onEnter:%s"):format(tostring(context.isActive.value))
                        )
                    end,
                    onExit = function()
                        table.insert(callLog, "toasts:onExit")
                    end,
                }),
            },
        })

        local hudEntry = findOverlay(router, "HUD")
        local toastEntry = findOverlay(router, "Toasts")

        assert(
            #router._state.overlayEntries == 2,
            "Router should register every overlay definition into runtime overlay state"
        )
        assert(hudEntry.kind == "overlay", "Registered overlays should stay tagged as overlays")
        assert(hudEntry.isMounted == true, "Persistent overlays should mount on router creation")
        assert(
            hudEntry.isVisible == false,
            "Reactive hidden overlays should track hidden visibility"
        )
        assert(hudEntry.state == "hidden", "Hidden persistent overlays should remain mounted")
        assert(
            hudEntry.context.routeKey == "overlay_HUD",
            "Overlay contexts should expose their stable overlay route key"
        )
        assert(
            hudEntry.context.isActive.value == false,
            "Persistent overlays should start inactive while hidden"
        )
        assert(
            toastEntry.isMounted == false,
            "Non-persistent hidden overlays should stay unmounted"
        )
        assert(
            toastEntry.state == "inactive",
            "Non-persistent hidden overlays should remain inactive"
        )
        assert(
            callLog[1] == "hud:component:false" and callLog[2] == "hud:onEnter:false",
            "Persistent overlays should mount and enter even when their reactive visibility is false"
        )
        assert(
            not table.find(callLog, "toasts:onEnter:false"),
            "Hidden non-persistent overlays should not mount or run lifecycle hooks"
        )

        local rootBackResult = router:back()
        assert(rootBackResult == nil, "router:back should ignore overlays at root depth")
        assert(
            hudEntry.isMounted == true and toastEntry.isMounted == false,
            "Back navigation should not mutate overlay mount state"
        )

        router:push("Inventory")
        router:back()
        assert(
            hudEntry.isMounted == true and toastEntry.isMounted == false,
            "Screen navigation should not tear down overlays"
        )

        toastVisible:set(true)
        assert(
            toastEntry.isMounted == true and toastEntry.isVisible == true,
            "Visible non-persistent overlays should mount when their reactive visible source flips true"
        )
        assert(
            toastEntry.context.isActive.value == true,
            "Mounted visible overlays should become active in their own layer"
        )
        assert(
            table.find(callLog, "toasts:component:false") ~= nil
                and table.find(callLog, "toasts:onEnter:false") ~= nil,
            "Non-persistent overlays should run component and onEnter when they mount"
        )

        toastVisible:set(false)
        assert(
            toastEntry.isMounted == false and toastEntry.state == "inactive",
            "Non-persistent overlays should unmount when their reactive visible source flips false"
        )
        assert(
            table.find(callLog, "toasts:onExit") ~= nil,
            "Unmounted non-persistent overlays should run onExit"
        )

        hudVisible:set(true)
        assert(
            hudEntry.isMounted == true and hudEntry.isVisible == true,
            "Persistent overlays should stay mounted and only update visibility when they become visible"
        )
        assert(
            hudEntry.context.isActive.value == true,
            "Visible persistent overlays should become active without remounting"
        )

        hudVisible:set(false)
        assert(
            hudEntry.isMounted == true and hudEntry.state == "hidden",
            "Persistent overlays should stay mounted when they become hidden again"
        )
        assert(
            not table.find(callLog, "hud:onExit"),
            "Persistent overlays should not run onExit when visibility alone changes"
        )

        local overlayCountBeforeReset = #router._state.overlayEntries
        router:reset("MainMenu")
        assert(
            #router._state.overlayEntries == overlayCountBeforeReset,
            "router:reset should preserve independently registered overlays"
        )
        assert(
            findOverlay(router, "HUD") == hudEntry,
            "router:reset should not recreate persistent overlay entries"
        )
    end,
}
