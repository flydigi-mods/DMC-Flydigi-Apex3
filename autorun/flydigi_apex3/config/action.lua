local Packet = require("udp_client")
local Instruction = Packet.Instruction

local Controller = {}

Controller.Keys = {'trigger', 'mode', 'params', 'duration', 'after'}
function Controller:new(dict)
    local newObj = {}
    for _, k in ipairs(Controller.Keys) do
        if dict[k] ~= nil then
            if k == 'after' then
                dict[k].trigger = dict.trigger
                newObj[k] = Controller:new(dict[k])
            else
                newObj[k] = dict[k]
            end
        end
    end
    if newObj.params == nil then
        newObj.params = {0, 0, 0, 0}
    end
    self.__index = self
    return setmetatable(newObj, self)
end

function Controller:to_dict()
    local d = {}
    for _, k in ipairs(Controller.keys) do
        local v = self[k]
        if v ~= nil then
            if k == 'after' then
                d[k] = v:to_dict()
            else
                d[k] = v
            end
        end
    end
    return d
end

function Controller:to_instruction(trigger)
    if trigger == nil then trigger = self.trigger end
    if trigger ~= nil and self.trigger ~= nil and trigger ~= self.trigger then
        return nil
    end
    if (self.mode == "default" or self.mode == "current") and trigger == nil then
        return nil
    end
    local i = Instruction:new(self.mode, self.params[1], self.params[2], self.params[3], self.params[4])
    if self.mode == "default" then
        if trigger == 'left' then
            i = Instruction.left_default()
        elseif trigger == 'right' then
            i = Instruction.right_default()
        end
    end
    if self.mode == "current" then
        if trigger == 'left' then
            i = Packet.current.left:clone()
        elseif trigger == 'right' then
            i = Packet.current.right:clone()
        end
    end
    if self.duration ~= nil and self.duration > 0 then
        local a 
        if self.after == nil then
            a = nil
        else
            a = self.after:to_instruction(trigger)
        end
        i:Duration(self.duration, a)
    end
    return i
end

function Controller:to_packet()
    local left = self:to_instruction('left')
    local right = self:to_instruction('right')
    return Packet:new(left, right)
end

local Filter = {}
Filter.Keys = {"key", "op", "value", "changed", "prev"}
function Filter:new(dict)
    local newObj = {}
    for _, k in ipairs(Filter.Keys) do
        local v = dict[k]
        if v ~= nil then
            if k == 'value' then
                if type(v) == 'table' then
                    local d = {}
                    for _, i in ipairs(v) do
                        d[i] = true
                    end
                    v = d
                end
            end
            newObj[k] = v
        end
    end
    if newObj.op == nil and not newObj.changed then newObj.op = "=" end
    self.__index = self
    return setmetatable(newObj, self)
end

function Filter:to_dict()
    local d = {}
    for _, k in ipairs(Filter.Keys) do
        v = self[k]
        if v ~= nil then
            if k == 'value' then
                if type(v) == 'table' then
                    local d = {}
                    for k, _ in pairs(v) do
                        table.insert(d, k)
                    end
                    v = d
                end
            end
            d[k] = v
        end
    end
    return d
end

Filter.OpFuncs = {}
function Filter.get_op_func(op)
    if op == "=" then op = "==" end
    local f = Filter.OpFuncs[op]
    if f == nil then 
        local fu, err = load("return function(a, b) return a "..op.." b end")
        if fu then
            local ok, func = pcall(fu)
            if ok then
                f = func
            end
        end
        Filter.OpFuncs[op] = f
    end
    return f
end

local function op_in(value, range)
    if type(range) == 'table' then
        if range[value] then
            return true
        else
            return false
        end
    end
    if type(value) == 'number' then
        if type(range) == 'number' then
            return value == range
        end
        if type(range) == 'string' then
            return value == tonumber(range)
        end
    end
    if type(value) == 'string' then
        if type(range) == 'number' then
            return value == tostring(range)
        end
        if type(range) == 'string' then
            return value == range
        end
    end
    return false
end

function Filter:match(prev, now, changed)
    if self.changed then
        if not changed[self.key] then return false end 
        if self.op == nil then return true end
    end
    local key = self.key
    local state = now
    if self.prev then
        state = prev
    end
    if self.op == nil then
        print("op nil for "..self.key..self.value)
    end
    if self.op == "in" then
        return op_in(state[key], self.value)
    end
    if self.op == 'not in' or self.op == "notin" or self.op == "not_in" then
        return not op_in(state[key], self.value)
    end
    local f = Filter.get_op_func(self.op)
    if f == nil then return false end
    if type(self.value) == 'nil' then return false end
    local ok, r = pcall(f, state[key], self.value)
    if not ok then
        print("op func failed "..self.op.." "..state[key].." "..self.value) 
        return false 
    end
    return r
end

local Action = {}
Action.Keys = {'name', 'trigger', 'filters'}
function Action:new(dict)
    local newObj = {name=dict.name, controller=nil, filters={}}
    if dict.trigger == nil then
        newObj.trigger = Controller:new({mode = 'default'})
    else
        newObj.trigger = Controller:new(dict.trigger)
    end
    if dict.filters ~= nil then
        for _, f in ipairs(dict.filters) do
            table.insert(newObj.filters, Filter:new(f))
        end
    end
    self.__index = self
    return setmetatable(newObj, self)
end

function Action:match(prev, now, changed)
    for _, filter in ipairs(self.filters) do
        if not filter:match(prev, now, changed) then
            return false
        end
    end
    return true
end

function Action:get_packet(prev, now, changed)
    if self:match(prev, now, changed) then
        return self.trigger:to_packet()
    end
    return nil
end

function Action:to_dict()
    local d = {}
    if self.name then
       d.name = self.name
    end
    d.trigger = self.trigger:to_dict()
    d.filters = {}
    for _, f in ipairs(self.filters) do
        table.insert(d.filters, f:to_dict())
    end
    return d
end

Action.Filter = Filter
Action.Controller = Controller

return Action
