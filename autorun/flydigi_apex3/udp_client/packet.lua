local Instruction = require("udp_client.instruction")

local Packet = {}

Packet.json = nil

function Packet:new(left, right)
    local newObj = {
        left = left,
        right = right 
    }
    if not left then newObj.left = Instruction.new_left() end
    if not right then newObj.right = Instruction.new_right() end
    newObj.left:Left()
    newObj.right:Right()
    self.__index = self
    return setmetatable(newObj, self)
end

function Packet:clone()
    return Packet:new(self.left:clone(), self.right:clone())
end

function Packet:Left(left)
    if not left then return self.left end
    self.left = left:Left()
    return self
end

function Packet:Right(right)
    if not right then return self.right end
    self.right = right:Right()
    return self
end

function Packet:to_json()
    local data = {
        instructions = {self.left:Left():packet(), self.right:Right():packet()}
    }
    return Packet.json(data)
end

function Packet:equal(other)
    if not self.left:equal(other.left) then return false end
    if not self.right:equal(other.right) then return false end
    return true
end

function Packet:is_nil()
    return self.left:is_nil() and self.right:is_nil()
end

function Packet:delta(new_packet)
    local d = new_packet:clone()
    if self.left:equal(new_packet.left) then d:Left(Instruction.new_left()) end
    if self.right:equal(new_packet.right) then d:Right(Instruction.new_right()) end
    return d
end

function Packet:send()
    if self:is_nil() then
        return false
    end
    if Packet.client == nil then
        error("Packet.client not initialized you should call Packet.load first")
        return false
    end
    if Packet.client:connect() then
        local j = self:to_json()
        local sent, err = Packet.client:send(j)
        return not err
    end
    return false
end

function Packet:change(to)
    if to == nil or to:is_nil() then return end
    if self:equal(to) then return end
    local delta = self:delta(to)
    if delta:is_nil() then return end
    local to_apply = true
    if self == Packet.current then
        to_apply = delta:send()
    end
    if to_apply then
        to.left:mark_sent()
        to.right:mark_sent()
        -- print("p "..tostring(self.right.send_at).." "..delta:to_json())
        local left = to:Left()
        local right = to:Right()
        if left:is_nil() then left = self:Left() end
        if right:is_nil() then right = self:Right() end
        self:Left(left)
        self:Right(right)
    end
    return to_apply
end

function Packet:tick()
    local now = Packet.client.socket.gettime()
    local l = self.left:next(now)
    local r = self.right:next(now)
    if l ~= nil or r ~= nil then
        self:change(Packet:new(l, r))
    end
end

function Packet.set_default(left, right)
    if left ~= nil then
        Instruction.defaults.left = left:Left()
        if right ~= nil then
            Instruction.defaults.right = right:Right()
        else
            Instruction.defaults.right = left:clone():Right()
        end
    end
end

function Packet.get_default()
    return Packet:new(
        Instruction.left_default(),
        Instruction.right_default()
    )
end

return Packet
