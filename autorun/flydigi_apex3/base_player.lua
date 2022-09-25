local BasePlayer = {}
local utils = require('utils')
local setting = require('setting')
local c = require('cache')
local BaseState = require("base_state")
local PlayerStatus = require("player_status")
local Config = require("config")
local Packet = require("udp_client")
local Instruction = Packet.Instruction
local debug_console = nil 

function BasePlayer:handle_debug_console(changed, new_state)
    if not changed then return end
    if not setting.debug_console_enable or setting.debug_console_ip == "" then return end
    if debug_console == nil then
        local socket = Packet.client.socket
        debug_console = socket.udp()
        debug_console:setpeername(setting.debug_console_ip, setting.debug_console_port)
    end
    local str = ""
    for k, _ in pairs(changed) do
        str = str..k.." = "..tostring(new_state[k])..", "
    end
    debug_console:send(str)
end


function BasePlayer:update_controller_config(action, player)
    local extra = PlayerStatus.get_player_status(self.name, player)
    local new_state = BaseState:new(action, extra)
    if self.current_state == nil or self.current_state:is_nil() then
        self.current_state = new_state
        return false
    end
    local changed = self.current_state:changed(new_state)
    if not changed then return false end
    self:handle_debug_console(changed, new_state)
    local packet = nil
    for _, c in ipairs(self.configs) do 
        if type(c.func) == "function" then
            local ok, n = pcall(c.func, self.current_state, new_state, changed)
            if ok then
                if n ~= nil then 
                    print(tostring(new_state.action).." from "..c.name)
                    packet = n
                    break
                end
            else
                print("run error "..c.name.." "..n)
            end
        elseif type(c) == 'table' then
            local n = c:get_packet(self.current_state, new_state, changed)
            if n ~= nil then 
                packet = n
                break
            end
        end
    end
    if not packet then
        packet = Packet.get_default()
    end
    self.current_state = new_state
    return packet
end

local function load_configs(name)
    local path_prefix = "flydigi_apex3/players/"
    local configs = {}
    for _, p in ipairs({name..".json", name..".default.json"}) do
        local path = path_prefix..p
        if utils.end_with(p, '.lua') then
            local s = fs.read(path)
            if s ~= nil then
                local func, err = load(s, p, 'bt', {Packet = Packet, Instruction = Instruction, utils=utils, log=log})
                if func then
                    local ok, func = pcall(func)
                    if ok then
                        table.insert(configs, {name=p, func=func})
                    end
                end
            end
        end
        if utils.end_with(p, '.json') then
            local c = Config.load_file(path, p)
            if c ~= nil then
                table.insert(configs, c)
            end
        end
    end
    print("loaded "..tostring(#configs).." configs for "..name)
    return configs
end

function BasePlayer:new(player_name)
    local newObj = {
        name = player_name,
    }
    newObj['current_state'] = BaseState:new()          
    newObj.configs = load_configs(player_name)
    for _, c in ipairs(BasePlayer.default_configs) do
        table.insert(newObj.configs, c)
    end
    self.__index = self
    return setmetatable(newObj, self)
end

function BasePlayer:reload_configs()
    if self == nil then
        BasePlayer.load_default_configs()
        for _, p in pairs(BasePlayer.players) do
            p:reload_configs()
        end
    else
        self.configs = load_configs(self.name)
        for _, c in ipairs(BasePlayer.default_configs) do
            table.insert(self.configs, c)
        end
    end
end

BasePlayer.default_configs = {}

function BasePlayer.load_default_configs()
    BasePlayer.default_configs = load_configs('default')
end

BasePlayer.load_default_configs()

BasePlayer.players = {}

function BasePlayer.get_player(name)
    local w = BasePlayer.players[name]
    if w == nil then
        w = BasePlayer:new(name)
        BasePlayer.players[name] = w
    end
    return w
end

return BasePlayer
