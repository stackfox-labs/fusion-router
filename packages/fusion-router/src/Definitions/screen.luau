local VALID_RETENTION_POLICIES = {
    destroy = true,
    keepAlive = true,
    singleton = true,
}

local FUNCTION_OPTION_NAMES = {
    canEnter = true,
    canExit = true,
    onEnter = true,
    onExit = true,
    onPause = true,
    onResume = true,
    validateParams = true,
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

local function valueType(value)
    return typeof(value)
end

local function validateOptions(options)
    if options == nil then
        return
    end

    if type(options) ~= "table" then
        error(
            ("Router.screen expected options to be a table or nil, got %s"):format(
                valueType(options)
            ),
            3
        )
    end

    for optionName, optionValue in options do
        if not VALID_OPTION_NAMES[optionName] then
            error(("Router.screen received an unknown option '%s'"):format(tostring(optionName)), 3)
        end

        if optionName == "retention" then
            if type(optionValue) ~= "string" or not VALID_RETENTION_POLICIES[optionValue] then
                error(
                    "Router.screen expected options.retention to be one of 'destroy', 'keepAlive', or 'singleton'",
                    3
                )
            end
        elseif optionName == "enterTransition" or optionName == "exitTransition" then
            if optionValue ~= nil and type(optionValue) ~= "string" then
                error(
                    ("Router.screen expected options.%s to be a string or nil, got %s"):format(
                        optionName,
                        valueType(optionValue)
                    ),
                    3
                )
            end
        elseif FUNCTION_OPTION_NAMES[optionName] then
            if optionValue ~= nil and type(optionValue) ~= "function" then
                error(
                    ("Router.screen expected options.%s to be a function or nil, got %s"):format(
                        optionName,
                        valueType(optionValue)
                    ),
                    3
                )
            end
        end
    end
end

local function screen(component, options)
    if type(component) ~= "function" then
        error(
            ("Router.screen expected component to be a function, got %s"):format(
                valueType(component)
            ),
            2
        )
    end

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
