local Router = require("../src")
local EntryFactory = require("../src/runtime/entries")

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
    name = "runtime entry factory creates screen modal and overlay records",
    run = function()
        assert(table.isfrozen(EntryFactory), "EntryFactory should be frozen")

        local screenDefinition = Router.screen(noop, {
            retention = "keepAlive",
        })
        local screenEntry =
            EntryFactory.createScreenEntry("Inventory", screenDefinition, "screen_7", {
                category = "Weapons",
            })

        assert(screenEntry.kind == "screen", "Screen entries should be tagged with kind='screen'")
        assert(screenEntry.key == "screen_7", "Screen entries should preserve the runtime key")
        assert(screenEntry.name == "Inventory", "Screen entries should preserve the route name")
        assert(screenEntry.params.category == "Weapons", "Screen entries should preserve params")
        assert(screenEntry.state == "entering", "Screen entries should start in entering state")
        assert(screenEntry.retained == true, "keepAlive screen entries should be retained")
        assert(
            screenEntry.retention == "keepAlive",
            "Screen entries should preserve the retention policy"
        )
        assert(
            screenEntry.definition == screenDefinition,
            "Screen entries should keep the definition reference"
        )
        assert(screenEntry.scope == nil, "Screen entries should start without a scope")
        assert(screenEntry.context == nil, "Screen entries should start without a context")
        assert(screenEntry.instance == nil, "Screen entries should start without an instance")
        assert(
            screenEntry.cleanup == nil,
            "Screen entries should start without cleanup bookkeeping"
        )
        assert(screenEntry.isMounted == false, "Screen entries should start unmounted")
        local destroyScreenEntry =
            EntryFactory.createScreenEntry("Shop", Router.screen(noop), "screen_8")
        assert(
            destroyScreenEntry.retained == false,
            "destroy screen entries should not be retained"
        )
        assert(
            destroyScreenEntry.retention == "destroy",
            "destroy screen entries should default retention to destroy"
        )

        local modalDefinition = Router.modal(noop, {
            barrierDismiss = true,
        })
        local modalEntry =
            EntryFactory.createModalEntry("ConfirmPurchase", modalDefinition, "modal_2", {
                productId = 10,
            })

        assert(modalEntry.kind == "modal", "Modal entries should be tagged with kind='modal'")
        assert(modalEntry.key == "modal_2", "Modal entries should preserve the runtime key")
        assert(modalEntry.name == "ConfirmPurchase", "Modal entries should preserve the route name")
        assert(modalEntry.params.productId == 10, "Modal entries should preserve params")
        assert(modalEntry.state == "entering", "Modal entries should start in entering state")
        assert(
            modalEntry.definition == modalDefinition,
            "Modal entries should keep the definition reference"
        )
        assert(modalEntry.scope == nil, "Modal entries should start without a scope")
        assert(modalEntry.context == nil, "Modal entries should start without a context")
        assert(modalEntry.instance == nil, "Modal entries should start without an instance")
        assert(modalEntry.cleanup == nil, "Modal entries should start without cleanup bookkeeping")
        assert(modalEntry.isMounted == false, "Modal entries should start unmounted")
        local overlayDefinition = Router.overlay(noop, {
            persistent = false,
            visible = true,
        })
        local overlayEntry = EntryFactory.createOverlayEntry("Toasts", overlayDefinition)

        assert(
            overlayEntry.kind == "overlay",
            "Overlay entries should be tagged with kind='overlay'"
        )
        assert(
            overlayEntry.key == "overlay_Toasts",
            "Overlay entries should derive a stable runtime key from the route name"
        )
        assert(overlayEntry.name == "Toasts", "Overlay entries should preserve the route name")
        assert(overlayEntry.persistent == false, "Overlay entries should preserve persistent")
        assert(overlayEntry.visible == true, "Overlay entries should preserve visible")
        assert(overlayEntry.isVisible == false, "Overlay entries should start hidden")
        assert(overlayEntry.state == "inactive", "Overlay entries should start inactive")
        assert(
            overlayEntry.definition == overlayDefinition,
            "Overlay entries should keep the definition reference"
        )
        assert(overlayEntry.scope == nil, "Overlay entries should start without a scope")
        assert(overlayEntry.context == nil, "Overlay entries should start without a context")
        assert(overlayEntry.instance == nil, "Overlay entries should start without an instance")
        assert(
            overlayEntry.cleanup == nil,
            "Overlay entries should start without cleanup bookkeeping"
        )
        assert(overlayEntry.isMounted == false, "Overlay entries should start unmounted")
        assert(
            overlayEntry.visibilityCleanup == nil,
            "Overlay entries should start without visibility subscriptions"
        )
        expectError(function()
            EntryFactory.createScreenEntry("", screenDefinition, "screen_1")
        end, "EntryFactory.createScreenEntry expected route name to be a non-empty string")

        expectError(function()
            EntryFactory.createScreenEntry("Inventory", modalDefinition, "screen_1")
        end, "EntryFactory.createScreenEntry expected definition.kind to be 'screen'")

        expectError(function()
            EntryFactory.createScreenEntry("Inventory", screenDefinition, "")
        end, "EntryFactory.createScreenEntry expected key to be a non-empty string")

        expectError(function()
            EntryFactory.createScreenEntry("Inventory", screenDefinition, "screen_1", "bad")
        end, "EntryFactory.createScreenEntry expected params to be a table or nil")

        expectError(function()
            EntryFactory.createModalEntry("Confirm", overlayDefinition, "modal_1")
        end, "EntryFactory.createModalEntry expected definition.kind to be 'modal'")

        expectError(function()
            EntryFactory.createOverlayEntry("Toasts", screenDefinition)
        end, "EntryFactory.createOverlayEntry expected definition.kind to be 'overlay'")
    end,
}
