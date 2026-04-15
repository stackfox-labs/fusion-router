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
    name = "Router.screen normalizes defaults and validates options",
    run = function()
        assert(type(Router.screen) == "function", "Router.screen should be exported")

        local definition = Router.screen(noop)

        assert(
            definition.kind == "screen",
            "Screen definitions should be tagged with kind='screen'"
        )
        assert(
            definition.component == noop,
            "Screen definitions should keep the component reference"
        )
        assert(
            definition.retention == "destroy",
            "Screen definitions should default retention to 'destroy'"
        )
        assert(
            definition.enterTransition == nil,
            "Screen definitions should default enterTransition to nil"
        )
        assert(
            definition.exitTransition == nil,
            "Screen definitions should default exitTransition to nil"
        )
        assert(definition.canEnter == nil, "Screen definitions should default canEnter to nil")
        assert(definition.canExit == nil, "Screen definitions should default canExit to nil")
        assert(definition.onEnter == nil, "Screen definitions should default onEnter to nil")
        assert(definition.onExit == nil, "Screen definitions should default onExit to nil")
        assert(definition.onPause == nil, "Screen definitions should default onPause to nil")
        assert(definition.onResume == nil, "Screen definitions should default onResume to nil")
        assert(
            definition.validateParams == nil,
            "Screen definitions should default validateParams to nil"
        )
        assert(table.isfrozen(definition), "Screen definitions should be frozen")

        local hooks = {
            canEnter = function()
                return true
            end,
            canExit = function()
                return true
            end,
            onEnter = noop,
            onExit = noop,
            onPause = noop,
            onResume = noop,
            validateParams = noop,
        }

        local configured = Router.screen(noop, {
            retention = "keepAlive",
            enterTransition = "slideLeft",
            exitTransition = "slideRight",
            canEnter = hooks.canEnter,
            canExit = hooks.canExit,
            onEnter = hooks.onEnter,
            onExit = hooks.onExit,
            onPause = hooks.onPause,
            onResume = hooks.onResume,
            validateParams = hooks.validateParams,
        })

        assert(configured.retention == "keepAlive", "Configured retention should be preserved")
        assert(
            configured.enterTransition == "slideLeft",
            "Configured enterTransition should be preserved"
        )
        assert(
            configured.exitTransition == "slideRight",
            "Configured exitTransition should be preserved"
        )
        assert(configured.canEnter == hooks.canEnter, "Configured canEnter should be preserved")
        assert(configured.canExit == hooks.canExit, "Configured canExit should be preserved")
        assert(configured.onEnter == hooks.onEnter, "Configured onEnter should be preserved")
        assert(configured.onExit == hooks.onExit, "Configured onExit should be preserved")
        assert(configured.onPause == hooks.onPause, "Configured onPause should be preserved")
        assert(configured.onResume == hooks.onResume, "Configured onResume should be preserved")
        assert(
            configured.validateParams == hooks.validateParams,
            "Configured validateParams should be preserved"
        )

        expectError(function()
            Router.screen("not a function")
        end, "Router.screen expected component to be a function")

        expectError(function()
            Router.screen(noop, "not a table")
        end, "Router.screen expected options to be a table or nil")

        expectError(
            function()
                Router.screen(noop, {
                    retention = "forever",
                })
            end,
            "Router.screen expected options.retention to be one of 'destroy', 'keepAlive', or 'singleton'"
        )

        expectError(function()
            Router.screen(noop, {
                enterTransition = 123,
            })
        end, "Router.screen expected options.enterTransition to be a string or nil")

        expectError(function()
            Router.screen(noop, {
                onEnter = true,
            })
        end, "Router.screen expected options.onEnter to be a function or nil")

        expectError(function()
            Router.screen(noop, {
                unknown = true,
            })
        end, "Router.screen received an unknown option 'unknown'")
    end,
}
