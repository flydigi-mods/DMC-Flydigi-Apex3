local Client = require("udp_client.client")
local Packet = require("udp_client.packet")
local Instruction = require("udp_client.instruction")
Packet.Instruction = Instruction

Packet.setup = function(my_path, to_json, left_default, right_default, get_port)
    Packet.client = Client:new(my_path)
    Instruction.client = Packet.client
    Packet.json = to_json
    if get_port ~= nil then
        Client.get_port = get_port
    end
    Packet.set_default(left_default, right_default)
end

Instruction.get_current_packet = function()
    return Packet.current
end

Packet.current = Packet.get_default()

return Packet
