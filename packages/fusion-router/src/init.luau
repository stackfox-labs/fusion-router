local screen = require("@self/definitions/screen")
local modal = require("@self/definitions/modal")
local overlay = require("@self/definitions/overlay")

local Router = {
    modal = modal,
    overlay = overlay,
    screen = screen,
}

return table.freeze(Router)
