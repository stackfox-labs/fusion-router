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

local function createRouteLookup(subject, routeMap, routeKind)
    return function(routeName)
        Validation.expectRouteName(subject, routeName, 2)

        local definition = routeMap[routeName]

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

    local getScreenDefinition = createRouteLookup("Router.push", registries.screens, "screens")
    local getModalDefinition = createRouteLookup("Router.pushModal", registries.modals, "modals")
    local getResetScreenDefinition =
        createRouteLookup("Router.reset", registries.screens, "screens")
    local getReplaceScreenDefinition =
        createRouteLookup("Router.replace", registries.screens, "screens")

    function router:push(routeName, params)
        validateParams("Router.push", params)

        local definition = getScreenDefinition(routeName)
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
        validateParams("Router.replace", params)

        local definition = getReplaceScreenDefinition(routeName)
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
        validateParams("Router.reset", params)

        local definition = getResetScreenDefinition(routeName)
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
        validateParams("Router.pushModal", params)

        local definition = getModalDefinition(routeName)
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
