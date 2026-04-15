local FUNCTION_OPTION_NAMES = {
    canEnter = true,
    canExit = true,
    onEnter = true,
    onExit = true,
    validateParams = true,
}

local VALID_OPTION_NAMES = {
    transition = true,
    barrierDismiss = true,
    canEnter = true,
    canExit = true,
    onEnter = true,
    onExit = true,
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
            ("Router.modal expected options to be a table or nil, got %s"):format(
                valueType(options)
            ),
            3
        )
    end

    for optionName, optionValue in options do
        if not VALID_OPTION_NAMES[optionName] then
            error(("Router.modal received an unknown option '%s'"):format(tostring(optionName)), 3)
        end

        if optionName == "transition" then
            if optionValue ~= nil and type(optionValue) ~= "string" then
                error(
                    ("Router.modal expected options.transition to be a string or nil, got %s"):format(
                        valueType(optionValue)
                    ),
                    3
                )
            end
        elseif optionName == "barrierDismiss" then
            if optionValue ~= nil and type(optionValue) ~= "boolean" then
                error(
                    ("Router.modal expected options.barrierDismiss to be a boolean or nil, got %s"):format(
                        valueType(optionValue)
                    ),
                    3
                )
            end
        elseif FUNCTION_OPTION_NAMES[optionName] then
            if optionValue ~= nil and type(optionValue) ~= "function" then
                error(
                    ("Router.modal expected options.%s to be a function or nil, got %s"):format(
                        optionName,
                        valueType(optionValue)
                    ),
                    3
                )
            end
        end
    end
end

local function modal(component, options)
    if type(component) ~= "function" then
        error(
            ("Router.modal expected component to be a function, got %s"):format(
                valueType(component)
            ),
            2
        )
    end

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
