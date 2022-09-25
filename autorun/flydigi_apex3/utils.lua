local utils = {}


local PlayerManager
local InputManager
local ChatManager
local GamePad 

utils.os = 'unix'
if package.config:sub(1,1) == '\\' then
    utils.os = 'windows'
end

local rt_code = 2048
local lt_code = 512

utils.buttons_from_value = {} 
utils.buttons_to_value = {}
local button_type = sdk.find_type_definition('via.hid.GamePadButton')
for _, f in ipairs(button_type:get_fields()) do
    if f:is_static() and f:get_name() ~= "All" and f:get_name() ~= "None" then
        utils.buttons_from_value[f:get_data()] = f:get_name()
        utils.buttons_to_value[f:get_name()] = f:get_data()
    end
end

utils.actions_from_value = {}
utils.actions_to_value = {}
local action_type = sdk.find_type_definition('app.PadInput.GameAction')
for _, f in ipairs(button_type:get_fields()) do
    if f:is_static() and f:get_name() ~= "All" and f:get_name() ~= "None" then
        utils.actions_from_value[f:get_data()] = f:get_name()
        utils.actions_to_value[f:get_name()] = f:get_data()
    end
end


function utils.get_pad_button()
    if not GamePad then
        local p = sdk.get_managed_singleton("app.PadManager")
        if p then
            GamePad = p:call("get_padInput")
        end
    end
    if not GamePad then
        print("cannot get GamepadApp")
        return {}
    end
    for b, v in pairs(utils.buttons_to_value) do
        if GamePad:call("isButtonOn", v) then
            print("button on "..b..", "..v)
        end
    end
    return {}
end

function is_trigger_down(code)
    local pad_on = utils.get_pad_button()
    return pad_on & code ~= 0
end

function utils.is_rt_down()
    return is_trigger_down(rt_code)
end

function utils.is_lt_down()
    return is_trigger_down(lt_code)
end

function utils.end_with(str, ending)
    return ending == "" or str:sub(-#ending) == ending
end

function utils.start_with(str, prefix)
    return prefix == "" or str:sub(0, #prefix) == prefix
end

function utils.trim_prefix(str, prefix)
    if utils.start_with(str, prefix) then
        return str:sub(#prefix + 1)
    end
    return str
end

function utils.trim_suffix(str, suffix)
    if utils.end_with(str, suffix) then
        return str:sub(0, -#suffix - 1)
    end
    return str
end

function utils.deepcompare(t1,t2,ignore_mt)
    local ty1 = type(t1)
    local ty2 = type(t2)
    if ty1 ~= ty2 then return false end
    -- non-table types can be directly compared
    if ty1 ~= 'table' and ty2 ~= 'table' then return t1 == t2 end
    -- as well as tables which have the metamethod __eq
    local mt = getmetatable(t1)
    if not ignore_mt and mt and mt.__eq then return t1 == t2 end
    for k1,v1 in pairs(t1) do
    local v2 = t2[k1]
    if v2 == nil or not utils.deepcompare(v1,v2) then return false end
    end
    for k2,v2 in pairs(t2) do
    local v1 = t1[k2]
    if v1 == nil or not utils.deepcompare(v1,v2) then return false end
    end
    return true
end

function utils.all_fields_for_type(t)
    local fields = t:get_fields()
    local pt = t:get_parent_type()
    if pt ~= nil then
        local pfs = utils.all_fields_for_type(pt)
        for _, f in ipairs(pfs) do
            table.insert(fields, f)
        end
    end
    return fields
end

function utils.dump_obj_fields(obj)
    if not sdk.is_managed_object(obj) then
        return
    end
    local d = {}
    local t = obj:get_type_definition()
    utils.dump_type_fields(t)
end

function utils.dump_type_fields(t, only_static, only_value_type)
    print("----------------------------type fields dump "..t:get_full_name())
    local fields = t:get_fields()
    local names = {}
    for _, f in ipairs(fields) do
        local static = f:is_static()
        local ty = f:get_type()
        if only_static == nil or only_static == static then
            if not only_value_type or ty:is_value_type() then
                table.insert(names, f:get_name())
                print(f:get_name()..", "..tostring(static)..", "..ty:get_full_name())
            end
        end
    end
    print("----------------------------end type fields dump "..t:get_full_name())
    return names
end

function utils.dump_type_methods(t, only_static, only_param_count, only_value_type)
    print("----------------------------type methods dump "..t:get_full_name())
    local methods = t:get_methods()
    local names = {}
    for _, m in ipairs(methods) do
        local is_static = m:is_static()
        local return_type = m:get_return_type()
        local param_count = m:get_num_params()
        if only_static == nil or only_static == is_static then
            if not only_param_count or param_count <= only_param_count then
                if not only_value_type or return_type:is_value_type() then
                    table.insert(names, m:get_name())
                    print(m:get_name()..", "..tostring(is_static)..", "..return_type:get_full_name()..", "..param_count)
                end
            end
        end
    end
    print("----------------------------end type methods dump "..t:get_full_name())
    return names
end

function utils.dump_obj(obj, filepath)
    if not sdk.is_managed_object(obj) then
        return
    end
    local d = {}
    local t = obj:get_type_definition()
    local fields = utils.all_fields_for_type(t)
    for _, f in ipairs(fields) do
        local name = f:get_name()
        local is_static = f:is_static()
        d[name] = {
            is_static = is_static,
            type = f:get_type():get_full_name()
        }
        local value
        if is_static then
            value = f:get_data(nil)
        else
            value = f:get_data(obj)
        end
        if value ~= nil and type(value) == "userdata" then
            if not sdk.is_managed_object(value) then
                value = sdk.to_managed_object(value)
            end
            if value ~= nil then
                value = utils.dump_obj(value)
            end
        end
        d[name]['value'] = value
    end
    if filepath == nil then
        print(json.dump_string(d, 2))
    else
        json.dump_file(filepath, d, 4)
    end
    return d
end

function utils.getEnumMap(enumTypeName)
    local typeDef = sdk.find_type_definition(enumTypeName)
    if not typeDef then return {} end

    local fields = typeDef:get_fields()
    local map = {}

    for i, field in ipairs(fields) do
        if field:is_static() then
            local name = field:get_name()
            local key = field:get_data(nil)
            map[key] = name
        end
    end
    return map
end

function utils.get_manager(args) 
    return sdk.to_managed_object(args[2]) 
end

return utils
