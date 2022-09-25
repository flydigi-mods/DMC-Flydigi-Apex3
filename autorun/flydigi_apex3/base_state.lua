local c = require('cache')
local BaseState = {}

function BaseState:new(action, extra)
    local newObj = {action = action}
    if extra then
        for k, v in pairs(extra) do
            newObj[k] = v
        end
    end            
    self.__index = self
    return setmetatable(newObj, self)
end

function BaseState:is_nil()
    local has_value = false
    for _, v in pairs(self) do 
        if v ~= nil then
            has_value = true
            break
        end
    end
    return not has_value
end

function BaseState:display_str()
    local str = "action: "..tostring(self.action)
    for k, v in pairs(self) do
        if k ~= "action" then
            str = str.."\n"..k..": "..tostring(self[k])
        end
    end
    return str
end

function BaseState:changed(other)
    local changed = false
    local delta = {}
    for k, v in pairs(other) do
        if self[k] ~= v then
            changed = true
            delta[k] = true
        end
    end
    if not changed then return false end
    return delta
end

return BaseState