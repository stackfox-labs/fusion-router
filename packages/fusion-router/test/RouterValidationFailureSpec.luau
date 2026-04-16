local Router = require("../src")
local createRouter = require("./TestRouter").createRouter

local function expectError(callback, expectedMessage)
    local ok, err = pcall(callback)

    assert(not ok, "Expected callback to throw")
    assert(
        string.find(tostring(err), expectedMessage, 1, true) ~= nil,
        ("Expected error containing %q, got %s"):format(expectedMessage, tostring(err))
    )
end

local function noop() end

return {
    name = "router creation and validation failures stay descriptive across config and navigation misuse",
    run = function()
        expectError(function()
            createRouter(nil)
        end, "Router.create expected config to be a table, got nil")

        expectError(function()
            createRouter({
                initialScreen = "",
                screens = {},
            })
        end, "Router.create expected config.initialScreen to be a non-empty string")

        expectError(function()
            createRouter({
                initialScreen = "MainMenu",
            })
        end, "Router.create expected config.screens to be a table, got nil")

        expectError(function()
            createRouter({
                initialScreen = "MainMenu",
                screens = {
                    MainMenu = Router.modal(noop),
                },
            })
        end, "Router.create expected config.screens.MainMenu to be a screen definition")

        expectError(function()
            createRouter({
                initialScreen = "MainMenu",
                screens = {
                    MainMenu = Router.screen(noop),
                },
                modals = {
                    Confirm = Router.screen(noop),
                },
            })
        end, "Router.create expected config.modals.Confirm to be a modal definition")

        expectError(function()
            createRouter({
                initialScreen = "MainMenu",
                screens = {
                    MainMenu = Router.screen(noop),
                },
                overlays = {
                    HUD = Router.modal(noop),
                },
            })
        end, "Router.create expected config.overlays.HUD to be a overlay definition")

        expectError(function()
            createRouter({
                initialScreen = "MainMenu",
                screens = {
                    MainMenu = Router.screen(noop),
                },
                transitions = true,
            })
        end, "Router.create expected config.transitions to be a table or nil")

        expectError(
            function()
                Router.screen(noop, {
                    retention = "forever",
                })
            end,
            "Router.screen expected options.retention to be one of 'destroy', 'keepAlive', or 'singleton'"
        )

        expectError(function()
            Router.modal(noop, {
                barrierDismiss = "yes",
            })
        end, "Router.modal expected options.barrierDismiss to be a boolean or nil")

        expectError(function()
            Router.overlay(noop, {
                persistent = "yes",
            })
        end, "Router.overlay expected options.persistent to be a boolean or nil")

        local router = createRouter({
            initialScreen = "MainMenu",
            screens = {
                MainMenu = Router.screen(noop),
                Inventory = Router.screen(noop),
            },
            modals = {
                Confirm = Router.modal(noop),
            },
            overlays = {
                HUD = Router.overlay(noop),
            },
        })

        local currentScreen = router:getCurrentScreen()

        expectError(function()
            router:push("Missing")
        end, "Router.push expected route 'Missing' to exist in screen")

        expectError(
            function()
                router:replace("Confirm")
            end,
            "Router.replace expected route 'Confirm' to be a screen route, but it is registered as a modal route"
        )

        expectError(
            function()
                router:reset("HUD")
            end,
            "Router.reset expected route 'HUD' to be a screen route, but it is registered as a overlay route"
        )

        expectError(
            function()
                router:pushModal("MainMenu")
            end,
            "Router.pushModal expected route 'MainMenu' to be a modal route, but it is registered as a screen route"
        )

        assert(
            router:getCurrentScreen() == currentScreen,
            "Validation failures should leave the active screen unchanged"
        )
        assert(
            router:getCurrentModal() == nil
                and #router._state.screenStack == 1
                and #router._state.modalStack == 0,
            "Validation failures should leave router stacks unchanged"
        )
    end,
}
