local Instruction = {}

Instruction.TriggerType = {Left=1, Right=2}
Instruction.ModeType = {Normal=0, Resistant=1, Vib=2, Gap=3}

local ForceMax = 255
local ForceMin = 1
local LengthMax = 200
local LengthMin = 0
local VibMax = 200
local VibMin = 1
local FreqMax = 200
local FreqMin = 1

local instruction_keys = {'trigger', 'mode', 'param1', 'param2', 'param3', 'param4'}

function Instruction:new(mode, param1, param2, param3, param4, trigger)
    local newObj = {
        trigger = trigger,
        mode = mode,
        param1 = param1,
        param2 = param2,
        param3 = param3,
        param4 = param4
    }
    self.__index = self
    return setmetatable(newObj, self)
end

function Instruction:clone(with_after)
    local i = Instruction:new()
    self:Normalize()
    for _, k in ipairs(instruction_keys) do 
        i[k] = self[k]
    end
    if self.after ~= nil and with_after then
        self.after:Normalize()
        i.after = self.after:clone()
        i.duration = self.duration
    end
    return i
end

function Instruction:equal(other)
    local same = true
    self:Normalize()
    other:Normalize()
    for _, k in ipairs(instruction_keys) do
        if self[k] ~= other[k] then
            same = false
            break
        end
    end
    return same
end

function Instruction:is_nil()
    return not self.mode
end

function Instruction:packet()
    local data = {}
    if self:is_nil() then
        data.type = 0
        data.parameters = nil
        return data
    end
    self:Normalize()
    data.type = 1
    data.parameters = {
        0, -- always 0
        self.trigger, 
        19, -- flydigi value
        tostring(self.mode),
        tostring(self.param1),
        tostring(self.param2),
        tostring(self.param3),
        tostring(self.param4)
    }
    return data
end

function Instruction:Params(params)
    if not params then return {self.param1, self.param2, self.param3, self.param4} end
    if self.setting_after and self.after ~= nil then 
        self.after:Params(params)
        return self
    end
    for i = 1, 4 do 
        if params[i] then
            self['param'..tostring(i)] = params[i]
        end
    end
    return self
end

function Instruction:Param(idx, value, if_mode)
    if idx == nil and value == nil then return nil end
    if idx == nil and value ~= nil then return self end
    local k = 'param'..tostring(idx)
    if not value then 
        if if_mode ~= nil and if_mode ~= self.mode then
            return 
        end
        return self[k] 
    end
    if self.setting_after and self.after ~= nil then
        self.after:Param(idx, value, if_mode)
        return self
    end
    if if_mode ~= nil and if_mode ~= self.mode then
        return self
    end
    self[k] = value
    return self
end

function Instruction:Mode(mode)
    if not mode then return self.mode end
    if self.setting_after and self.after then
        self.after:Mode(mode)
        return self
    end
    if self.mode ~= mode then
        self:Params({})
        self.mode = mode 
    end
    return self
end

function Instruction:Trigger(trigger)
    if trigger == nil then return self.trigger end
    if self.setting_after and self.after then
        self.after:Trigger(trigger)
        return self
    end
    self.trigger = trigger
    return self
end

function Instruction:Normal()
    return self:Mode(Instruction.ModeType.Normal)
end

function Instruction:Resistant()
    return self:Mode(Instruction.ModeType.Resistant):AdaptOutputData(true)
end

function Instruction:Vib()
    return self:Mode(Instruction.ModeType.Vib)
end

function Instruction:Gap()
    return self:Mode(Instruction.ModeType.Gap)
end

function Instruction:Left()
    return self:Trigger(Instruction.TriggerType.Left)
end

function Instruction:Right()
    return self:Trigger(Instruction.TriggerType.Right)
end

function Instruction:force_param_position()
    if self.mode == Instruction.ModeType.Resistant then return 2 end
    if self.mode == Instruction.ModeType.Vib then return 2 end
    if self.mode == Instruction.ModeType.Gap then return 3 end
    return nil
end

function Instruction:Force(force) -- 0 - 255
    local pos = self:force_param_position()
    if not force then return self:Param(pos) end
    if self.setting_after and self.after ~= nil then
        pos = self.after:force_param_position()
    end
    self:Param(pos, force)
    return self
end

function Instruction:ForceMax(offset)
    if offset == nil then offset = 0 end
    if offset > 0 then offset = 0 - offset end
    return self:Force(ForceMax + offset)
end

function Instruction:ForceMin(offset)
    if offset == nil then offset = 0 end
    if offset < 0 then offset = 0 - offset end
    return self:Force(ForceMin + offset)
end

function Instruction:begin_position()
    if self.mode == Instruction.ModeType.Resistant then return 1 end
    if self.mode == Instruction.ModeType.Vib then return 1 end
    if self.mode == Instruction.ModeType.Gap then return 1 end
    return nil
end

function Instruction:Begin(distance) -- 0 - 200
    local pos = self:begin_position()
    if not distance then return self:Param(pos) end
    if self.setting_after and self.after ~= nil then
        pos = self.after:begin_position()
    end
    self:Param(pos, distance)
    return self
