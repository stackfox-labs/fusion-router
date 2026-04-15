local Validation = require("../shared/validation")

local VALID_OPTION_NAMES = {
    persistent = true,
    visible = true,
    onEnter = true,
    onExit = true,
}

local function validateOptions(options)
    if options == nil then
        return
    end

    Validation.expectTableOrNil("Router.overlay", options, "options", 2)
    Validation.rejectUnknownOptions("Router.overlay", options, VALID_OPTION_NAMES, 2)

    for optionName, optionValue in options do
        if optionName == "persistent" then
            Validation.expectOptionalBoolean("Router.overlay", optionValue, "options.persistent", 2)
        elseif optionName ~= "visible" then
            Validation.expectOptionalFunction(
                "Router.overlay",
                optionValue,
                ("options.%s"):format(optionName),
                2
            )
        end
    end
end

local function overlay(component, options)
    Validation.expectFunction("Router.overlay", component, "component", 1)

    validateOptions(options)

    local normalizedOptions = options or {}
    local definition = {
        kind = "overlay",
        component = component,
        persistent = if normalizedOptions.persistent == nil
            then true
            else normalizedOptions.persistent,
        visible = normalizedOptions.visible,
        onEnter = normalizedOptions.onEnter,
        onExit = normalizedOptions.onExit,
    }

    return table.freeze(definition)
end

return overlay
