local mod_name = "flydigi_apex3"
print('run '..mod_name)
local p =  string.match(package.path, "(.-)([^\\/]-)?.lua;"):gsub("lua\\$", "").."reframework\\autorun\\"..mod_name
package.path = p.."\\?.lua;"..p.."\\?\\init.lua;"..package.path
require("run")
