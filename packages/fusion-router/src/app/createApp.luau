local Validation = require("../shared/validation")
local TransitionPresets = require("./transitions")

local function makeScaleUDim2(xScale, yScale)
    if UDim2 ~= nil and type(UDim2.fromScale) == "function" then
        return UDim2.fromScale(xScale, yScale)
    end

    return {
        xScale = xScale,
        yScale = yScale,
    }
end

local function makeVector2(x, y)
    if Vector2 ~= nil and type(Vector2.new) == "function" then
        return Vector2.new(x, y)
    end

    return {
        x = x,
        y = y,
    }
end

local function makeColor3(r, g, b)
    if Color3 ~= nil and type(Color3.new) == "function" then
        return Color3.new(r, g, b)
    end

    return {
        r = r,
        g = g,
        b = b,
    }
end

local function makeTweenInfo(duration)
    if TweenInfo ~= nil and type(TweenInfo.new) == "function" and Enum ~= nil then
        return TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    end

    return {
        duration = duration,
    }
end

local function validateScope(scope)
    local subject = "Router.App"

    Validation.expectTableOrNil(subject, scope, "scope", 1)

    if scope == nil then
        error("Router.App expected scope to be a table, got nil", 2)
    end

    Validation.expectFunction(subject, scope.New, "scope.New", 1)
    Validation.expectFunction(subject, scope.Computed, "scope.Computed", 1)
end

local function validateRouter(router)
    local subject = "Router.App"

    Validation.expectTableOrNil(subject, router, "router", 1)

    if router == nil then
        error("Router.App expected router to be a table, got nil", 2)
    end

    Validation.expectTableOrNil(subject, router._runtime, "router._runtime", 1)
    Validation.expectTableOrNil(subject, router._state, "router._state", 1)
    Validation.expectFunction(subject, router._runtime.bindApp, "router._runtime.bindApp", 1)
    Validation.expectTableOrNil(subject, router._runtime.version, "router._runtime.version", 1)
end

local function createDefaultScheduler()
    local taskLibrary = task

    if type(taskLibrary) == "table" and type(taskLibrary.delay) == "function" then
        return {
            cancel = function(handle)
                if type(taskLibrary.cancel) == "function" and handle ~= nil then
                    taskLibrary.cancel(handle)
                end
            end,
            delay = function(duration, callback)
                return taskLibrary.delay(duration, callback)
            end,
        }
    end

    return {
        cancel = function() end,
        delay = function(_, callback)
            callback()
            return nil
        end,
    }
end

local function resolveStyleForEntry(entry)
    if entry.transition == nil then
        return TransitionPresets.activeStyle(), TransitionPresets.activeStyle(), 0
    end

    if entry.transition.phase == "entering" then
        return TransitionPresets.resolvePhaseStyle(entry.transition.name, "entering"),
            TransitionPresets.activeStyle(),
            entry.transition.duration
    end

    return TransitionPresets.activeStyle(),
        TransitionPresets.resolvePhaseStyle(entry.transition.name, "exiting"),
        entry.transition.duration
end

local function createAnimatedStates(scope, entry)
    local startStyle, endStyle, duration = resolveStyleForEntry(entry)

    local positionGoal = scope:Value(startStyle.position)
    local transparencyGoal = scope:Value(startStyle.transparency)
    local scaleGoal = scope:Value(startStyle.scale)

    local tweenInfo = makeTweenInfo(duration)
    local tweenPosition = if duration > 0
        then scope:Tween(positionGoal, tweenInfo)
        else positionGoal
    local tweenTransparency = if duration > 0
        then scope:Tween(transparencyGoal, tweenInfo)
        else transparencyGoal
    local tweenScale = if duration > 0 then scope:Tween(scaleGoal, tweenInfo) else scaleGoal

    positionGoal:set(endStyle.position)
    transparencyGoal:set(endStyle.transparency)
    scaleGoal:set(endStyle.scale)

    return {
        position = tweenPosition,
        scale = tweenScale,
        transparency = tweenTransparency,
    }
end

