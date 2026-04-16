type TestCase = {
    name: string,
    run: () -> (),
}

local cases: { TestCase } = {
    require("./packages/fusion-router/test/CreateRouterSpec"),
    require("./packages/fusion-router/test/EntryFactorySpec"),
    require("./packages/fusion-router/test/InspectionHelpersSpec"),
    require("./packages/fusion-router/test/NavigationValidationSpec"),
    require("./packages/fusion-router/test/KeyGeneratorSpec"),
    require("./packages/fusion-router/test/ScreenPushSpec"),
    require("./packages/fusion-router/test/ScreenReplaceSpec"),
    require("./packages/fusion-router/test/ScreenBackSpec"),
    require("./packages/fusion-router/test/ScreenResetSpec"),
    require("./packages/fusion-router/test/ScreenCloseSpec"),
    require("./packages/fusion-router/test/ScreenRetentionSpec"),
    require("./packages/fusion-router/test/ScreenDestroyLifecycleSpec"),
    require("./packages/fusion-router/test/ModalPushSpec"),
    require("./packages/fusion-router/test/ModalCloseSpec"),
    require("./packages/fusion-router/test/ModalAtomicitySpec"),
    require("./packages/fusion-router/test/ActiveStateSpec"),
    require("./packages/fusion-router/test/SmokeSpec"),
    require("./packages/fusion-router/test/ModalDefinitionSpec"),
    require("./packages/fusion-router/test/OverlayDefinitionSpec"),
    require("./packages/fusion-router/test/RouteContextSpec"),
    require("./packages/fusion-router/test/ScreenDefinitionSpec"),
    require("./packages/fusion-router/test/ScopeOwnerSpec"),
    require("./packages/fusion-router/test/ValidationHelpersSpec"),
}

local passed = 0

for _, case in cases do
    local ok, err = pcall(case.run)

    if ok then
        passed += 1
        print(("PASS %s"):format(case.name))
    else
        error(("FAIL %s\n%s"):format(case.name, tostring(err)))
    end
end

print(("Test summary: %d passed"):format(passed))
