local EntryFactory = require("./entries")
local Validation = require("../shared/validation")
local createRuntimeKeyGenerator = require("./keyGenerator")
local createRouteContext = require("./routeContext")

type RouterDeps = {
    createRuntimeKeyGenerator: ((
    ) -> {
        nextScreenKey: () -> string,
        nextModalKey: () -> string,
    })?,
    createRouteContext: ((entry: any, router: any, isActive: any) -> any)?,
    createScopeOwner: ((fusion: any?) -> any)?,
    fusion: any?,
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

local function createBasicScopeOwner()
    local nextScopeId = 0
    local owner = {}

    function owner.attach(entry)
        if entry.scope ~= nil then
            error(
                ("BasicScopeOwner.attach expected entry '%s' to not already have a scope"):format(
                    tostring(entry.name)
                ),
                2
            )
        end

        nextScopeId += 1

        local scope = {
            id = nextScopeId,
        }

        entry.scope = scope
        entry.cleanup = function()
            owner.cleanup(entry)
        end

        return scope
    end

    function owner.cleanup(entry)
        if entry.scope == nil then
            return false
        end

        entry.scope = nil
        entry.context = nil
        entry.instance = nil
        entry.cleanup = nil
        entry.isMounted = false

        return true
    end

    return table.freeze(owner)
end

local function ensureActiveState(entry)
    local activeState = entry._activeState

    if activeState == nil then
        activeState = {
            value = false,
        }
        entry._activeState = activeState
    end

    return activeState
end

local function setEntryActive(entry, isActive)
    ensureActiveState(entry).value = isActive
end

local function validateRouteParams(subject, definition, params)
    validateParams(subject, params)

    local validateRouteSpecificParams = definition.validateParams

    if validateRouteSpecificParams ~= nil then
        validateRouteSpecificParams(params)
    end
end

local function runLifecycleHook(hook, context)
    if hook == nil then
        return
    end

    local ok, hookError = pcall(hook, context)

    if not ok then
        error(hookError, 0)
    end
end

local function createRouter(config, deps: RouterDeps?)
    Validation.validateRouterConfig(config)

    local resolvedDeps = deps or {}
    local keyGeneratorFactory = resolvedDeps.createRuntimeKeyGenerator or createRuntimeKeyGenerator
    local keyGenerator = keyGeneratorFactory()
    local routeContextFactory = resolvedDeps.createRouteContext or createRouteContext
    local scopeOwnerFactory = resolvedDeps.createScopeOwner
    local scopeOwner =
        if scopeOwnerFactory ~= nil then scopeOwnerFactory(resolvedDeps.fusion) else createBasicScopeOwner()

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
    local retainedKeepAlive = {}
    local retainedSingleton = {}

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

    local function ensureEntryContext(entry)
        if entry.scope == nil then
            scopeOwner.attach(entry)
        end

        local context = entry.context

        if context == nil then
            context = routeContextFactory(entry, router, ensureActiveState(entry))
            entry.context = context
        end

        return context
    end

    local function removeKeepAliveEntry(entry)
        local bucket = retainedKeepAlive[entry.name]

        if bucket == nil then
            return
        end

        local index = table.find(bucket, entry)

        if index ~= nil then
            table.remove(bucket, index)
        end

        if #bucket == 0 then
            retainedKeepAlive[entry.name] = nil
        end
    end

    local function removeRetainedEntry(entry)
        state.retainedScreens[entry.key] = nil

        if entry.retention == "singleton" then
            if retainedSingleton[entry.name] == entry then
                retainedSingleton[entry.name] = nil
            end
        elseif entry.retention == "keepAlive" then
            removeKeepAliveEntry(entry)
        end
    end

    local function storeRetainedEntry(entry)
        state.retainedScreens[entry.key] = entry

        if entry.retention == "singleton" then
            local existing = retainedSingleton[entry.name]

            if existing ~= nil and existing ~= entry then
                removeRetainedEntry(existing)
                existing.state = "exiting"
                setEntryActive(existing, false)
                runLifecycleHook(existing.definition.onExit, existing.context)
                scopeOwner.cleanup(existing)
            end

            retainedSingleton[entry.name] = entry
        elseif entry.retention == "keepAlive" then
            local bucket = retainedKeepAlive[entry.name]

            if bucket == nil then
                bucket = {}
                retainedKeepAlive[entry.name] = bucket
            end

            if table.find(bucket, entry) == nil then
                table.insert(bucket, entry)
            end
        end
    end

    local function takeReusableScreenEntry(routeName, definition, params)
        local entry = nil

        if definition.retention == "singleton" then
            entry = retainedSingleton[routeName]

            if entry ~= nil then
                retainedSingleton[routeName] = nil
            end
        elseif definition.retention == "keepAlive" then
            local bucket = retainedKeepAlive[routeName]

            if bucket ~= nil then
                entry = table.remove(bucket)

                if #bucket == 0 then
                    retainedKeepAlive[routeName] = nil
                end
            end
        end

        if entry == nil then
            return nil, false
        end

        state.retainedScreens[entry.key] = nil
        entry.params = params
        entry.context = nil

        ensureEntryContext(entry)

        return entry, true
    end

    local function createGuardedScreenEntry(routeName, definition, params)
        local entry, reused = takeReusableScreenEntry(routeName, definition, params)

        if entry == nil then
            entry = EntryFactory.createScreenEntry(
                routeName,
                definition,
                keyGenerator.nextScreenKey(),
                params
            )
            reused = false
        end

        ensureEntryContext(entry)

        return entry, reused
    end

    local function prepareScreenEntry(subject, routeName, definition, params)
        validateRouteParams(subject, definition, params)

        local entry, reused = createGuardedScreenEntry(routeName, definition, params)
        local canEnter = definition.canEnter

        if canEnter ~= nil and canEnter(entry.context) == false then
            if reused then
                storeRetainedEntry(entry)
            else
                scopeOwner.cleanup(entry)
            end

            return nil, false
        end

        return entry, reused
    end

    local function prepareModalEntry(subject, routeName, definition, params)
        validateRouteParams(subject, definition, params)

        local entry = EntryFactory.createModalEntry(
            routeName,
            definition,
            keyGenerator.nextModalKey(),
            params
        )

        ensureEntryContext(entry)

        local canEnter = definition.canEnter

        if canEnter ~= nil and canEnter(entry.context) == false then
            scopeOwner.cleanup(entry)

            return nil
        end

        return entry
    end

    local function mountScreenEntry(entry)
        local context = ensureEntryContext(entry)

        entry.instance = entry.definition.component(context)
        entry.isMounted = true
        entry.state = "active"
        setEntryActive(entry, true)

        return entry
    end

    local function activateScreenEntry(entry, reused)
        if reused and entry.isMounted and entry.scope ~= nil and entry.instance ~= nil then
            ensureEntryContext(entry)
            entry.state = "active"
            setEntryActive(entry, true)

            return entry
        end

        return mountScreenEntry(entry)
    end

    local function resumeScreenEntry(entry)
        if not entry.isMounted or entry.scope == nil or entry.context == nil then
            mountScreenEntry(entry)
        else
            entry.state = "active"
            setEntryActive(entry, true)
        end

        return entry
    end

    local function mountModalEntry(entry)
        local context = ensureEntryContext(entry)

        entry.instance = entry.definition.component(context)
        entry.isMounted = true
        entry.state = "active"
        setEntryActive(entry, true)

        return entry
    end

    local function restoreScreenState(entry, snapshot)
        entry.state = snapshot.state
        setEntryActive(entry, snapshot.isActive)

        if snapshot.wasRetained then
            state.retainedScreens[entry.key] = snapshot.retainedValue
        else
            state.retainedScreens[entry.key] = nil
        end
    end

    local function restoreModalState(entry, snapshot)
        entry.state = snapshot.state
        setEntryActive(entry, snapshot.isActive)
    end

    local function activateUnderlyingModal()
        local nextModal = state.modalStack[#state.modalStack]

        if nextModal ~= nil then
            nextModal.state = "active"
            setEntryActive(nextModal, true)
        end

        return nextModal
    end

    local function closeTopModal(subject)
        local modalCount = #state.modalStack

        if modalCount == 0 then
            return nil
        end

        local currentModal = state.modalStack[modalCount]
        local canExit = currentModal.definition.canExit

        if canExit ~= nil and canExit(currentModal.context) == false then
            return nil
        end

        state.currentTransition = currentModal.definition.transition or registries.transitions.modalClose

        local closedModal = table.remove(state.modalStack)

        closedModal.state = "exiting"
        setEntryActive(closedModal, false)
        runLifecycleHook(closedModal.definition.onExit, closedModal.context)
        scopeOwner.cleanup(closedModal)
        activateUnderlyingModal()

        return closedModal
    end

    function router:push(routeName, params)
        local definition = getScreenDefinition(routeName)
        local entry, reused = prepareScreenEntry("Router.push", routeName, definition, params)

        if entry == nil then
            return nil
        end

        local currentScreen = state.screenStack[#state.screenStack]
        local currentScreenSnapshot = nil

        if currentScreen ~= nil then
            currentScreenSnapshot = {
                state = currentScreen.state,
                isActive = ensureActiveState(currentScreen).value,
                wasRetained = state.retainedScreens[currentScreen.key] ~= nil,
                retainedValue = state.retainedScreens[currentScreen.key],
            }

            setEntryActive(currentScreen, false)
            currentScreen.state = "paused"

            if currentScreen.retained then
                state.retainedScreens[currentScreen.key] = currentScreen

                local onPause = currentScreen.definition.onPause

                if onPause ~= nil then
                    local ok, pauseError = pcall(onPause, currentScreen.context)

                    if not ok then
                        restoreScreenState(currentScreen, currentScreenSnapshot)
                        scopeOwner.cleanup(entry)
                        error(pauseError, 0)
                    end
                end
            else
                state.retainedScreens[currentScreen.key] = nil
            end
        end

        table.insert(state.screenStack, entry)

        local mounted, mountResult = pcall(activateScreenEntry, entry, reused)

        if not mounted then
            table.remove(state.screenStack)

            if reused then
                storeRetainedEntry(entry)
            else
                scopeOwner.cleanup(entry)
            end

            if currentScreenSnapshot ~= nil then
                restoreScreenState(currentScreen, currentScreenSnapshot)
            end

            error(mountResult, 0)
        end

        local onEnter = definition.onEnter

        if onEnter ~= nil then
            local entered, enterError = pcall(onEnter, entry.context)

            if not entered then
                table.remove(state.screenStack)

                if reused then
                    storeRetainedEntry(entry)
                else
                    scopeOwner.cleanup(entry)
                end

                if currentScreenSnapshot ~= nil then
                    restoreScreenState(currentScreen, currentScreenSnapshot)
                end

                error(enterError, 0)
            end
        end

        if currentScreen ~= nil and not currentScreen.retained then
            scopeOwner.cleanup(currentScreen)
        end

        return mountResult
    end

    local function collectResetScreenEntries()
        local collected = {}
        local seenKeys = {}

        for index = #state.screenStack, 1, -1 do
            local entry = state.screenStack[index]
            local entryKey = entry.key

            seenKeys[entryKey] = true
            table.insert(collected, entry)
        end

        for entryKey, entry in state.retainedScreens do
            if not seenKeys[entryKey] then
                seenKeys[entryKey] = true
                table.insert(collected, entry)
            end
        end

        return collected
    end

    function router:replace(routeName, params)
        local definition = getReplaceScreenDefinition(routeName)
        local entry, reused = prepareScreenEntry("Router.replace", routeName, definition, params)

        if entry == nil then
            return nil
        end

        local currentIndex = #state.screenStack
        local currentScreen = state.screenStack[currentIndex]
        local currentScreenSnapshot = nil

        if currentScreen ~= nil then
            local canExit = currentScreen.definition.canExit

            if canExit ~= nil and canExit(currentScreen.context) == false then
                scopeOwner.cleanup(entry)

                return nil
            end

            currentScreenSnapshot = {
                state = currentScreen.state,
                isActive = ensureActiveState(currentScreen).value,
                wasRetained = state.retainedScreens[currentScreen.key] ~= nil,
                retainedValue = state.retainedScreens[currentScreen.key],
            }

            setEntryActive(currentScreen, false)

            if currentScreen.retained then
                currentScreen.state = "paused"
            else
                currentScreen.state = "exiting"
                state.retainedScreens[currentScreen.key] = nil
                runLifecycleHook(currentScreen.definition.onExit, currentScreen.context)
            end
        end

        if currentIndex == 0 then
            table.insert(state.screenStack, entry)
        else
            state.screenStack[currentIndex] = entry
        end

        local mounted, mountResult = pcall(activateScreenEntry, entry, reused)

        if not mounted then
            if currentIndex == 0 then
                table.remove(state.screenStack)
            elseif currentScreen ~= nil and currentScreen.retained then
                state.screenStack[currentIndex] = currentScreen
                restoreScreenState(currentScreen, currentScreenSnapshot)
            end

            if reused then
                storeRetainedEntry(entry)
            else
                scopeOwner.cleanup(entry)
            end
            error(mountResult, 0)
        end

        local onEnter = definition.onEnter

        if onEnter ~= nil then
            local entered, enterError = pcall(onEnter, entry.context)

            if not entered then
                if currentIndex == 0 then
                    table.remove(state.screenStack)
                elseif currentScreen ~= nil and currentScreen.retained then
                    state.screenStack[currentIndex] = currentScreen
                    restoreScreenState(currentScreen, currentScreenSnapshot)
                end

                if reused then
                    storeRetainedEntry(entry)
                else
                    scopeOwner.cleanup(entry)
                end
                error(enterError, 0)
            end
        end

        if currentScreen ~= nil then
            if currentScreen.retained then
                storeRetainedEntry(currentScreen)
            else
                scopeOwner.cleanup(currentScreen)
            end
        end

        return mountResult
    end

    function router:back()
        if #state.modalStack > 0 then
            return closeTopModal("Router.back")
        end

        if #state.screenStack <= 1 then
            return nil
        end

        local currentScreen = state.screenStack[#state.screenStack]
        local canExit = currentScreen.definition.canExit

        if canExit ~= nil and canExit(currentScreen.context) == false then
            return nil
        end

        local previousScreen = state.screenStack[#state.screenStack - 1]
        local shouldResumePrevious = previousScreen ~= nil and previousScreen.state == "paused"
        local poppedScreen = table.remove(state.screenStack)

        setEntryActive(poppedScreen, false)

        if poppedScreen.retained then
            poppedScreen.state = "paused"
            storeRetainedEntry(poppedScreen)
        else
            poppedScreen.state = "exiting"
            state.retainedScreens[poppedScreen.key] = nil
            runLifecycleHook(poppedScreen.definition.onExit, poppedScreen.context)
            scopeOwner.cleanup(poppedScreen)
        end

        if previousScreen ~= nil then
            resumeScreenEntry(previousScreen)

            if shouldResumePrevious then
                runLifecycleHook(previousScreen.definition.onResume, previousScreen.context)
            end
        end

        return poppedScreen
    end

    function router:reset(routeName, params)
        local definition = getResetScreenDefinition(routeName)
        local entry, reused = prepareScreenEntry("Router.reset", routeName, definition, params)

        if entry == nil then
            return nil
        end

        local exitingScreens = collectResetScreenEntries()

        for _, exitingScreen in exitingScreens do
            exitingScreen.state = "exiting"
            setEntryActive(exitingScreen, false)
            state.retainedScreens[exitingScreen.key] = nil
            runLifecycleHook(exitingScreen.definition.onExit, exitingScreen.context)
            scopeOwner.cleanup(exitingScreen)
        end

        clearArray(state.modalStack)
        clearArray(state.screenStack)
        clearArray(state.overlayEntries)
        clearArray(state.retainedScreens)
        retainedKeepAlive = {}
        retainedSingleton = {}
        state.currentTransition = nil

        table.insert(state.screenStack, entry)

        local mounted, mountResult = pcall(activateScreenEntry, entry, reused)

        if not mounted then
            table.remove(state.screenStack)
            if reused then
                storeRetainedEntry(entry)
            else
                scopeOwner.cleanup(entry)
            end
            error(mountResult, 0)
        end

        runLifecycleHook(definition.onEnter, entry.context)

        return mountResult
    end

    function router:pushModal(routeName, params)
        local definition = getModalDefinition(routeName)
        local entry = prepareModalEntry("Router.pushModal", routeName, definition, params)

        if entry == nil then
            return nil
        end

        local currentModal = state.modalStack[#state.modalStack]
        local currentModalSnapshot = nil
        local previousTransition = state.currentTransition

        if currentModal ~= nil then
            currentModalSnapshot = {
                state = currentModal.state,
                isActive = ensureActiveState(currentModal).value,
            }

            setEntryActive(currentModal, false)
        end

        table.insert(state.modalStack, entry)
        state.currentTransition = definition.transition or registries.transitions.modalOpen

        local mounted, mountResult = pcall(mountModalEntry, entry)

        if not mounted then
            table.remove(state.modalStack)
            state.currentTransition = previousTransition
            scopeOwner.cleanup(entry)

            if currentModalSnapshot ~= nil then
                restoreModalState(currentModal, currentModalSnapshot)
            end

            error(mountResult, 0)
        end

        local onEnter = definition.onEnter

        if onEnter ~= nil then
            local entered, enterError = pcall(onEnter, entry.context)

            if not entered then
                table.remove(state.modalStack)
                state.currentTransition = previousTransition
                scopeOwner.cleanup(entry)

                if currentModalSnapshot ~= nil then
                    restoreModalState(currentModal, currentModalSnapshot)
                end

                error(enterError, 0)
            end
        end

        return mountResult
    end

    function router:popModal()
        return closeTopModal("Router.popModal")
    end

    function router:closeAllModals()
        local closed = {}
        local originalTransition = state.currentTransition

        for index = #state.modalStack, 1, -1 do
            local modalEntry = state.modalStack[index]
            local canExit = modalEntry.definition.canExit

            if canExit ~= nil and canExit(modalEntry.context) == false then
                state.currentTransition = originalTransition

                return {}
            end
        end

        while #state.modalStack > 0 do
            local closedModal = closeTopModal("Router.closeAllModals")

            if closedModal == nil then
                break
            end

            table.insert(closed, closedModal)
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
