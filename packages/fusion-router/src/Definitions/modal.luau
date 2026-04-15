local Validation = require("../shared/validation")

local VALID_OPTION_NAMES = {
    transition = true,
    barrierDismiss = true,
    canEnter = true,
    canExit = true,
    onEnter = true,
    onExit = true,
    validateParams = true,
}

local function validateOptions(options)
    if options == nil then
        return
    end

    Validation.expectTableOrNil("Router.modal", options, "options", 2)
    Validation.rejectUnknownOptions("Router.modal", options, VALID_OPTION_NAMES, 2)

    for optionName, optionValue in options do
        if optionName == "transition" then
            Validation.expectOptionalString("Router.modal", optionValue, "options.transition", 2)
        elseif optionName == "barrierDismiss" then
            Validation.expectOptionalBoolean(
                "Router.modal",
                optionValue,
                "options.barrierDismiss",
                2
            )
        else
            Validation.expectOptionalFunction(
                "Router.modal",
                optionValue,
                ("options.%s"):format(optionName),
                2
            )
        end
    end
end

local function modal(component, options)
    Validation.expectFunction("Router.modal", component, "component", 1)

    validateOptions(options)

    local normalizedOptions = options or {}
    local definition = {
        kind = "modal",
        component = component,
        transition = normalizedOptions.transition,
        barrierDismiss = normalizedOptions.barrierDismiss or false,
        canEnter = normalizedOptions.canEnter,
        canExit = normalizedOptions.canExit,
        onEnter = normalizedOptions.onEnter,
        onExit = normalizedOptions.onExit,
        validateParams = normalizedOptions.validateParams,
    }

    return table.freeze(definition)
end

return modal
