local Validation = require("../shared/validation")

local REQUIRED_ROUTER_METHODS = {
    "push",
    "replace",
    "back",
    "reset",
    "pushModal",
    "popModal",
}

local function bindNavigationMethod(context, router, methodName)
    return function(firstArg, secondArg, thirdArg)
        local routeName = secondArg
        local params = thirdArg

        if firstArg ~= context then
            routeName = firstArg
            params = secondArg
        end

        return router[methodName](router, routeName, params)
    end
end

local function bindNoArgMethod(router, methodName)
    return function()
        return router[methodName](router)
    end
end

local function validateEntry(subject, entry)
    Validation.expectTableOrNil(subject, entry, "entry", 2)

    if entry == nil then
        error(("%s expected entry to be a table, got nil"):format(subject), 2)
    end

    if entry.kind ~= "screen" and entry.kind ~= "modal" and entry.kind ~= "overlay" then
        error(("%s expected entry.kind to be 'screen', 'modal', or 'overlay'"):format(subject), 2)
    end

    Validation.expectRouteName(subject, entry.name, 1)
    Validation.expectNonEmptyString(subject, entry.key, "entry.key", 1)
    Validation.expectTableOrNil(subject, entry.scope, "entry.scope", 1)

    if entry.scope == nil then
        error(("%s expected entry.scope to be a table, got nil"):format(subject), 2)
    end
end

local function validateRouter(subject, router)
    Validation.expectTableOrNil(subject, router, "router", 2)

    if router == nil then
        error(("%s expected router to be a table, got nil"):format(subject), 2)
    end

    for _, methodName in REQUIRED_ROUTER_METHODS do
        Validation.expectFunction(subject, router[methodName], ("router.%s"):format(methodName), 1)
    end
end

local function createRouteContext(entry, router, isActive)
    local subject = "createRouteContext"

    validateEntry(subject, entry)
    validateRouter(subject, router)

    local context
    context = {
        scope = entry.scope,
        router = router,
        params = entry.params,
        routeName = entry.name,
        routeKey = entry.key,
        isActive = isActive,
        push = false :: any,
        replace = false :: any,
        back = false :: any,
        reset = false :: any,
        pushModal = false :: any,
        popModal = false :: any,
        close = false :: any,
    }

    context.push = bindNavigationMethod(context, router, "push")
    context.replace = bindNavigationMethod(context, router, "replace")
    context.back = bindNoArgMethod(router, "back")
    context.reset = bindNavigationMethod(context, router, "reset")
    context.pushModal = bindNavigationMethod(context, router, "pushModal")
    context.popModal = bindNoArgMethod(router, "popModal")

    if entry.kind == "modal" then
        context.close = bindNoArgMethod(router, "popModal")
    elseif entry.kind == "screen" then
        context.close = bindNoArgMethod(router, "back")
    else
        context.close = function()
            return nil
        end
    end

    context = table.freeze(context)
    entry.context = context

    return context
end

return createRouteContext
