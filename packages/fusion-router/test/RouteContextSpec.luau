local createRouteContext = require("../src/runtime/routeContext")
local EntryFactory = require("../src/runtime/entries")
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
    name = "route context exposes mounted entry fields and delegates navigation methods",
    run = function()
        local calls = {}
        local fakeRouter = {
            push = function(_, name, params)
                table.insert(calls, {
                    method = "push",
                    name = name,
                    params = params,
                })
            end,

            replace = function(_, name, params)
                table.insert(calls, {
                    method = "replace",
                    name = name,
                    params = params,
                })
            end,

            back = function()
                table.insert(calls, {
                    method = "back",
                })
            end,

            reset = function(_, name, params)
                table.insert(calls, {
                    method = "reset",
                    name = name,
                    params = params,
                })
            end,

            pushModal = function(_, name, params)
                table.insert(calls, {
                    method = "pushModal",
                    name = name,
                    params = params,
                })
            end,

            popModal = function()
                table.insert(calls, {
                    method = "popModal",
                })
            end,
        }

        local isActiveState = {
            tag = "active-state",
        }
        local screenEntry =
            EntryFactory.createScreenEntry("Inventory", Router.screen(noop), "screen_4", {
                category = "Weapons",
            })
        screenEntry.scope = {
            id = "scope-screen-4",
        }

        local screenContext = createRouteContext(screenEntry, fakeRouter, isActiveState)

        assert(table.isfrozen(screenContext), "Route contexts should be frozen")
        assert(screenEntry.context == screenContext, "Route contexts should be stored on the entry")
        assert(screenContext.scope == screenEntry.scope, "Route contexts should expose entry.scope")
        assert(screenContext.router == fakeRouter, "Route contexts should expose the router")
        assert(
            screenContext.params.category == "Weapons",
            "Route contexts should expose entry params"
        )
        assert(
            screenContext.routeName == "Inventory",
            "Route contexts should expose the route name"
        )
        assert(screenContext.routeKey == "screen_4", "Route contexts should expose the route key")
        assert(
            screenContext.isActive == isActiveState,
            "Route contexts should expose the supplied isActive value"
        )

        screenContext:push("Shop", {
            page = "Featured",
        })
        screenContext.replace("MainMenu", {
            origin = "Inventory",
        })
        screenContext:back()
        screenContext.reset("MainMenu")
        screenContext:pushModal("ItemDetails", {
            itemId = "sword_01",
        })
        screenContext.popModal()
        screenContext:close()

        assert(#calls == 7, "Screen context should delegate every navigation method")
        assert(calls[1].method == "push", "ctx:push should call router.push")
        assert(calls[1].name == "Shop", "ctx:push should forward the route name")
        assert(calls[1].params.page == "Featured", "ctx:push should forward params")
        assert(calls[2].method == "replace", "ctx.replace should call router.replace")
        assert(calls[2].name == "MainMenu", "ctx.replace should forward the route name")
        assert(
            calls[2].params.origin == "Inventory",
            "ctx.replace should forward params in dot-call form"
        )
        assert(calls[3].method == "back", "ctx:back should call router.back")
        assert(calls[4].method == "reset", "ctx.reset should call router.reset")
        assert(calls[4].name == "MainMenu", "ctx.reset should forward the route name")
        assert(calls[5].method == "pushModal", "ctx:pushModal should call router.pushModal")
        assert(calls[5].params.itemId == "sword_01", "ctx:pushModal should forward params")
        assert(calls[6].method == "popModal", "ctx.popModal should call router.popModal")
        assert(calls[7].method == "back", "screen ctx:close should route to router.back")

        local modalEntry =
            EntryFactory.createModalEntry("ConfirmPurchase", Router.modal(noop), "modal_3", {
                productId = 77,
            })
        modalEntry.scope = {
            id = "scope-modal-3",
        }

        local modalContext = createRouteContext(modalEntry, fakeRouter)
        modalContext:close()

        assert(calls[8].method == "popModal", "modal ctx:close should route to router.popModal")

        expectError(function()
            createRouteContext(nil, fakeRouter)
        end, "createRouteContext expected entry to be a table, got nil")

        expectError(function()
            createRouteContext(
                EntryFactory.createOverlayEntry("Toasts", Router.overlay(noop)),
                fakeRouter
            )
        end, "createRouteContext expected entry.kind to be 'screen' or 'modal'")

        expectError(function()
            createRouteContext(
                EntryFactory.createScreenEntry("Inventory", Router.screen(noop), "screen_5"),
                fakeRouter
            )
        end, "createRouteContext expected entry.scope to be a table, got nil")

        expectError(function()
            createRouteContext(screenEntry, nil)
        end, "createRouteContext expected router to be a table, got nil")

        expectError(function()
            createRouteContext(screenEntry, {
                push = noop,
            })
        end, "createRouteContext expected router.replace to be a function")
    end,
}
