local Validation = require("../shared/validation")

local EntryFactory = {}

local function expectDefinition(subject, definition, expectedKind)
    Validation.expectTableOrNil(subject, definition, "definition", 2)

    if definition == nil or definition.kind ~= expectedKind then
        error(("%s expected definition.kind to be '%s'"):format(subject, expectedKind), 3)
    end
end

local function expectParams(subject, params)
    Validation.expectTableOrNil(subject, params, "params", 2)
end

local function expectKey(subject, key)
    Validation.expectNonEmptyString(subject, key, "key", 2)
end

function EntryFactory.createScreenEntry(name, definition, key, params)
    local subject = "EntryFactory.createScreenEntry"

    Validation.expectRouteName(subject, name, 1)
    expectDefinition(subject, definition, "screen")
    expectKey(subject, key)
    expectParams(subject, params)

    local entry = {
        kind = "screen",
        key = key,
        name = name,
        params = params,
        state = "entering",
        retained = definition.retention ~= "destroy",
        retention = definition.retention,
        definition = definition,
        scope = nil,
        context = nil,
        instance = nil,
        cleanup = nil,
        isMounted = false,
    }

    return entry
end

function EntryFactory.createModalEntry(name, definition, key, params)
    local subject = "EntryFactory.createModalEntry"

    Validation.expectRouteName(subject, name, 1)
    expectDefinition(subject, definition, "modal")
    expectKey(subject, key)
    expectParams(subject, params)

    local entry = {
        kind = "modal",
        key = key,
        name = name,
        params = params,
        state = "entering",
        definition = definition,
        scope = nil,
        context = nil,
        instance = nil,
        cleanup = nil,
        isMounted = false,
    }

    return entry
end

function EntryFactory.createOverlayEntry(name, definition)
    local subject = "EntryFactory.createOverlayEntry"

    Validation.expectRouteName(subject, name, 1)
    expectDefinition(subject, definition, "overlay")

    local entry = {
        kind = "overlay",
        name = name,
        persistent = definition.persistent,
        visible = definition.visible,
        definition = definition,
        scope = nil,
        context = nil,
        instance = nil,
        cleanup = nil,
        isMounted = false,
    }

    return entry
end

return table.freeze(EntryFactory)
