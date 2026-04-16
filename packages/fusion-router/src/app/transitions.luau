local TransitionPresets = {}

local function fromScale(xScale, yScale)
    if UDim2 ~= nil and type(UDim2.fromScale) == "function" then
        return UDim2.fromScale(xScale, yScale)
    end

    return {
        xScale = xScale,
        yScale = yScale,
    }
end

local function makeStyle(position, transparency, scale)
    return {
        position = position,
        transparency = transparency,
        scale = scale,
    }
end

local ACTIVE_STYLE = makeStyle(fromScale(0, 0), 0, 1)

function TransitionPresets.activeStyle()
    return ACTIVE_STYLE
end

function TransitionPresets.hiddenStyle()
    return makeStyle(fromScale(0, 0), 0, 1)
end

function TransitionPresets.resolvePhaseStyle(presetName, phase)
    if presetName == "fade" then
        if phase == "entering" then
            return makeStyle(fromScale(0, 0), 1, 1)
        end

        return makeStyle(fromScale(0, 0), 1, 1)
    elseif presetName == "slideLeft" then
        if phase == "entering" then
            return makeStyle(fromScale(1, 0), 0, 1)
        end

        return makeStyle(fromScale(-1, 0), 0, 1)
    elseif presetName == "slideRight" then
        if phase == "entering" then
            return makeStyle(fromScale(-1, 0), 0, 1)
        end

        return makeStyle(fromScale(1, 0), 0, 1)
    elseif presetName == "fadeScaleIn" then
        if phase == "entering" then
            return makeStyle(fromScale(0, 0), 1, 0.92)
        end

        return makeStyle(fromScale(0, 0), 1, 0.92)
    elseif presetName == "fadeOut" then
        if phase == "entering" then
            return ACTIVE_STYLE
        end

        return makeStyle(fromScale(0, 0), 1, 1)
    end

    return ACTIVE_STYLE
end

return table.freeze(TransitionPresets)
