local Validation = require("../shared/validation")

local function createScopeOwner(fusion)
    local subject = "createScopeOwner"

    Validation.expectTableOrNil(subject, fusion, "fusion", 1)

    if fusion == nil then
        error("createScopeOwner expected fusion to be a table, got nil", 2)
    end

    Validation.expectFunction(subject, fusion.scoped, "fusion.scoped", 1)
    Validation.expectFunction(subject, fusion.doCleanup, "fusion.doCleanup", 1)

    local owner = {}

    function owner.attach(entry)
        local attachSubject = "ScopeOwner.attach"

        Validation.expectTableOrNil(attachSubject, entry, "entry", 1)

        if entry == nil then
            error("ScopeOwner.attach expected entry to be a table, got nil", 2)
        end

        if entry.scope ~= nil then
            error(
                ("ScopeOwner.attach expected entry '%s' to not already have a scope"):format(
                    tostring(entry.name)
                ),
                2
            )
        end

        local scope = fusion:scoped()
        entry.scope = scope
        entry.cleanup = function()
            owner.cleanup(entry)
        end

        return scope
    end

    function owner.cleanup(entry)
        local cleanupSubject = "ScopeOwner.cleanup"

        Validation.expectTableOrNil(cleanupSubject, entry, "entry", 1)

        if entry == nil then
            error("ScopeOwner.cleanup expected entry to be a table, got nil", 2)
        end

        local scope = entry.scope

        if scope == nil then
            return false
        end

        if type(scope.doCleanup) == "function" then
            scope:doCleanup()
        else
            fusion.doCleanup(scope)
        end

        entry.scope = nil
        entry.context = nil
        entry.instance = nil
        entry.cleanup = nil
        entry.isMounted = false

        return true
    end

    return table.freeze(owner)
end

return createScopeOwner
