local os = 'unix'
if package.config:sub(1,1) == '\\' then
    os = 'windows'
end

local Client = {}
Client.get_port = function()
    return 7878
end

function Client:new(udp_path)
    local path = package.path
    local cpath = package.cpath 

    if os == 'windows' then
        package.cpath = udp_path.."\\?.dll;"..package.cpath
        package.path = udp_path.."\\?.lua;"..package.path:gsub(".dll", '.lua')
    else
        package.cpath = udp_path.."/?.so;"..package.cpath
        package.path = udp_path.."/?.lua;"..package.path
    end

    local socket = require('socket.socket')

    package.path = path
    package.cpath = cpath

    local newObj = {
        address = "127.0.0.1",
        udp = socket.udp(),
        socket = socket
    }
    self.__index = self
    return setmetatable(newObj, self)
end

function Client:connected() 
    return self.port == Client.get_port()
end

function Client:connect()
    if self:connected() then
        return true
    end
    local port = Client.get_port()
    local success, err = self.udp:setpeername(self.address, port)
    if success then
        self.port = port
    else
        print('connect err '..err)
    end
    return success ~= nil
end

function Client:send(msg)
    return self.udp:send(msg)
end

return Client
