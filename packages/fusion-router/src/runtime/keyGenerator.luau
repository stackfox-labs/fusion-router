local function createRuntimeKeyGenerator()
    local screenCount = 0
    local modalCount = 0

    local generator = {
        nextScreenKey = function()
            screenCount += 1

            return ("screen_%d"):format(screenCount)
        end,

        nextModalKey = function()
            modalCount += 1

            return ("modal_%d"):format(modalCount)
        end,
    }

    return table.freeze(generator)
end

return createRuntimeKeyGenerator
