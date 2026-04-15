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
    name = "Router.overlay normalizes defaults and validates options",
    run = function()
        assert(type(Router.overlay) == "function", "Router.overlay should be exported")

        local definition = Router.overlay(noop)

        assert(
            definition.kind == "overlay",
            "Overlay definitions should be tagged with kind='overlay'"
        )
        assert(
            definition.component == noop,
            "Overlay definitions should keep the component reference"
        )
        assert(
            definition.persistent == true,
            "Overlay definitions should default persistent to true"
        )
        assert(definition.visible == nil, "Overlay definitions should default visible to nil")
        assert(definition.onEnter == nil, "Overlay definitions should default onEnter to nil")
        assert(definition.onExit == nil, "Overlay definitions should default onExit to nil")
        assert(table.isfrozen(definition), "Overlay definitions should be frozen")

        local reactiveVisible = {
            kind = "reactive visible sentinel",
        }

        local configured = Router.overlay(noop, {
            persistent = false,
            visible = reactiveVisible,
            onEnter = noop,
            onExit = noop,
        })

        assert(configured.persistent == false, "Configured persistent should be preserved")
        assert(configured.visible == reactiveVisible, "Configured visible should be preserved")
        assert(configured.onEnter == noop, "Configured onEnter should be preserved")
        assert(configured.onExit == noop, "Configured onExit should be preserved")

        expectError(function()
            Router.overlay("not a function")
        end, "Router.overlay expected component to be a function")

        expectError(function()
            Router.overlay(noop, "not a table")
        end, "Router.overlay expected options to be a table or nil")

        expectError(function()
            Router.overlay(noop, {
                persistent = "yes",
            })
        end, "Router.overlay expected options.persistent to be a boolean or nil")

        expectError(function()
            Router.overlay(noop, {
                onEnter = true,
            })
        end, "Router.overlay expected options.onEnter to be a function or nil")

        expectError(function()
            Router.overlay(noop, {
                unknown = true,
            })
        end, "Router.overlay received an unknown option 'unknown'")
    end,
}
