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
            MainMenu = Router.screen(noop, {
                retention = "singleton",
            }),
            Inventory = Router.screen(noop),
        },
        modals = {
            ConfirmPurchase = Router.modal(noop),
        },
        overlays = {
            Toasts = Router.overlay(noop),
        },
        transitions = {
            screenPush = "slideLeft",
        },
    }
end

return {
    name = "Router.create validates first and builds router state registries and method surface",
    run = function()
        local keyGeneratorFactoryCalls = 0
        local screenKeyCalls = 0
        local fakeKeyGenerator = {
            nextScreenKey = function()
                screenKeyCalls += 1

                return ("screen_boot_%d"):format(screenKeyCalls)
            end,

            nextModalKey = function()
                return "modal_test"
            end,
        }

        local router = createRouter(createConfig(), {
            createRuntimeKeyGenerator = function()
                keyGeneratorFactoryCalls += 1

                return fakeKeyGenerator
            end,
        })

        assert(table.isfrozen(router), "Router instances should be frozen")
        assert(keyGeneratorFactoryCalls == 1, "Router.create should create one key generator")
        assert(
            router._state.initialScreen == "MainMenu",
            "Router should store initialScreen in state"
        )
        assert(
            type(router._state.screenStack) == "table",
            "Router should initialize a screen stack"
        )
        assert(type(router._state.modalStack) == "table", "Router should initialize a modal stack")
        assert(
            type(router._state.overlayEntries) == "table",
            "Router should initialize overlay state"
        )
        assert(
            type(router._state.retainedScreens) == "table",
            "Router should initialize retained screen state"
        )
        assert(
            router._state.currentTransition == nil,
            "Router should initialize without an active transition"
        )
        assert(router._registries.screens.MainMenu ~= nil, "Router should keep screen registries")
        assert(
            router._registries.modals.ConfirmPurchase ~= nil,
            "Router should keep modal registries"
        )
        assert(router._registries.overlays.Toasts ~= nil, "Router should keep overlay registries")
        assert(
            router._registries.transitions.screenPush == "slideLeft",
            "Router should keep transition registries"
        )
        assert(
            router._runtime.keyGenerator == fakeKeyGenerator,
            "Router should store the key generator"
        )
        assert(
            #router._state.screenStack == 1,
            "Router.create should bootstrap one initial screen entry"
        )
        assert(
            router._state.screenStack[1].name == "MainMenu",
            "Router.create should bootstrap the configured initial screen"
        )
        assert(
            router._state.screenStack[1].key == "screen_boot_1",
            "The bootstrapped initial screen should use the screen key generator"
        )
        assert(
            router:getCurrentScreen() == router._state.screenStack[1],
            "The bootstrapped initial screen should be the current screen"
        )
        assert(
            router:getCurrentScreen().retention == "singleton",
            "The bootstrapped initial screen should preserve its definition metadata"
        )
        assert(
            router:getScreenParams() == nil,
            "The bootstrapped initial screen should expose nil params by default"
        )
        assert(router:canGoBack() == false, "A fresh router should not be able to go back")

        assert(type(router.push) == "function", "Router should expose push")
        assert(type(router.replace) == "function", "Router should expose replace")
        assert(type(router.back) == "function", "Router should expose back")
        assert(type(router.reset) == "function", "Router should expose reset")
        assert(type(router.pushModal) == "function", "Router should expose pushModal")
        assert(type(router.popModal) == "function", "Router should expose popModal")
        assert(type(router.closeAllModals) == "function", "Router should expose closeAllModals")
        assert(type(router.getCurrentScreen) == "function", "Router should expose getCurrentScreen")
        assert(type(router.getCurrentModal) == "function", "Router should expose getCurrentModal")
        assert(type(router.getScreenParams) == "function", "Router should expose getScreenParams")
        assert(type(router.canGoBack) == "function", "Router should expose canGoBack")

        local pushedEntry = router:push("Inventory")
        assert(
            pushedEntry.key == "screen_boot_2",
            "Subsequent screen pushes should continue from the bootstrapped initial screen"
        )
        assert(router:canGoBack() == true, "Routers with two screens should be able to go back")

        local invalidFactoryCalls = 0

        expectError(function()
            createRouter({
                initialScreen = "Missing",
                screens = {
                    MainMenu = Router.screen(noop),
                },
            }, {
                createRuntimeKeyGenerator = function()
                    invalidFactoryCalls += 1

                    return fakeKeyGenerator
                end,
            })
        end, "Router.create expected initialScreen 'Missing' to exist in config.screens")

        assert(
            invalidFactoryCalls == 0,
            "Router.create should validate config before creating runtime state"
        )

        expectError(function()
            Router.create({
                initialScreen = "Missing",
                screens = {
                    MainMenu = Router.screen(noop),
                },
            })
        end, "Router.create expected initialScreen 'Missing' to exist in config.screens")
    end,
}
