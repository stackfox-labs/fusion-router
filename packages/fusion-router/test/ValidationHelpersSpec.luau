local Validation = require("../src/shared/validation")
local Router = require("../src")

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
    name = "shared validation helpers validate route names and router config",
    run = function()
        Validation.expectRouteName("Router.push", "Inventory")

        local config = Validation.validateRouterConfig({
            initialScreen = "MainMenu",
            screens = {
                MainMenu = Router.screen(noop),
            },
            modals = {
                Confirm = Router.modal(noop),
            },
            overlays = {
                Toasts = Router.overlay(noop),
            },
            transitions = {
                screenPush = "slideLeft",
            },
        })

        assert(
            config.initialScreen == "MainMenu",
            "validateRouterConfig should return the config table"
        )

        expectError(function()
            Validation.expectRouteName("Router.push", "")
        end, "Router.push expected route name to be a non-empty string")

        expectError(function()
            Validation.validateRouterConfig(nil)
        end, "Router.create expected config to be a table, got nil")

        expectError(function()
            Validation.validateRouterConfig({
                initialScreen = "",
                screens = {
                    MainMenu = Router.screen(noop),
                },
            })
        end, "Router.create expected config.initialScreen to be a non-empty string")

        expectError(function()
            Validation.validateRouterConfig({
                initialScreen = "MainMenu",
            })
        end, "Router.create expected config.screens to be a table, got nil")

        expectError(function()
            Validation.validateRouterConfig({
                initialScreen = "Missing",
                screens = {
                    MainMenu = Router.screen(noop),
                },
            })
        end, "Router.create expected initialScreen 'Missing' to exist in config.screens")

        expectError(function()
            Validation.validateRouterConfig({
                initialScreen = "MainMenu",
                screens = {
                    MainMenu = Router.modal(noop),
                },
            })
        end, "Router.create expected config.screens.MainMenu to be a screen definition")

        expectError(function()
            Validation.validateRouterConfig({
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
            Validation.validateRouterConfig({
                initialScreen = "MainMenu",
                screens = {
                    MainMenu = Router.screen(noop),
                },
                overlays = {
                    Toasts = Router.modal(noop),
                },
            })
        end, "Router.create expected config.overlays.Toasts to be a overlay definition")

        expectError(function()
            Validation.validateRouterConfig({
                initialScreen = "MainMenu",
                screens = {
                    [""] = Router.screen(noop),
                },
            })
        end, "Router.create expected route name to be a non-empty string")
    end,
}
