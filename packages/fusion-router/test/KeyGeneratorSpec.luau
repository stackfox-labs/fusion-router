local createRuntimeKeyGenerator = require("../src/runtime/keyGenerator")

return {
    name = "runtime key generator produces stable screen and modal keys",
    run = function()
        local generator = createRuntimeKeyGenerator()

        assert(table.isfrozen(generator), "Key generator should be frozen")
        assert(
            type(generator.nextScreenKey) == "function",
            "Key generator should expose nextScreenKey"
        )
        assert(
            type(generator.nextModalKey) == "function",
            "Key generator should expose nextModalKey"
        )

        assert(generator.nextScreenKey() == "screen_1", "First screen key should be screen_1")
        assert(generator.nextScreenKey() == "screen_2", "Second screen key should be screen_2")
        assert(generator.nextModalKey() == "modal_1", "First modal key should be modal_1")
        assert(generator.nextScreenKey() == "screen_3", "Screen keys should keep incrementing")
        assert(generator.nextModalKey() == "modal_2", "Modal keys should keep incrementing")

        local otherGenerator = createRuntimeKeyGenerator()

        assert(
            otherGenerator.nextScreenKey() == "screen_1",
            "A new key generator should start its screen counter at 1"
        )
        assert(
            otherGenerator.nextModalKey() == "modal_1",
            "A new key generator should start its modal counter at 1"
        )
    end,
}
