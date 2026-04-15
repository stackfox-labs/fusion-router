type TestCase = {
    name: string,
    run: () -> (),
}

local cases: { TestCase } = {
    require("./packages/fusion-router/test/SmokeSpec"),
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
