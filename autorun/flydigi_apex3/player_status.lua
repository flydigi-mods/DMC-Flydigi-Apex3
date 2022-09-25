local utils = require('utils')
local c = require('cache')
local setting = require("setting")

local m = {
    Nero = {
        weapon = "<currentWeaponType>k__BackingField",
        wire = "<currentWireType>k__BackingField",
        wire_action = "<wireActionType>k__BackingField",
        exceed_level = "get_exceedLevel",
        is_devil = 'get_isDevil'
    },
    Dante = {
        weapon_s = "<currentWeaponS>k__BackingField", -- app.PlayerDante.WeaponS
        weapon_l = "<currentWeaponL>k__BackingField",  -- app.PlayerDante.WeaponL
        current_style = '<currentStyle>k__BackingField', -- app.PlayerDante.StyleType
        is_devil = 'get_isUseDevilTriggerDamageRate',
        active_action = 'get_activeAction'
    },
    V = {
        is_devil = "get_isDevilTrigger"
    },
    VergilPL = {
        is_doppel = "IsDoppel", -- bool
        concent_gauge = '<concentGauge>k__BackingField',
        concent_lv = 'get_concentLv',
        weapon_s = "<currentWeaponS>k__BackingField", -- app.PlayerVergilPL.WeaponS
        doppel = '<DoppelMode>k__BackingField',
        v_mode = 'get_isSummonGilver',
        is_devil = "get_isTheDevilTrigger",
        devil_gauge_status = "<theDevilGaugeStatus>k__BackingField" -- app.PlayerVergilPL.TheDevilGaugeStatus
    }
}

-- for k, _ in pairs(m) do
--     local ty = sdk.find_type_definition(sdk.game_namespace("Player"..k))
--     utils.dump_type_fields(ty, false, true)
--     utils.dump_type_methods(ty, false, 0, true)
-- end

local enumCache = {}

local function parse_enum(type, value)
    local s = type:get_full_name()
    local map = enumCache[s]
    if map == nil then
        map = {}
        local fields = type:get_fields()
        for _, f in ipairs(fields) do
            if f:is_static() then
                map[f:get_data(nil)] = f:get_name()
            end
        end
        enumCache[s] = map
    end
    return map[value]
end

local function generate_status_func(t, name)
    local field = t:get_field(name)
    if type(field) == 'userdata' then
        local t = field:get_type()
        if t:is_a("System.Enum") then
            return function(player) 
                return parse_enum(t, player:get_field(name))
            end 
        end
        return function(player) return player:get_field(name) end
    end
    local method = t:get_method(name)
    if type(method) == 'userdata' then
        local t = method:get_return_type()
        if t:is_a("System.Enum") then
            return function(player)
                return parse_enum(t, player:call(name))
            end
        end
        return function(player) return player:call(name) end
    end
    return nil
end

local charge_fields = {} -- app.ChargeChecker

local function fill_changer_fields(name, player, data)
    local charges = charge_fields[name]
    if charges == nil then
        charges = {}
        for _, f in ipairs(player:get_type_definition():get_fields()) do
            if not f:is_static() and f:get_type():get_full_name() == "app.ChargeChecker" then
                table.insert(charges, f:get_name())
            end
        end
        charge_fields[name] = charges
    end
    for _, k in ipairs(charges) do
        local c = player:get_field(k)
        if c ~= nil then
            local key = k
            key = utils.trim_suffix(utils.trim_suffix(utils.trim_prefix(key, "<"), ">k__BackingField"), "Checker")
            data[key.."State"] = c:call('get_state')
            data[key.."Level"] = c:call('get_chargeLevel')
        end
    end
end

m.get_player_status = function(name, player)
    local s = m[name]
    if setting.debug_console_enable and setting.debug_console_ip ~= "" then
        s = {}
        local fields = utils.dump_type_fields(player:get_type_definition(), false, true)
        local methods = utils.dump_type_methods(player:get_type_definition(), false, 0, true)
        for _, f in ipairs(fields) do
            if f ~= "CurrentThinkAction" and not utils.end_with(f, "Timer>k__BackingField") and not utils.end_with(f, "Timer") and not utils.start_with(f, "offset") and not utils.start_with(f, "<offset") and not utils.end_with(f, "Frame") and not utils.start_with(f, "<concentGauge>") and f ~= 'ImageInterval' then
                s[f] = f
            end
        end
        for _, m in ipairs(methods) do 
        if utils.start_with(m, "get_") and not utils.end_with(m, "Timer") and not utils.end_with(m, "AngleH") and not utils.end_with(m, "AngleV") and not utils.start_with(m, "get_axis") and m ~= "get_checkPosition" and not utils.start_with(m, "get_offset") and m ~= 'get_concentGauge' then
                s[m] = m
            end
        end
    end
    local d = {}
    for k, v in pairs(s) do 
        if type(v) == 'string' then
            v = generate_status_func(player:get_type_definition(), v)
            if v ~= nil then
                s[k] = v
            end
        end
        if v ~= nil then
            local r, e = pcall(v, player)
            if r then
                d[k] = e
            else
                print("error to call "..k.." "..tostring(e))
            end
        end
    end
    fill_changer_fields(name, player, d)
    -- for k, v in pairs(c.player_status_methods) do
    --     d[k] = player:call(v:get_name())
    -- end
    return d
end

return m