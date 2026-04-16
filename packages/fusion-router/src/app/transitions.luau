local TransitionPresets = {}

local function createStyle(opacity, offsetX, scale)
    return {
        offsetX = offsetX or 0,
        opacity = opacity or 1,
        scale = scale or 1,
    }
end

function TransitionPresets.resolveStyle(presetName, phase)
    if presetName == "fade" then
        return if phase == "entering" then createStyle(0.45, 0, 1) else createStyle(0, 0, 1)
    elseif presetName == "slideLeft" then
        return if phase == "entering" then createStyle(1, 1, 1) else createStyle(1, -1, 1)
    elseif presetName == "slideRight" then
        return if phase == "entering" then createStyle(1, -1, 1) else createStyle(1, 1, 1)
    elseif presetName == "fadeScaleIn" then
        return if phase == "entering" then createStyle(0.35, 0, 0.92) else createStyle(0, 0, 0.92)
    elseif presetName == "fadeOut" then
        return if phase == "entering" then createStyle(1, 0, 1) else createStyle(0, 0, 1)
    end

    return createStyle(1, 0, 1)
end

return table.freeze(TransitionPresets)
