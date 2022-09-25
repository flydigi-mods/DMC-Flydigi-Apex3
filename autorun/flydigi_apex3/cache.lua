local c = {}

c.player_type = sdk.find_type_definition(sdk.game_namespace("Player"))
c.player_set_action_method = c.player_type:get_method("setAction")
c.player_do_update_method = c.player_type:get_method("doUpdate")
c.player_is_master_method = c.player_type:get_method("get_isMasterManualPlayer")

c.player_status_method_names = {"Wait", "Walk", "Jog", "Move", "Run", "Dash"}

c.player_status_methods = {}

for _, n in ipairs(c.player_status_method_names) do
    c.player_status_methods[n] = c.player_type:get_method("get_is"..n)
end

return c
