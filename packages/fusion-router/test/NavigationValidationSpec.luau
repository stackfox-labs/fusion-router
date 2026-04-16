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

local function noop() end

local function createConfig()
    return {
        initialScreen = "MainMenu",
        screens = {
            MainMenu = Router.screen(noop),
            Inventory = Router.screen(noop),
        },
        modals = {
            ConfirmPurchase = Router.modal(noop),
        },
        overlays = {
            Toasts = Router.overlay(noop),
        },
    }
end

return {
    name = "navigation methods reject unknown and wrong-kind routes before mutating state",
    run = function()
        local screenKeyCalls = 0
        local modalKeyCalls = 0
        local router = createRouter(createConfig(), {
            createRuntimeKeyGenerator = function()
                return {
                    nextScreenKey = function()
                        screenKeyCalls += 1

                        return ("screen_%d"):format(screenKeyCalls)
                    end,
                    nextModalKey = function()
                        modalKeyCalls += 1

                        return ("modal_%d"):format(modalKeyCalls)
                    end,
                }
            end,
        })

        local function expectUnchangedState()
            assert(
                #router._state.screenStack == 1,
                "Failed navigation should not change screen stack"
            )
            assert(
                #router._state.modalStack == 0,
                "Failed navigation should not change modal stack"
            )
            assert(
                router:getCurrentScreen().name == "MainMenu",
                "Failed navigation should preserve the current screen"
            )
            assert(router:getCurrentModal() == nil, "Failed navigation should preserve modal state")
            assert(
                screenKeyCalls == 1,
                "Failed screen navigation should not allocate a new screen key"
            )
            assert(
                modalKeyCalls == 0,
                "Failed modal navigation should not allocate a new modal key"
            )
        end

        expectError(function()
            router:push("Missing")
        end, "Router.push expected route 'Missing' to exist in screen")
        expectUnchangedState()

        expectError(
            function()
                router:push("ConfirmPurchase")
            end,
            "Router.push expected route 'ConfirmPurchase' to be a screen route, but it is registered as a modal route"
        )
        expectUnchangedState()

        expectError(function()
            router:replace("Missing")
        end, "Router.replace expected route 'Missing' to exist in screen")
        expectUnchangedState()

        expectError(
            function()
                router:replace("ConfirmPurchase")
            end,
            "Router.replace expected route 'ConfirmPurchase' to be a screen route, but it is registered as a modal route"
        )
        expectUnchangedState()

        expectError(function()
            router:reset("Missing")
        end, "Router.reset expected route 'Missing' to exist in screen")
        expectUnchangedState()

        expectError(
            function()
                router:reset("ConfirmPurchase")
            end,
            "Router.reset expected route 'ConfirmPurchase' to be a screen route, but it is registered as a modal route"
        )
        expectUnchangedState()

        expectError(function()
            router:pushModal("Missing")
        end, "Router.pushModal expected route 'Missing' to exist in modal")
        expectUnchangedState()

        expectError(
            function()
                router:pushModal("MainMenu")
            end,
            "Router.pushModal expected route 'MainMenu' to be a modal route, but it is registered as a screen route"
        )
        expectUnchangedState()
    end,
}
