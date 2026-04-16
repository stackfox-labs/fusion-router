local EntryFactory = require("./entries")
local Validation = require("../shared/validation")
local createRuntimeKeyGenerator = require("./keyGenerator")

type RouterDeps = {
    createRuntimeKeyGenerator: ((
    ) -> {
        nextScreenKey: () -> string,
        nextModalKey: () -> string,
    })?,
}

local function validateParams(subject, params)
    Validation.expectTableOrNil(subject, params, "params", 2)
end

local function createRouteLookup(subject, routeMap, routeKind, otherRouteKinds)
    return function(routeName)
        Validation.expectRouteName(subject, routeName, 2)

        local definition = routeMap[routeName]

        if definition ~= nil then
            return definition
        end

        if otherRouteKinds ~= nil then
            for otherRouteKind, otherRouteMap in otherRouteKinds do
                if otherRouteMap[routeName] ~= nil then
                    error(
                        (
                            "%s expected route '%s' to be a %s route, but it is registered as a %s route"
                        ):format(subject, routeName, routeKind, otherRouteKind),
                        3
                    )
                end
            end
        end

        if definition == nil then
            error(
                ("%s expected route '%s' to exist in %s"):format(subject, routeName, routeKind),
                3
            )
        end

        return definition
    end
end

local function clearArray(list)
    for index = #list, 1, -1 do
        list[index] = nil
    end
end

local function createRouter(config, deps: RouterDeps?)
    Validation.validateRouterConfig(config)

    local resolvedDeps = deps or {}
    local keyGeneratorFactory = resolvedDeps.createRuntimeKeyGenerator or createRuntimeKeyGenerator
    local keyGenerator = keyGeneratorFactory()

    local registries = {
        screens = config.screens,
        modals = config.modals or {},
        overlays = config.overlays or {},
        transitions = config.transitions or {},
    }

    local state = {
        initialScreen = config.initialScreen,
        screenStack = {},
        modalStack = {},
        overlayEntries = {},
        retainedScreens = {},
        currentTransition = nil,
    }

    local router = {
        _registries = registries,
        _runtime = {
            keyGenerator = keyGenerator,
        },
        _state = state,
    }

    local screenRouteKinds = {
        modal = registries.modals,
        overlay = registries.overlays,
    }
    local modalRouteKinds = {
        screen = registries.screens,
        overlay = registries.overlays,
    }

    local getScreenDefinition =
        createRouteLookup("Router.push", registries.screens, "screen", screenRouteKinds)
    local getModalDefinition =
        createRouteLookup("Router.pushModal", registries.modals, "modal", modalRouteKinds)
    local getResetScreenDefinition =
        createRouteLookup("Router.reset", registries.screens, "screen", screenRouteKinds)
    local getReplaceScreenDefinition =
        createRouteLookup("Router.replace", registries.screens, "screen", screenRouteKinds)

    function router:push(routeName, params)
        local definition = getScreenDefinition(routeName)
        validateParams("Router.push", params)
        local entry = EntryFactory.createScreenEntry(
            routeName,
            definition,
            keyGenerator.nextScreenKey(),
            params
        )

        table.insert(state.screenStack, entry)

        return entry
    end

    function router:replace(routeName, params)
        local definition = getReplaceScreenDefinition(routeName)
        validateParams("Router.replace", params)
        local entry = EntryFactory.createScreenEntry(
            routeName,
            definition,
            keyGenerator.nextScreenKey(),
            params
        )

        if #state.screenStack == 0 then
            table.insert(state.screenStack, entry)
        else
            state.screenStack[#state.screenStack] = entry
        end

        return entry
    end

    function router:back()
        if #state.modalStack > 0 then
            return table.remove(state.modalStack)
        end

        if #state.screenStack > 1 then
            return table.remove(state.screenStack)
        end

        return nil
    end

    function router:reset(routeName, params)
        local definition = getResetScreenDefinition(routeName)
        validateParams("Router.reset", params)
        local entry = EntryFactory.createScreenEntry(
            routeName,
            definition,
            keyGenerator.nextScreenKey(),
            params
        )

        clearArray(state.screenStack)
        clearArray(state.modalStack)
        state.currentTransition = nil

        table.insert(state.screenStack, entry)

        return entry
    end

    function router:pushModal(routeName, params)
        local definition = getModalDefinition(routeName)
        validateParams("Router.pushModal", params)
        local entry = EntryFactory.createModalEntry(
            routeName,
            definition,
            keyGenerator.nextModalKey(),
            params
        )

        table.insert(state.modalStack, entry)

        return entry
    end

    function router:popModal()
        if #state.modalStack == 0 then
            return nil
        end

        return table.remove(state.modalStack)
    end

    function router:closeAllModals()
        local closed = {}

        while #state.modalStack > 0 do
            table.insert(closed, table.remove(state.modalStack))
        end

        return closed
    end

    function router:getCurrentScreen()
        return state.screenStack[#state.screenStack]
    end

    function router:getCurrentModal()
        return state.modalStack[#state.modalStack]
    end

    function router:getScreenParams()
        local currentScreen = self:getCurrentScreen()

        if currentScreen == nil then
            return nil
        end

        return currentScreen.params
    end

    function router:canGoBack()
        return #state.modalStack > 0 or #state.screenStack > 1
    end

    router:push(config.initialScreen)

    return table.freeze(router)
end

return createRouter
