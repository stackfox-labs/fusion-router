local createRouter = require("../src/runtime/createRouter")
local createTestFusion = require("./TestFusion")

local fusion = createTestFusion()

local function createTestRouter(config, deps)
    local resolvedDeps = deps or {}
    resolvedDeps.fusion = resolvedDeps.fusion or fusion

    return createRouter(config, resolvedDeps)
end

return {
    createRouter = createTestRouter,
    fusion = fusion,
}
