local EntryFactory = require("../src/runtime/entries")
local createScopeOwner = require("../src/runtime/scopeOwner")
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
    name = "scope owner assigns route-local scopes and cleans them up deterministically",
    run = function()
        local scopedCalls = 0
        local cleanupCalls = {}
        local fakeFusion = {
            scoped = function(self)
                scopedCalls += 1

                return {
                    owner = self,
                    id = scopedCalls,
                }
            end,

            doCleanup = function(scope)
                table.insert(cleanupCalls, scope)
            end,
        }

        local scopeOwner = createScopeOwner(fakeFusion)
        local entry = EntryFactory.createScreenEntry("Inventory", Router.screen(noop), "screen_1")

        assert(table.isfrozen(scopeOwner), "Scope owner should be frozen")

        local scope = scopeOwner.attach(entry)

        assert(scope.id == 1, "Attached scope should come from Fusion.scoped")
        assert(entry.scope == scope, "Scope owner should assign the scope to the entry")
        assert(
            type(entry.cleanup) == "function",
            "Scope owner should assign an entry cleanup callback"
        )
        assert(entry.context == nil, "Attaching a scope should not invent route context")
        assert(entry.instance == nil, "Attaching a scope should not invent an instance")
        assert(entry.isMounted == false, "Attaching a scope should not mark the entry mounted")

        local cleaned = scopeOwner.cleanup(entry)

        assert(cleaned == true, "Cleanup should return true when a scope existed")
        assert(#cleanupCalls == 1, "Cleanup should forward to Fusion.doCleanup once")
        assert(cleanupCalls[1] == scope, "Cleanup should clean up the attached scope")
        assert(entry.scope == nil, "Cleanup should clear the route scope")
        assert(entry.context == nil, "Cleanup should clear route context bookkeeping")
        assert(entry.instance == nil, "Cleanup should clear instance bookkeeping")
        assert(entry.cleanup == nil, "Cleanup should clear the cleanup callback reference")
        assert(entry.isMounted == false, "Cleanup should leave the entry unmounted")

        assert(
            scopeOwner.cleanup(entry) == false,
            "Cleanup should return false when there is no scope left to clean"
        )

        local replacementScope = scopeOwner.attach(entry)
        assert(replacementScope.id == 2, "Reattaching after cleanup should get a fresh scope")
        assert(entry.scope == replacementScope, "Reattach should store the new scope")

        expectError(function()
            scopeOwner.attach(entry)
        end, "ScopeOwner.attach expected entry 'Inventory' to not already have a scope")

        expectError(function()
            createScopeOwner(nil)
        end, "createScopeOwner expected fusion to be a table, got nil")

        expectError(function()
            createScopeOwner({
                doCleanup = noop,
            })
        end, "createScopeOwner expected fusion.scoped to be a function")

        expectError(function()
            createScopeOwner({
                scoped = noop,
            })
        end, "createScopeOwner expected fusion.doCleanup to be a function")
    end,
}
