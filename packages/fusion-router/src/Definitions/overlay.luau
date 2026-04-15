local FUNCTION_OPTION_NAMES = {
    onEnter = true,
    onExit = true,
}

local VALID_OPTION_NAMES = {
    persistent = true,
    visible = true,
    onEnter = true,
    onExit = true,
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
            ("Router.overlay expected options to be a table or nil, got %s"):format(
                valueType(options)
            ),
            3
        )
    end

    for optionName, optionValue in options do
        if not VALID_OPTION_NAMES[optionName] then
            error(
                ("Router.overlay received an unknown option '%s'"):format(tostring(optionName)),
                3
            )
        end

        if optionName == "persistent" then
            if optionValue ~= nil and type(optionValue) ~= "boolean" then
                error(
                    ("Router.overlay expected options.persistent to be a boolean or nil, got %s"):format(
                        valueType(optionValue)
                    ),
                    3
                )
            end
        elseif FUNCTION_OPTION_NAMES[optionName] then
            if optionValue ~= nil and type(optionValue) ~= "function" then
                error(
                    ("Router.overlay expected options.%s to be a function or nil, got %s"):format(
                        optionName,
                        valueType(optionValue)
                    ),
                    3
                )
            end
        end
    end
end

local function overlay(component, options)
    if type(component) ~= "function" then
        error(
            ("Router.overlay expected component to be a function, got %s"):format(
                valueType(component)
            ),
            2
        )
    end

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
