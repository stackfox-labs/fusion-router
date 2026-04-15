local Router = require("../src")

return {
    name = "fusion-router package entrypoint returns a frozen table",
    run = function()
        assert(type(Router) == "table", "Router entrypoint should return a table")
        assert(table.isfrozen(Router), "Router entrypoint should be frozen")
    end,
}
