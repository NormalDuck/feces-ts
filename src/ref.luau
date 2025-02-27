--!strict
--!optimize 2

local handle = require("./handle")
local refs = require("./refs")

local function ref(world, key)
    if not key then
        return handle(world, world:entity())
    end
    local e = refs[key]
    if not e then
        e = world:entity()
        refs[key] = e
    end
    -- Cannot cache handles because they will get invalidated
    return handle(e)
end

return ref