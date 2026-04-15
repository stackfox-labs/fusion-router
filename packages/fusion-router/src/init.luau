local screen = require("@self/definitions/screen")
local modal = require("@self/definitions/modal")
local overlay = require("@self/definitions/overlay")
local createRouter = require("@self/runtime/createRouter")

local Router = {
    create = createRouter,
    modal = modal,
    overlay = overlay,
    screen = screen,
}

return table.freeze(Router)
