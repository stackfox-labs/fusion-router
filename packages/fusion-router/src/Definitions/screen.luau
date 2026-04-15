local Validation = require("../shared/validation")

local VALID_RETENTION_POLICIES = {
    destroy = true,
    keepAlive = true,
    singleton = true,
}

local VALID_OPTION_NAMES = {
    retention = true,
    enterTransition = true,
    exitTransition = true,
    canEnter = true,
    canExit = true,
    onEnter = true,
    onExit = true,
    onPause = true,
    onResume = true,
    validateParams = true,
}

local function validateOptions(options)
    if options == nil then
        return
    end

    Validation.expectTableOrNil("Router.screen", options, "options", 2)
    Validation.rejectUnknownOptions("Router.screen", options, VALID_OPTION_NAMES, 2)

    for optionName, optionValue in options do
        if optionName == "retention" then
            Validation.expectOptionalEnumString(
                "Router.screen",
                optionValue,
                "options.retention",
                VALID_RETENTION_POLICIES,
                "'destroy', 'keepAlive', or 'singleton'",
                2
            )
        elseif optionName == "enterTransition" or optionName == "exitTransition" then
            Validation.expectOptionalString(
                "Router.screen",
                optionValue,
                ("options.%s"):format(optionName),
                2
            )
        else
            Validation.expectOptionalFunction(
                "Router.screen",
                optionValue,
                ("options.%s"):format(optionName),
                2
            )
        end
    end
end

local function screen(component, options)
    Validation.expectFunction("Router.screen", component, "component", 1)

    validateOptions(options)

    local normalizedOptions = options or {}
    local definition = {
        kind = "screen",
        component = component,
        retention = normalizedOptions.retention or "destroy",
        enterTransition = normalizedOptions.enterTransition,
        exitTransition = normalizedOptions.exitTransition,
        canEnter = normalizedOptions.canEnter,
        canExit = normalizedOptions.canExit,
        onEnter = normalizedOptions.onEnter,
        onExit = normalizedOptions.onExit,
        onPause = normalizedOptions.onPause,
        onResume = normalizedOptions.onResume,
        validateParams = normalizedOptions.validateParams,
    }

    return table.freeze(definition)
end

return screen