end

function Instruction:BeginTop(offset)
    if offset == nil then offset = 0 end
    if offset < 0 then offset = 0 - offset end
    return self:Begin(LengthMin + offset)
end

function Instruction:BeginHalf(offset)
    if offset == nil then offset = 0 end
    return self:Begin(LengthMin + (LengthMax - LengthMin) / 2 + offset)
end

function Instruction:BeginBottom(offset)
    if offset == nil then offset = 0 end
    if offset > 0 then offset = 0 - offset end
    return self:Begin(LengthMax + offset)
end

function Instruction:BeginOffset(offset)
    if offset == nil then offset = 0 end
    return self:Begin(self:Begin() + offset)
end

function Instruction:BeginDefault()
    local default = Instruction.defaults.right:Begin()
    if self.trigger == Instruction.TriggerType.Left then
        default = Instruction.defautls.left:Begin()
    end
    return self:Begin(default)
end

function Instruction:AdaptOutputData(a) -- true false
    if a ~= nil then
        a = a and 1 or 0
    end
    return self:Param(3, a, Instruction.ModeType.Resistant)
end

function Instruction:VibForce(force) -- 0 - 200
    return self:Param(3, force, Instruction.ModeType.Vib)
end

function Instruction:VibForceMax()
    return self:VibForce(VibMax)
end

function Instruction:VibForceMin()
    return self:VibForce(VibMin)
end

function Instruction:VibFreq(freq) -- 0 - 200
    return self:Param(4, freq, Instruction.ModeType.Vib)
end

function Instruction:Length(length) -- 0 - 200
    return self:Param(2, length, Instruction.ModeType.Gap)
end

function Instruction:LengthMax()
    return self:Length(LengthMax)
end

function Instruction:LengthMin()
    return self:Length(LengthMin)
end

function Instruction:After(secs, a)
    if secs == nil then
        return
    end
    self.duration = secs
    if a == nil then
        a = Instruction:new()
    end
    self.after = a
    self.after.trigger = self.trigger
    self.setting_after = true
    local mode_str = " nil"
    if self.after.mode ~= nil then
        mode_str = " "..self.after.mode
    end
    return self
end

function Instruction:Duration(secs, a)
    if a == nil then
        a = Instruction.right_default()
        if self.trigger == Instruction.TriggerType.Left then
            a = Instruction.left_default()
        end
    end
    return self:After(secs, a):Before()
end

function Instruction:Before()
    self.setting_after = false
    return self
end

function Instruction:VibFor(duration, after)
    return self:Vib():Duration(duration, after)
end

function Instruction:get_setting_obj()
    if self.setting_after and self.after ~= nil then
        return self.after
    end
    return self
end

function Instruction:next(now)
    if now == nil then return nil end
    if self.after == nil or self.duration == nil or self.send_at == nil then return nil end
    if now >= self.send_at + self.duration then
        return self.after
    end
    return nil
end

function Instruction:mark_sent()
    if self.send_at ~= nil then return end
    self.send_at = Instruction.client.socket.gettime()
end

function Instruction:PushBack(duration, after)
    if duration == nil then duration = 0.5 end
    return self:Vib():BeginTop():ForceMax():VibForceMax():VibFreq(2):Duration(duration, after)
end

function Instruction.left_default()
    return Instruction.defaults.left:clone():Left()
end

function Instruction.right_default()
    return Instruction.defaults.right:clone():Right()
end

function Instruction.new_left()
    return Instruction:new():Left()
end

function Instruction.new_right()
    return Instruction:new():Right()
end

local function normalize_param(value, min, max)
    if value == nil then return min end
    if value < min then return min end
    if value > max then return max end
    return value
end

function Instruction:Normalize()
    if self:is_nil() then 
        self:Params({})
    else
        local force = self:Force()
        local new_force = normalize_param(force, ForceMin, ForceMax)
        if new_force ~= force then self:Force(new_force) end
        local begin = self:Begin()
        local new_begin = normalize_param(begin, LengthMin, LengthMax)
        if new_begin ~= begin then self:Begin(new_begin) end
        local length = self:Length()
        local new_length = normalize_param(length, LengthMin, LengthMax)
        if new_length ~= length then self:Length(new_length) end
        local vib_force = self:VibForce()
        local new_vib_force = normalize_param(vib_force, VibMin, VibMax)
        if new_vib_force ~= vib_force then self:VibForce(new_vib_force) end
        local vib_freq = self:VibFreq()
        local new_vib_freq = normalize_param(vib_freq, FreqMin, FreqMax)
        if new_vib_freq ~= vib_freq then self:VibFreq(new_vib_freq) end
    end
    for i = 1, 4 do 
        local k = 'param'..tostring(i)
        if self[k] == nil then
            self[k] = 0
        end
    end
    return self
end

Instruction.defaults = {
    left = Instruction:new():Trigger(Instruction.TriggerType.Left):Resistant():ForceMax():BeginHalf(),
    right = Instruction:new():Trigger(Instruction.TriggerType.Right):Resistant():ForceMax():BeginHalf()
}

return Instruction
