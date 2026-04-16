local Validation = require("../shared/validation")
local TransitionPresets = require("./transitions")

local function validateScope(scope)
    local subject = "Router.App"

    Validation.expectTableOrNil(subject, scope, "scope", 1)

    if scope == nil then
        error("Router.App expected scope to be a table, got nil", 2)
    end

    Validation.expectFunction(subject, scope.New, "scope.New", 1)
end

local function validateRouter(router)
    local subject = "Router.App"

    Validation.expectTableOrNil(subject, router, "router", 1)

    if router == nil then
        error("Router.App expected router to be a table, got nil", 2)
    end

    Validation.expectTableOrNil(subject, router._state, "router._state", 1)
    Validation.expectTableOrNil(subject, router._runtime, "router._runtime", 1)
    Validation.expectFunction(subject, router._runtime.subscribe, "router._runtime.subscribe", 1)
    Validation.expectFunction(subject, router._runtime.bindApp, "router._runtime.bindApp", 1)
    Validation.expectFunction(subject, router.popModal, "router.popModal", 1)
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

local function instantiate(scope, className, props)
    local constructor = scope:New(className)
    local instance = constructor(props)

    if type(instance) ~= "table" then
        instance = {}
    end

    instance.ClassName = className

    for key, value in props do
        instance[key] = value
    end

    return instance
end

local function updateNode(node, props)
    for key, value in props do
        node[key] = value
    end

    return node
end

local function createTransitionSnapshot(entry)
    local transition = entry.transition

    if transition == nil then
        return nil
    end

    return {
        duration = transition.duration,
        name = transition.name,
        phase = transition.phase,
        style = TransitionPresets.resolveStyle(transition.name, transition.phase),
    }
end

local function shouldRenderScreen(entry)
    return entry.isMounted or entry.state == "exiting"
end

local function shouldRenderModal(entry)
    return entry.isMounted or entry.state == "exiting"
end

local function shouldRenderOverlay(entry)
    return entry.isMounted
end

local function createRouteNode(scope, layerKind, entry, layoutOrder, extraProps)
    local isVisible = true

    if layerKind == "screen" then
        isVisible = entry.state ~= "paused"
    elseif layerKind == "overlay" then
        isVisible = entry.isVisible or entry.state == "entering" or entry.state == "exiting"
    end

    local props = {
        Active = entry.context ~= nil and entry.context.isActive.value or false,
        Children = if entry.instance == nil then {} else { entry.instance },
        Key = entry.key,
        Kind = entry.kind,
        LayoutOrder = layoutOrder,
        MountedInstance = entry.instance,
        Name = ("%s:%s"):format(layerKind, entry.name),
        RouteKey = entry.key,
        RouteName = entry.name,
        State = entry.state,
        Transition = createTransitionSnapshot(entry),
        Visible = isVisible,
    }

    if extraProps ~= nil then
        for key, value in extraProps do
            props[key] = value
        end
    end

    return instantiate(scope, "Frame", props)
end

local function createModalBarrierNode(scope, router, entry, layoutOrder)
    return instantiate(scope, "TextButton", {
        AutoButtonColor = false,
        Barrier = true,
        Dismissible = entry.definition.barrierDismiss,
        LayoutOrder = layoutOrder,
        Name = ("modalBarrier:%s"):format(entry.name),
        OnActivated = function()
            if entry.definition.barrierDismiss then
                router:popModal()
            end
        end,
        RouteKey = entry.key,
        RouteName = entry.name,
        Visible = true,
    })
end

local function appendScreenNodes(scope, destination, entries)
    for _, entry in entries do
        if shouldRenderScreen(entry) then
            table.insert(
                destination,
                createRouteNode(scope, "screen", entry, #destination + 1, {
                    Hidden = entry.state == "paused",
                    Retained = entry.retained,
                })
            )
        end
    end
end

local function appendModalNodes(scope, router, destination, entries)
    for _, entry in entries do
        if shouldRenderModal(entry) then
            table.insert(
                destination,
                createModalBarrierNode(scope, router, entry, #destination + 1)
            )
            table.insert(
                destination,
                createRouteNode(scope, "modal", entry, #destination + 1, {
                    BarrierDismiss = entry.definition.barrierDismiss,
                })
            )
        end
    end
end

local function appendOverlayNodes(scope, destination, entries)
    for _, entry in entries do
        if shouldRenderOverlay(entry) then
            table.insert(
                destination,
                createRouteNode(scope, "overlay", entry, #destination + 1, {
                    Persistent = entry.persistent,
                })
            )
        end
    end
end

local function createApp(scope, router, options)
    validateScope(scope)
    validateRouter(router)
    Validation.expectTableOrNil("Router.App", options, "options", 3)

    local scheduler = if options ~= nil and options.scheduler ~= nil
        then options.scheduler
        else createDefaultScheduler()

    local root = instantiate(scope, "Frame", {
        BackgroundTransparency = 1,
        Children = {},
        ClipsDescendants = false,
        Name = "FusionRouterApp",
    })
    local screenLayer = instantiate(scope, "Frame", {
        BackgroundTransparency = 1,
        Children = {},
        LayoutOrder = 1,
        Layer = "screens",
        Name = "FusionRouterScreens",
    })
    local modalLayer = instantiate(scope, "Frame", {
        BackgroundTransparency = 1,
        Children = {},
        LayoutOrder = 2,
        Layer = "modals",
        Name = "FusionRouterModals",
    })
    local overlayLayer = instantiate(scope, "Frame", {
        BackgroundTransparency = 1,
        Children = {},
        LayoutOrder = 3,
        Layer = "overlays",
        Name = "FusionRouterOverlays",
    })

    local function rebuild()
        local screenChildren = {}
        local modalChildren = {}
        local overlayChildren = {}

        appendScreenNodes(scope, screenChildren, router._state.screenStack)
        appendScreenNodes(scope, screenChildren, router._state.exitingScreens)
        appendModalNodes(scope, router, modalChildren, router._state.modalStack)
        appendModalNodes(scope, router, modalChildren, router._state.exitingModals)
        appendOverlayNodes(scope, overlayChildren, router._state.overlayEntries)

        updateNode(screenLayer, {
            Children = screenChildren,
        })
        updateNode(modalLayer, {
            Children = modalChildren,
        })
        updateNode(overlayLayer, {
            Children = overlayChildren,
        })
        updateNode(root, {
            Children = { screenLayer, modalLayer, overlayLayer },
        })
    end

    local unsubscribe = router._runtime.subscribe(rebuild)
    local unbind = router._runtime.bindApp({
        scheduler = scheduler,
    })

    root.cleanup = function()
        unsubscribe()
        unbind()
    end

    rebuild()

    return root
end

return createApp
