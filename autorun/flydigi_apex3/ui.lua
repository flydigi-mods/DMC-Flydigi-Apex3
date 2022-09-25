local setting = require("setting")
local version = require("version")
local Packet = require("udp_client")
local utils = require('utils')
local BasePlayer = require("base_player")
local Instruction = Packet.Instruction

local default_lock_pos_min = 50
local default_lock_pos_max = 150

local begin_test_udp_time = 0
local test_udp_secs = 5
local test_udp_result = false

local left_trigger_code = 512
local right_trigger_code = 2048

local packet

local about = "made by @songchenwen"

local function current_timestamp()
    return os.time(os.date("!*t"))
end

local function is_testing_udp()
    return current_timestamp() - begin_test_udp_time <= test_udp_secs
end

local function test_udp()
    begin_test_udp_time = current_timestamp()
    local vib = Instruction:new():Vib():VibForceMax():VibFreq(40):BeginTop():ForceMin()
    local p = Packet:new(vib, vib:clone())
    if p:send() then
        packet = p
        return true
    end
    return false
end

local function reset_controller()
    if packet == nil then return end
    local r = Packet:new(Instruction.left_default(), Instruction.right_default())
    if packet:delta(r):is_nil() then
        packet = nil
    else
        if r:send() then packet = nil end
    end
end

local function controller_default_changed()
    Packet.set_default(
        Instruction:new():Resistant():ForceMax():Begin(setting.left_default_lock_pos),
        Instruction:new():Resistant():ForceMax():Begin(setting.right_default_lock_pos)
    )
    Packet.get_default():send()
end

local function reload_weapon_configs()
    BasePlayer.reload_configs()
end

re.on_frame(function()
    if packet == nil then return end
    if not is_testing_udp() then reset_controller() end
end)

re.on_draw_ui(function() 
    if imgui.tree_node("Flydigi Apex3") then
        _, setting.enable = imgui.checkbox("Enable Apex3 Adaptive Trigger", setting.enable)
        left_default_changed, setting.left_default_lock_pos = imgui.slider_int("Left Trigger Default Lock Position", setting.left_default_lock_pos, default_lock_pos_min, default_lock_pos_max)
        right_default_changed, setting.right_default_lock_pos = imgui.slider_int("Right Trigger Default Lock Position", setting.right_default_lock_pos, default_lock_pos_min, default_lock_pos_max)
        if left_default_changed or right_default_changed then
            controller_default_changed()
        end
        local port_changed, port = imgui.input_text("Flydigi Space Port", tostring(setting.udp_port))
        if port_changed then
            port = tonumber(port)
            if port ~= nil then 
                if port >= 1024 and port <= 65535 then
                    setting.udp_port = port 
                end
            end
        end
        local reset_default = imgui.button("Reset Default")
        if reset_default then setting.reset_default() end
        local reload_w = imgui.button("Reload Weapon Configs")
        if reload_w then reload_weapon_configs() end
        if version then
            imgui.text("Version: "..version)
        end
        imgui.text(about)
        if imgui.tree_node("Debug") then
            if is_testing_udp() then
                if test_udp_result then
                    imgui.text("Push Trigger, It Should Vibrate")
                else
                    imgui.text("Connect Flydigi Space Failed")
                end
            else
                local send_udp = imgui.button("Test Connection")
                if send_udp then
                    test_udp_result = test_udp()
                end
            end
            _, setting.debug_window = imgui.checkbox("Open Debug Window", setting.debug_window)
            _, setting.debug_console_enable = imgui.checkbox("Enable Debug Console", setting.debug_console_enable)
            _, setting.debug_console_ip = imgui.input_text("Debug Console IP", setting.debug_console_ip)
            _, setting.debug_console_port = imgui.input_text("Debug Console Port", setting.debug_console_port)
        end
        imgui.tree_pop();
    end
end)
