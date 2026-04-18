local Validation = {}

local function valueType(value)
    return typeof(value)
end

local function raise(message, level)
    error(message, level + 1)
end

function Validation.expectFunction(subject, value, label, level)
    if type(value) ~= "function" then
        raise(
            ("%s expected %s to be a function, got %s"):format(subject, label, valueType(value)),
            level or 1
        )
    end
end

function Validation.expectTableOrNil(subject, value, label, level)
    if value ~= nil and type(value) ~= "table" then
        raise(
            ("%s expected %s to be a table or nil, got %s"):format(subject, label, valueType(value)),
            level or 1
        )
    end
end

function Validation.expectFusion(subject, value, label, level)
    Validation.expectTableOrNil(subject, value, label, (level or 1) + 1)

    if value == nil then
        raise(("%s expected %s to be a Fusion table, got nil"):format(subject, label), level or 1)
    end

    Validation.expectFunction(subject, value.scoped, ("%s.scoped"):format(label), (level or 1) + 1)
    Validation.expectFunction(
        subject,
        value.doCleanup,
        ("%s.doCleanup"):format(label),
        (level or 1) + 1
    )
    Validation.expectFunction(subject, value.peek, ("%s.peek"):format(label), (level or 1) + 1)
end

function Validation.rejectUnknownOptions(subject, options, validOptionNames, level)
    if options == nil then
        return
    end

    for optionName in options do
        if not validOptionNames[optionName] then
            raise(
                ("%s received an unknown option '%s'"):format(subject, tostring(optionName)),
                level or 1
            )
        end
    end
end

function Validation.expectOptionalBoolean(subject, value, label, level)
    if value ~= nil and type(value) ~= "boolean" then
        raise(
            ("%s expected %s to be a boolean or nil, got %s"):format(
                subject,
                label,
                valueType(value)
            ),
            level or 1
        )
    end
end

function Validation.expectOptionalString(subject, value, label, level)
    if value ~= nil and type(value) ~= "string" then
        raise(
            ("%s expected %s to be a string or nil, got %s"):format(
                subject,
                label,
                valueType(value)
            ),
            level or 1
        )
    end
end

function Validation.expectOptionalFunction(subject, value, label, level)
    if value ~= nil and type(value) ~= "function" then
        raise(
            ("%s expected %s to be a function or nil, got %s"):format(
                subject,
                label,
                valueType(value)
            ),
            level or 1
        )
    end
end

function Validation.expectNonEmptyString(subject, value, label, level)
    if type(value) ~= "string" or value == "" then
        raise(
            ("%s expected %s to be a non-empty string, got %s"):format(
                subject,
                label,
                valueType(value)
            ),
            level or 1
        )
    end
end

function Validation.expectOptionalEnumString(
    subject,
    value,
    label,
    validValues,
    expectedValues,
    level
)
    if value == nil then
        return
    end

    if type(value) ~= "string" or not validValues[value] then
        raise(("%s expected %s to be one of %s"):format(subject, label, expectedValues), level or 1)
    end
end

function Validation.expectRouteName(subject, routeName, level)
    Validation.expectNonEmptyString(subject, routeName, "route name", (level or 1) + 1)
end

function Validation.expectRouteMap(subject, routeMap, label, expectedKind, level)
    Validation.expectTableOrNil(subject, routeMap, label, (level or 1) + 1)

    if routeMap == nil then
        return
    end

    for routeName, definition in routeMap do
        Validation.expectRouteName(subject, routeName, (level or 1) + 1)
        Validation.expectTableOrNil(
            subject,
            definition,
            ("%s.%s"):format(label, routeName),
            (level or 1) + 1
        )

        if definition == nil or definition.kind ~= expectedKind then
            raise(
                ("%s expected %s.%s to be a %s definition"):format(
                    subject,
                    label,
                    tostring(routeName),
                    expectedKind
                ),
                level or 1
            )
        end
    end
end

function Validation.validateRouterConfig(config)
    local subject = "Router.create"

    Validation.expectTableOrNil(subject, config, "config", 2)

    if config == nil then
        raise("Router.create expected config to be a table, got nil", 1)
    end

    if type(config.initialScreen) ~= "string" or config.initialScreen == "" then
        raise(
            ("Router.create expected config.initialScreen to be a non-empty string, got %s"):format(
                valueType(config.initialScreen)
            ),
            1
        )
    end

    Validation.expectTableOrNil(subject, config.transitions, "config.transitions", 1)
    Validation.expectRouteMap(subject, config.screens, "config.screens", "screen", 1)
    Validation.expectRouteMap(subject, config.modals, "config.modals", "modal", 1)
    Validation.expectRouteMap(subject, config.overlays, "config.overlays", "overlay", 1)

    if config.screens == nil then
        raise("Router.create expected config.screens to be a table, got nil", 1)
    end

    if config.screens[config.initialScreen] == nil then
        raise(
            ("Router.create expected initialScreen '%s' to exist in config.screens"):format(
                config.initialScreen
            ),
            1
        )
    end

    return config
end

return Validation
