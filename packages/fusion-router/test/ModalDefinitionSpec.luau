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
    name = "Router.modal normalizes defaults and validates options",
    run = function()
        assert(type(Router.modal) == "function", "Router.modal should be exported")

        local definition = Router.modal(noop)

        assert(definition.kind == "modal", "Modal definitions should be tagged with kind='modal'")
        assert(
            definition.component == noop,
            "Modal definitions should keep the component reference"
        )
        assert(definition.transition == nil, "Modal definitions should default transition to nil")
        assert(
            definition.barrierDismiss == false,
            "Modal definitions should default barrierDismiss to false"
        )
        assert(definition.canEnter == nil, "Modal definitions should default canEnter to nil")
        assert(definition.canExit == nil, "Modal definitions should default canExit to nil")
        assert(definition.onEnter == nil, "Modal definitions should default onEnter to nil")
        assert(definition.onExit == nil, "Modal definitions should default onExit to nil")
        assert(
            definition.validateParams == nil,
            "Modal definitions should default validateParams to nil"
        )
        assert(table.isfrozen(definition), "Modal definitions should be frozen")

        local hooks = {
            canEnter = function()
                return true
            end,
            canExit = function()
                return true
            end,
            onEnter = noop,
            onExit = noop,
            validateParams = noop,
        }

        local configured = Router.modal(noop, {
            transition = "fadeScaleIn",
            barrierDismiss = true,
            canEnter = hooks.canEnter,
            canExit = hooks.canExit,
            onEnter = hooks.onEnter,
            onExit = hooks.onExit,
            validateParams = hooks.validateParams,
        })

        assert(configured.transition == "fadeScaleIn", "Configured transition should be preserved")
        assert(configured.barrierDismiss == true, "Configured barrierDismiss should be preserved")
        assert(configured.canEnter == hooks.canEnter, "Configured canEnter should be preserved")
        assert(configured.canExit == hooks.canExit, "Configured canExit should be preserved")
        assert(configured.onEnter == hooks.onEnter, "Configured onEnter should be preserved")
        assert(configured.onExit == hooks.onExit, "Configured onExit should be preserved")
        assert(
            configured.validateParams == hooks.validateParams,
            "Configured validateParams should be preserved"
        )

        expectError(function()
            Router.modal("not a function")
        end, "Router.modal expected component to be a function")

        expectError(function()
            Router.modal(noop, "not a table")
        end, "Router.modal expected options to be a table or nil")

        expectError(function()
            Router.modal(noop, {
                transition = 123,
            })
        end, "Router.modal expected options.transition to be a string or nil")

        expectError(function()
            Router.modal(noop, {
                barrierDismiss = "yes",
            })
        end, "Router.modal expected options.barrierDismiss to be a boolean or nil")

        expectError(function()
            Router.modal(noop, {
                onEnter = true,
            })
        end, "Router.modal expected options.onEnter to be a function or nil")

        expectError(function()
            Router.modal(noop, {
                unknown = true,
            })
        end, "Router.modal received an unknown option 'unknown'")
    end,
}
