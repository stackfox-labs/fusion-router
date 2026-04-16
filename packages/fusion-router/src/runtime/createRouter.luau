local EntryFactory = require("./entries")
local Validation = require("../shared/validation")
local createRuntimeKeyGenerator = require("./keyGenerator")
local createRouteContext = require("./routeContext")

local TRANSITION_DURATIONS = {
    fade = 0.18,
    slideLeft = 0.24,
    slideRight = 0.24,
    fadeScaleIn = 0.2,
    fadeOut = 0.18,
}

type RouterDeps = {
    createRuntimeKeyGenerator: ((
    ) -> {
        nextScreenKey: () -> string,
        nextModalKey: () -> string,
    })?,
    createRouteContext: ((entry: any, router: any, isActive: any) -> any)?,
    createScopeOwner: ((fusion: any?) -> any)?,
    fusion: any?,
    scheduler: any?,
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
                        ("%s expected route '%s' to be a %s route, but it is registered as a %s route"):format(
                            subject,
                            routeName,
                            routeKind,
                            otherRouteKind
                        ),
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

local function clearMap(map)
    for key in map do
        map[key] = nil
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

local function getTransitionDuration(presetName)
    return TRANSITION_DURATIONS[presetName] or 0.2
end

local function createRouter(config, deps: RouterDeps?)
    Validation.validateRouterConfig(config)

    local resolvedDeps = deps or {}
    local keyGeneratorFactory = resolvedDeps.createRuntimeKeyGenerator or createRuntimeKeyGenerator
    local keyGenerator = keyGeneratorFactory()
    local routeContextFactory = resolvedDeps.createRouteContext or createRouteContext
    local scopeOwnerFactory = resolvedDeps.createScopeOwner
    local scopeOwner = if scopeOwnerFactory ~= nil
        then scopeOwnerFactory(resolvedDeps.fusion)
        else createBasicScopeOwner()

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
        exitingScreens = {},
        exitingModals = {},
        retainedScreens = {},
        currentTransition = nil,
    }
    local retainedKeepAlive = {}
    local retainedSingleton = {}

    local router = {
        _registries = registries,
        _runtime = {
            appBinding = nil,
            keyGenerator = keyGenerator,
            listeners = {},
            scheduler = resolvedDeps.scheduler,
        },
        _state = state,
    }

    local function notifyStateChanged()
        for _, listener in router._runtime.listeners do
            listener()
        end
    end

    function router._runtime.subscribe(listener)
        Validation.expectFunction("Router._runtime.subscribe", listener, "listener", 1)

        table.insert(router._runtime.listeners, listener)

        return function()
            local index = table.find(router._runtime.listeners, listener)

            if index ~= nil then
                table.remove(router._runtime.listeners, index)
            end
        end
    end

    function router._runtime.bindApp(binding)
        Validation.expectTableOrNil("Router._runtime.bindApp", binding, "binding", 1)

        router._runtime.appBinding = binding
        notifyStateChanged()

        return function()
            if router._runtime.appBinding == binding then
                router._runtime.appBinding = nil
                notifyStateChanged()
            end
        end
    end

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

    local function getBoundScheduler()
        local appBinding = router._runtime.appBinding

        if appBinding ~= nil and type(appBinding.scheduler) == "table" then
            return appBinding.scheduler
        end

        return router._runtime.scheduler
    end

    local function hasBoundApp()
        return router._runtime.appBinding ~= nil
    end

    local function removeTrackedEntry(list, entry)
        local index = table.find(list, entry)

        if index ~= nil then
            table.remove(list, index)
        end
    end

    local function cancelPendingTransition(entry)
        local transitionHandle = entry._transitionHandle
        local scheduler = getBoundScheduler()

        if
            transitionHandle ~= nil
            and scheduler ~= nil
            and type(scheduler.cancel) == "function"
        then
            scheduler.cancel(transitionHandle)
        end

        entry._transitionHandle = nil
        entry._transitionToken = (entry._transitionToken or 0) + 1
        entry.transition = nil
    end

    local function scheduleTransition(entry, presetName, phase, onComplete)
        local scheduler = getBoundScheduler()

        cancelPendingTransition(entry)

        if
            presetName == nil
            or not hasBoundApp()
            or scheduler == nil
            or type(scheduler.delay) ~= "function"
        then
            entry.transition = nil
            onComplete()
            notifyStateChanged()

            return false
        end

        local transitionToken = (entry._transitionToken or 0) + 1
        local duration = getTransitionDuration(presetName)

        entry._transitionToken = transitionToken
        entry.transition = {
            duration = duration,
            name = presetName,
            phase = phase,
        }
        entry._transitionHandle = scheduler.delay(duration, function()
            if entry._transitionToken ~= transitionToken then
                return
            end

            entry._transitionHandle = nil
            entry.transition = nil
            onComplete()
            notifyStateChanged()
        end)

        notifyStateChanged()

        return true
    end

    local function resolveScreenEnterTransition(definition)
        return definition.enterTransition or registries.transitions.screenPush
    end

    local function resolveScreenExitTransition(definition, defaultTransition)
        return definition.exitTransition or defaultTransition
    end

    local function trackExitingScreen(entry, presetName, finalizer)
        table.insert(state.exitingScreens, entry)
        entry.state = "exiting"
        setEntryActive(entry, false)

        local completed = scheduleTransition(entry, presetName, "exiting", function()
            removeTrackedEntry(state.exitingScreens, entry)
            finalizer()
        end)

        if not completed then
            removeTrackedEntry(state.exitingScreens, entry)
        end
    end

    local function trackExitingModal(entry, presetName, finalizer)
        table.insert(state.exitingModals, entry)
        entry.state = "exiting"
        setEntryActive(entry, false)

        local completed = scheduleTransition(entry, presetName, "exiting", function()
            removeTrackedEntry(state.exitingModals, entry)
            finalizer()
        end)

        if not completed then
            removeTrackedEntry(state.exitingModals, entry)
        end
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

    local function beginScreenEnterTransition(entry)
        local presetName = resolveScreenEnterTransition(entry.definition)

        if hasBoundApp() then
            state.currentTransition = presetName
        end

        if presetName == nil or not hasBoundApp() then
            entry.state = "active"
            setEntryActive(entry, true)
            notifyStateChanged()

            return
        end

        entry.state = "entering"
        setEntryActive(entry, true)
        scheduleTransition(entry, presetName, "entering", function()
            entry.state = "active"
            setEntryActive(entry, true)
        end)
    end

    local function beginModalEnterTransition(entry)
        local presetName = entry.definition.transition or registries.transitions.modalOpen

        state.currentTransition = presetName

        if presetName == nil or not hasBoundApp() then
            entry.state = "active"
            setEntryActive(entry, true)
            notifyStateChanged()

            return
        end

        entry.state = "entering"
        setEntryActive(entry, true)
        scheduleTransition(entry, presetName, "entering", function()
            entry.state = "active"
            setEntryActive(entry, true)
        end)
    end

    local function resolveOverlayVisibility(entry)
        local visibleSource = entry.visible

        if visibleSource == nil then
            return true
        end

        if type(visibleSource) == "boolean" then
            return visibleSource
        end

        local fusion = resolvedDeps.fusion

        if fusion ~= nil and type(fusion.peek) == "function" then
            local peeked, visibleValue = pcall(fusion.peek, visibleSource)

            if not peeked then
                error(visibleValue, 0)
            end

            return not not visibleValue
        end

        if type(visibleSource) == "table" then
            local rawValue = rawget(visibleSource, "value")

            if type(rawValue) == "boolean" then
                return rawValue
            end

            local currentValue = rawget(visibleSource, "current")

            if type(currentValue) == "boolean" then
                return currentValue
            end
        end

        return not not visibleSource
    end

    local function mountOverlayEntry(entry)
        local context = ensureEntryContext(entry)

        entry.instance = entry.definition.component(context)
        entry.isMounted = true

        return entry
    end

    local syncOverlayEntry

    local function subscribeOverlayVisibility(entry)
        local visibleSource = entry.visible

        if type(visibleSource) ~= "table" then
            return
        end

        local subscribe = visibleSource.subscribe or visibleSource.onChange

        if type(subscribe) ~= "function" then
            return
        end

        local disconnect = subscribe(visibleSource, function()
            syncOverlayEntry(entry)
        end)

        if type(disconnect) == "function" then
            entry.visibilityCleanup = disconnect
        end
    end

    function syncOverlayEntry(entry)
        local isVisible = resolveOverlayVisibility(entry)
        local shouldMount = entry.persistent or isVisible

        entry.isVisible = isVisible

        if shouldMount and not entry.isMounted then
            mountOverlayEntry(entry)
            runLifecycleHook(entry.definition.onEnter, entry.context)
        elseif not shouldMount and entry.isMounted then
            runLifecycleHook(entry.definition.onExit, entry.context)
            scopeOwner.cleanup(entry)
        end

        if entry.isMounted then
            entry.state = if isVisible then "active" else "hidden"
        else
            entry.state = "inactive"
        end

        setEntryActive(entry, entry.isMounted and isVisible)
        notifyStateChanged()

        return entry
    end

    local function registerOverlays()
        clearArray(state.overlayEntries)

        local entries = {}

        for routeName, definition in registries.overlays do
            table.insert(entries, EntryFactory.createOverlayEntry(routeName, definition))
        end

        table.sort(entries, function(left, right)
            return left.name < right.name
        end)

        for _, entry in entries do
            subscribeOverlayVisibility(entry)
            syncOverlayEntry(entry)
            table.insert(state.overlayEntries, entry)
        end

        notifyStateChanged()
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
            cancelPendingTransition(nextModal)
            nextModal.state = "active"
            setEntryActive(nextModal, true)
        end

        notifyStateChanged()

        return nextModal
    end

    local function closeTopModal()
        local modalCount = #state.modalStack

        if modalCount == 0 then
            return nil
        end

        local currentModal = state.modalStack[modalCount]
        local canExit = currentModal.definition.canExit

        if canExit ~= nil and canExit(currentModal.context) == false then
            return nil
        end

        local closeTransition = currentModal.definition.transition
            or registries.transitions.modalClose

        state.currentTransition = closeTransition

        local closedModal = table.remove(state.modalStack)
        runLifecycleHook(closedModal.definition.onExit, closedModal.context)

        if closeTransition ~= nil and hasBoundApp() then
            trackExitingModal(closedModal, closeTransition, function()
                scopeOwner.cleanup(closedModal)
            end)
        else
            closedModal.state = "exiting"
            setEntryActive(closedModal, false)
            scopeOwner.cleanup(closedModal)
        end

        activateUnderlyingModal()
        notifyStateChanged()

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

                local pushExitTransition = resolveScreenExitTransition(
                    currentScreen.definition,
                    registries.transitions.screenPush
                )

                if pushExitTransition ~= nil and hasBoundApp() and currentScreen.isMounted then
                    currentScreen.state = "exiting"
                    scheduleTransition(currentScreen, pushExitTransition, "exiting", function()
                        currentScreen.state = "paused"
                        scopeOwner.cleanup(currentScreen)
                    end)
                end
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
            if not hasBoundApp() or currentScreen.transition == nil then
                scopeOwner.cleanup(currentScreen)
            end
        end

        beginScreenEnterTransition(entry)
        notifyStateChanged()

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
                local replaceExitTransition = resolveScreenExitTransition(
                    currentScreen.definition,
                    registries.transitions.screenPop
                )

                if replaceExitTransition ~= nil and hasBoundApp() then
                    trackExitingScreen(currentScreen, replaceExitTransition, function()
                        scopeOwner.cleanup(currentScreen)
                    end)
                else
                    currentScreen.state = "exiting"
                    setEntryActive(currentScreen, false)
                    scopeOwner.cleanup(currentScreen)
                end
            end
        end

        beginScreenEnterTransition(entry)
        notifyStateChanged()

        return mountResult
    end

    function router:back()
        if #state.modalStack > 0 then
            return closeTopModal()
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
        local shouldResumePrevious = previousScreen ~= nil
            and (previousScreen.state == "paused" or previousScreen.state == "exiting")
        local poppedScreen = table.remove(state.screenStack)

        setEntryActive(poppedScreen, false)

        if poppedScreen.retained then
            poppedScreen.state = "paused"
            storeRetainedEntry(poppedScreen)
        else
            state.retainedScreens[poppedScreen.key] = nil
            runLifecycleHook(poppedScreen.definition.onExit, poppedScreen.context)

            local backExitTransition = resolveScreenExitTransition(
                poppedScreen.definition,
                registries.transitions.screenPop
            )

            if backExitTransition ~= nil and hasBoundApp() then
                trackExitingScreen(poppedScreen, backExitTransition, function()
                    scopeOwner.cleanup(poppedScreen)
                end)
            else
                poppedScreen.state = "exiting"
                scopeOwner.cleanup(poppedScreen)
            end
        end

        if previousScreen ~= nil then
            cancelPendingTransition(previousScreen)
            resumeScreenEntry(previousScreen)

            if shouldResumePrevious then
                runLifecycleHook(previousScreen.definition.onResume, previousScreen.context)
            end
        end

        if hasBoundApp() then
            state.currentTransition = resolveScreenExitTransition(
                poppedScreen.definition,
                registries.transitions.screenPop
            )
        end
        notifyStateChanged()

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
        clearArray(state.exitingScreens)
        clearArray(state.exitingModals)
        clearMap(state.retainedScreens)
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
        beginScreenEnterTransition(entry)
        notifyStateChanged()

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

        beginModalEnterTransition(entry)
        notifyStateChanged()

        return mountResult
    end

    function router:popModal()
        return closeTopModal()
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
            local closedModal = closeTopModal()

            if closedModal == nil then
                break
            end

            table.insert(closed, closedModal)
        end

        notifyStateChanged()

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
    state.currentTransition = nil
    registerOverlays()
    notifyStateChanged()

    return table.freeze(router)
end

return createRouter
