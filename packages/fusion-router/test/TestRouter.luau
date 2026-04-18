local createRouter = require("../src/runtime/createRouter")
local createTestFusion = require("./TestFusion")

local fusion = createTestFusion()

local function createTestRouter(config, deps)
    local resolvedDeps = deps or {}
    local routerFusion = resolvedDeps.fusion or fusion

    return createRouter(config, routerFusion, resolvedDeps)
end

return {
    createRouter = createTestRouter,
    fusion = fusion,
}