local function ensureRouteWrapper(fusion, layerName, entry, layoutOrder)
    local render = entry._appRender

    if render == nil then
        local scope = fusion:scoped()
        local positionGoal = scope:Value(TransitionPresets.activeStyle().position)
        local transparencyGoal = scope:Value(TransitionPresets.activeStyle().transparency)
        local scaleGoal = scope:Value(TransitionPresets.activeStyle().scale)
        local durationGoal = scope:Value(0)
        local visibleGoal = scope:Value(true)
        local layoutOrderGoal = scope:Value(layoutOrder)
        local routeStateGoal = scope:Value(entry.state)
        local transitionNameGoal = scope:Value(nil)
        local transitionPhaseGoal = scope:Value(nil)
        local tweenInfo = scope:Computed(function(use)
            return makeTweenInfo(use(durationGoal))
        end)

        local props = {
            Active = entry.context ~= nil and entry.context.isActive or false,
            AnchorPoint = makeVector2(0, 0),
            BackgroundTransparency = 1,
            GroupTransparency = scope:Tween(transparencyGoal, tweenInfo),
            LayoutOrder = layoutOrderGoal,
            Name = ("%s_%s"):format(layerName, entry.name),
            Position = scope:Tween(positionGoal, tweenInfo),
            Size = makeScaleUDim2(1, 1),
            Visible = visibleGoal,

            [fusion.Children] = {
                scope:New("UIScale")({
                    Scale = scope:Tween(scaleGoal, tweenInfo),
                }),
                entry.instance,
            },
        }

        if type(fusion.Attribute) == "function" then
            props[fusion.Attribute("RouteKey")] = entry.key
            props[fusion.Attribute("RouteLayer")] = layerName
            props[fusion.Attribute("RouteName")] = entry.name
            props[fusion.Attribute("RouteState")] = routeStateGoal
            props[fusion.Attribute("TransitionName")] = transitionNameGoal
            props[fusion.Attribute("TransitionPhase")] = transitionPhaseGoal
        end

        render = {
            durationGoal = durationGoal,
            layoutOrderGoal = layoutOrderGoal,
            positionGoal = positionGoal,
            routeStateGoal = routeStateGoal,
            scaleGoal = scaleGoal,
            scope = scope,
            transitionNameGoal = transitionNameGoal,
            transitionPhaseGoal = transitionPhaseGoal,
            transparencyGoal = transparencyGoal,
            visibleGoal = visibleGoal,
            wrapper = scope:New("CanvasGroup")(props),
        }
        entry._appRender = render

        if entry.scope ~= nil then
            table.insert(entry.scope, function()
                if entry._appRender == render then
                    entry._appRender = nil
                end

                scope:doCleanup()
            end)
        end
    end

    local _, endStyle, duration = resolveStyleForEntry(entry)
    local visible = entry.state ~= "paused" and entry.state ~= "inactive"

    if layerName == "overlay" and not entry.isVisible and entry.persistent then
        visible = false
    end

    render.durationGoal:set(duration)
    render.layoutOrderGoal:set(layoutOrder)
    render.positionGoal:set(endStyle.position)
    render.routeStateGoal:set(entry.state)
    render.scaleGoal:set(endStyle.scale)
    render.transparencyGoal:set(endStyle.transparency)
    render.visibleGoal:set(visible)

    if entry.transition ~= nil then
        render.transitionNameGoal:set(entry.transition.name)
        render.transitionPhaseGoal:set(entry.transition.phase)
    else
        render.transitionNameGoal:set(nil)
        render.transitionPhaseGoal:set(nil)
    end

    return render.wrapper
end

local function createModalBarrier(scope, fusion, router, entry, layoutOrder)
    local OnEvent = fusion.OnEvent
    local animated = createAnimatedStates(scope, entry)
    local props = {
        AutoButtonColor = false,
        BackgroundColor3 = makeColor3(0, 0, 0),
        BackgroundTransparency = scope:Computed(function(use)
            local baseTransparency = use(animated.transparency)
            return math.min(1, 0.45 + baseTransparency * 0.55)
        end),
        LayoutOrder = layoutOrder,
        Name = ("modalBarrier_%s"):format(entry.name),
        Size = makeScaleUDim2(1, 1),
        Text = "",
        Visible = entry.state ~= "inactive",

        [OnEvent("Activated")] = function()
            if entry.definition.barrierDismiss then
                router:popModal()
            end
        end,
    }

    if type(fusion.Attribute) == "function" then
        props[fusion.Attribute("BarrierRouteName")] = entry.name
        props[fusion.Attribute("BarrierDismiss")] = entry.definition.barrierDismiss
    end

    local createTextButton = scope:New("TextButton")
    return createTextButton(props)
