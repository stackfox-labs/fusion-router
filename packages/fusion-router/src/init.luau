local screen = require("@self/definitions/screen")
local modal = require("@self/definitions/modal")
local overlay = require("@self/definitions/overlay")
local App = require("@self/app/createApp")
local createRouter = require("@self/runtime/createRouter")

local Router = {
    App = App,
    create = createRouter,
    modal = modal,
    overlay = overlay,
    screen = screen,
}

return table.freeze(Router)
