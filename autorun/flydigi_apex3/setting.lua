local file_path = "flydigi_apex3/setting.json"
local fields_not_to_save = { reset_default = true, debug_console_enable = true, debug_window = true}
local default_udp_port = 7878

local default_setting = {
    enable = true, 
    debug_window = false, 
    left_default_lock_pos = 100, 
    right_default_lock_pos = 100,
    font_size = 14,
    udp_port = default_udp_port,
    debug_console_ip = '', 
    debug_console_port = 5000,
    debug_console_enable = false
}

local setting = json.load_file(file_path)

local function apply_default()
    if not setting then setting = {} end
    for k, v in pairs(default_setting) do 
        if setting[k] == nil then
            setting[k] = v
        end
    end
end

apply_default()

setting.reset_default = function()
    for k, v in pairs(default_setting) do
        setting[k] = v
    end
end

print("flydigi setting init")

re.on_config_save(function()
    local data = {}
    for k, v in pairs(setting) do
        if not fields_not_to_save[k] then
            if default_setting[k] ~= v then
                data[k] = v
            end
        end
    end
    json.dump_file(file_path, data, 4)
end)

return setting
