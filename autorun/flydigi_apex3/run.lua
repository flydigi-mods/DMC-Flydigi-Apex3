local utils = require('utils')
local c = require('cache')
local setting = require('setting')
local BasePlayer = require('base_player')
local PlayerStatus = require('player_status')
local BaseState = require('base_state')
local json = require('json')
local Config = require('udp_client')
local Instruction = Config.Instruction

local udp_path = "./flydigi_apex3/udp_client"
if utils.os == 'windows' then
    udp_path = string.match(package.path, "(.-)([^\\/]-)?.lua;"):gsub("lua\\$", "").."\\udp_client"
end
Config.setup(udp_path, json.encode, 
Instruction.new_left():Resistant():ForceMax():Begin(setting.left_default_lock_pos):AdaptOutputData(true),
Instruction.new_right():Resistant():ForceMax():Begin(setting.right_default_lock_pos):AdaptOutputData(true),
function() return setting.udp_port end
)
Config.current = Config.get_default()
Config.current:send()

local playerName
local currentPlayer
local action = nil

local function update_controller_config(new_config)
    Config.current:change(new_config)
end

local function reset_default_controller_config()
    Config.current:change(Config.get_default())
end

reset_default_controller_config()

local function getPlayerName(player)
    local t = player:get_type_definition():get_name()
    return utils.trim_prefix(t, "Player")
end

-- utils.dump_type_fields(sdk.find_type_definition('app.PlayerVergilPL')) -- PlayerV, PlayerVergilPL

local function onUpdate(player)
    local config = currentPlayer:update_controller_config(action, player)
    if config then
        update_controller_config(config)
    end
end

sdk.hook(c.player_set_action_method, function(args)
    local player = utils.get_manager(args)
    if not c.player_is_master_method:call(player) then
        return
    end
    local name = getPlayerName(player)
    if playerName ~= name then
        if currentPlayer ~= nil then
            currentPlayer.current_state = BaseState:new()
        end
        reset_default_controller_config()
        currentPlayer = BasePlayer.get_player(name)
        playerName = name
    end
    local action_name = sdk.to_managed_object(args[3]):call("ToString")
    if action_name == nil or action_name == 'None' then
        return
    end
    if action_name ~= action then
        action = action_name
        onUpdate(player)
    end
end, function(retval) return retval end)

sdk.hook(c.player_do_update_method, function(args)
    local player = utils.get_manager(args)
    if not c.player_is_master_method:call(player) then
        return
    end
    local name = getPlayerName(player)
    if playerName ~= name then
        if currentPlayer ~= nil then
            currentPlayer.current_state = BaseState:new()
        end
        reset_default_controller_config()
        currentPlayer = BasePlayer.get_player(name)
        playerName = name
    end
    onUpdate(player)
end, function(retval) return retval end)


local font = nil
if d2d then
    d2d.register(function()
        font = d2d.Font.new("Arial", setting.font_size)
    end, function()
        if not setting.debug_window then return end
        if not font then return end
        if currentPlayer == nil then return end
        local str = currentPlayer.name
        if not currentPlayer.current_state:is_nil() then 
            str = str..'\n'..currentPlayer.current_state:display_str()
        end 
        if Config.current then
            local left = Config.current.left
            local right = Config.current.right
            if left ~= nil and not left:is_nil() then
                str = str.."\nLT: "..left.mode.." "..left.param1.." "..left.param2.." "..left.param3.." "..left.param4
            end
            if right ~= nil and not right:is_nil() then
                str = str.."\nRT: "..right.mode.." "..right.param1.." "..right.param2.." "..right.param3.." "..right.param4
            end
        end
        if str == "" then
            return
        end
        local w, h = font:measure(str)
        local screen_w, screen_h = d2d.surface_size()
        local margin = 40
        local padding = 2
        d2d.fill_rect(margin, screen_h - margin - h - padding * 2, w + padding * 2, h + padding * 2, 0x77000000)
        d2d.text(font, str, margin + padding, screen_h - margin - padding - h, 0x99FFFFFF)
    end)
end

re.on_frame(function()
    if Config.current ~= nil then
        Config.current:tick() 
    end
    if d2d and font then return end
    if setting.debug_window then
        if currentPlayer == nil then return end
        local str = currentPlayer.name
        if not currentPlayer.current_state:is_nil() then 
            str = str..'\n'..currentPlayer.current_state:display_str()
        end 
        if Config.current then
            local left = Config.current.left
            local right = Config.current.right
            if left ~= nil and not left:is_nil() then
                str = str.."\nLT: "..left.mode.." "..left.param1.." "..left.param2.." "..left.param3.." "..left.param4
            end
            if right ~= nil and not right:is_nil() then
                str = str.."\nRT: "..right.mode.." "..right.param1.." "..right.param2.." "..right.param3.." "..right.param4
            end
        end
        if str == "" then
            return
        end
        if imgui.begin_window("Flydigi Apex3 Debug", true, 64) then
            imgui.text(str)
            imgui.end_window()
        else
            setting.debug_window = false
        end
    end
end)

require("ui")