end

local function createLayer(scope, fusion, name, layoutOrder, childFactory)
    local Children = fusion.Children

    local props = {
        BackgroundTransparency = 1,
        LayoutOrder = layoutOrder,
        Name = name,
        Size = makeScaleUDim2(1, 1),

        [Children] = scope:Computed(function(use, innerScope)
            return childFactory(use, innerScope)
        end),
    }

    if type(fusion.Attribute) == "function" then
        props[fusion.Attribute("LayerName")] = name
    end

    local createFrame = scope:New("Frame")
    return createFrame(props)
end

local function createApp(scope, router, options)
    validateScope(scope)
    validateRouter(router)
    Validation.expectTableOrNil("Router.App", options, "options", 3)

    local fusion = if options ~= nil and options.fusion ~= nil
        then options.fusion
        else router._runtime.fusion
    Validation.expectFusion("Router.App", fusion, "fusion", 1)
    local scheduler = if options ~= nil and options.scheduler ~= nil
        then options.scheduler
        else createDefaultScheduler()
    local Children = fusion.Children
    local screenLayer = createLayer(
        scope,
        fusion,
        "FusionRouterScreens",
        1,
        function(use, _)
            use(router._runtime.version)

            local children = {}
            local layoutOrder = 1

            for _, entry in router._state.screenStack do
                if entry.isMounted or entry.state == "paused" then
                    table.insert(
                        children,
                        ensureRouteWrapper(fusion, "screen", entry, layoutOrder)
                    )
                    layoutOrder += 1
                end
            end

            for _, entry in router._state.exitingScreens do
                table.insert(
                    children,
                    ensureRouteWrapper(fusion, "screen", entry, layoutOrder)
                )
                layoutOrder += 1
            end

            return children
        end
    )

    local modalLayer = createLayer(scope, fusion, "FusionRouterModals", 2, function(use, innerScope)
        use(router._runtime.version)

        local children = {}
        local layoutOrder = 1

        for _, entry in router._state.modalStack do
            table.insert(
                children,
                createModalBarrier(innerScope, fusion, router, entry, layoutOrder)
            )
            layoutOrder += 1
            table.insert(
                children,
                ensureRouteWrapper(fusion, "modal", entry, layoutOrder)
            )
            layoutOrder += 1
        end

        for _, entry in router._state.exitingModals do
            table.insert(
                children,
                createModalBarrier(innerScope, fusion, router, entry, layoutOrder)
            )
            layoutOrder += 1
            table.insert(
                children,
                ensureRouteWrapper(fusion, "modal", entry, layoutOrder)
            )
            layoutOrder += 1
        end

        return children
    end)

    local overlayLayer = createLayer(
        scope,
        fusion,
        "FusionRouterOverlays",
        3,
        function(use, _)
            use(router._runtime.version)

            local children = {}
            local layoutOrder = 1

            for _, entry in router._state.overlayEntries do
                if entry.isMounted then
                    table.insert(
                        children,
                        ensureRouteWrapper(fusion, "overlay", entry, layoutOrder)
                    )
                    layoutOrder += 1
                end
            end

            return children
        end
    )

    local root = scope:New("Frame")({
        BackgroundTransparency = 1,
        ClipsDescendants = false,
        Name = "FusionRouterApp",
        Size = makeScaleUDim2(1, 1),

        [Children] = {
            screenLayer,
            modalLayer,
            overlayLayer,
        },
    })

    local unbind = router._runtime.bindApp({
        scheduler = scheduler,
    })

    table.insert(scope, function()
        unbind()
    end)

    return root
end

return createApp
