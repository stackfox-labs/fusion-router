local function isState(value)
    return type(value) == "table" and value._isFusionState == true
end

local function flattenChildren(input, destination)
    if input == nil then
        return
    end

    if isState(input) then
        flattenChildren(input._EXTREMELY_DANGEROUS_usedAsValue, destination)
    elseif type(input) == "table" and input.ClassName == nil then
        for _, child in input do
            flattenChildren(child, destination)
        end
    else
        table.insert(destination, input)
    end
end

local function createTestFusion()
    local fusion = {}

    local function notify(state)
        local listeners = table.clone(state._listeners)

        for _, listener in listeners do
            listener()
        end
    end

    function fusion.peek(target)
        if isState(target) then
            return target._EXTREMELY_DANGEROUS_usedAsValue
        end

        return target
    end

    local function createValue(scope, initialValue)
        local state = {
            _EXTREMELY_DANGEROUS_usedAsValue = initialValue,
            _isFusionState = true,
            _listeners = {},
            kind = "Value",
            scope = scope,
            value = initialValue,
        }

        function state:set(newValue)
            self._EXTREMELY_DANGEROUS_usedAsValue = newValue
            self.value = newValue
            notify(self)

            return newValue
        end

        table.insert(scope, function()
            table.clear(state._listeners)
        end)

        return state
    end

    function fusion.Value(scope, initialValue)
        return createValue(scope, initialValue)
    end

    local function observeState(target, callback)
        if not isState(target) then
            return function() end
        end

        table.insert(target._listeners, callback)

        return function()
            local index = table.find(target._listeners, callback)

            if index ~= nil then
                table.remove(target._listeners, index)
            end
        end
    end

    function fusion.Computed(scope, processor)
        local state = {
            _EXTREMELY_DANGEROUS_usedAsValue = nil,
            _isFusionState = true,
            _listeners = {},
            _subscriptions = {},
            kind = "Computed",
            scope = scope,
            value = nil,
        }

        local function recompute()
            for _, disconnect in state._subscriptions do
                disconnect()
            end

            table.clear(state._subscriptions)

            local innerScope = fusion:scoped()
            local dependencies = {}
            local value = processor(function(target)
                if isState(target) and table.find(dependencies, target) == nil then
                    table.insert(dependencies, target)
                end

                return fusion.peek(target)
            end, innerScope)

            state._EXTREMELY_DANGEROUS_usedAsValue = value
            state.value = value

            for _, dependency in dependencies do
                table.insert(state._subscriptions, observeState(dependency, recompute))
            end

            notify(state)
        end

        recompute()
        table.insert(scope, function()
            for _, disconnect in state._subscriptions do
                disconnect()
            end
        end)

        return state
    end

    function fusion.Observer(scope, watching)
        local observer = {}

        function observer:onChange(callback)
            return observeState(watching, callback)
        end

        function observer:onBind(callback)
            callback()
            return observeState(watching, callback)
        end

        table.insert(scope, function() end)

        return observer
    end

    function fusion.Tween(scope, goalState, tweenInfo)
        local tween = fusion.Computed(scope, function(use)
            return use(goalState)
        end)
        tween.kind = "Tween"
        tween.tweenInfo = tweenInfo

        return tween
    end

    fusion.Spring = fusion.Tween

    fusion.Children = table.freeze({
        kind = "Children",
    })

    fusion.Attribute = function(name)
        return table.freeze({
            kind = "Attribute",
            name = name,
        })
    end

    fusion.OnEvent = function(name)
        return table.freeze({
            kind = "OnEvent",
            name = name,
        })
    end

    local function bindProp(node, key, value)
        local function assign(nextValue)
            node[key] = nextValue
        end

        assign(fusion.peek(value))

        if isState(value) then
            table.insert(
                node._disconnects,
                observeState(value, function()
                    assign(fusion.peek(value))
                end)
            )
        end
    end

    function fusion.New(scope, className)
        return function(props)
            local node = {
                _disconnects = {},
                Attributes = {},
                Children = {},
                ClassName = className,
                Events = {},
            }

            for key, value in props do
                if key == fusion.Children then
                    local function assignChildren(nextValue)
                        local nextChildren = {}
                        flattenChildren(nextValue, nextChildren)
                        node.Children = nextChildren
                    end

                    assignChildren(fusion.peek(value))

                    if isState(value) then
                        table.insert(
                            node._disconnects,
                            observeState(value, function()
                                assignChildren(fusion.peek(value))
                            end)
                        )
                    end
                elseif type(key) == "table" and key.kind == "Attribute" then
                    local function assignAttribute(nextValue)
                        node.Attributes[key.name] = nextValue
                    end

                    assignAttribute(fusion.peek(value))

                    if isState(value) then
                        table.insert(
                            node._disconnects,
                            observeState(value, function()
                                assignAttribute(fusion.peek(value))
                            end)
                        )
                    end
                elseif type(key) == "table" and key.kind == "OnEvent" then
                    node.Events[key.name] = value
                    node[("On%s"):format(key.name)] = value
                else
                    bindProp(node, key, value)
                end
            end

            function node:destroy()
                for _, disconnect in self._disconnects do
                    disconnect()
                end

                table.clear(self._disconnects)
            end

            table.insert(scope, node)

            return node
        end
    end

    function fusion.doCleanup(task)
        if type(task) == "function" then
            task()
        elseif type(task) == "table" then
            if type(task.destroy) == "function" then
                task:destroy()
                return
            end

            if type(task.Destroy) == "function" then
                task:Destroy()
                return
            end

            for index = #task, 1, -1 do
                fusion.doCleanup(task[index])
            end
        end
    end

    function fusion.scoped(...)
        local scope = {}

        for _, source in { ... } do
            if type(source) == "table" then
                for key, value in source do
                    if scope[key] == nil then
                        scope[key] = value
                    end
                end
            end
        end

        if next(scope) == nil then
            for key, value in fusion do
                scope[key] = value
            end
        end

        scope.doCleanup = fusion.doCleanup

        return scope
    end

    return table.freeze(fusion)
end

return createTestFusion
