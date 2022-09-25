local Action = require('config.action')

local Config = {}

function Config:new(dict, name)
    local as = dict.actions 
    local newObj = {actions = {}, name=name}
    if type(as) == 'table' then
        for _, d in ipairs(as) do
            local a = Action:new(d)
            table.insert(newObj.actions, a)
        end
    end
    self.__index = self
    return setmetatable(newObj, self)
end

function Config.load_file(path, name)
    local d = json.load_file(path)
    if d == nil then return nil end
    return Config:new(d, name)
end

function Config:get_packet(prev, now, changed)
    for _, a in ipairs(self.actions) do
        local p = a:get_packet(prev, now, changed)
        if p ~= nil and not p:is_nil() then 
            if a.name then
                print(a.name.." "..self.name)
            end
            return p
        end
    end
    return nil
end

return Config
