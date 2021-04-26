local r_who = io.popen "whoami"
local who   = r_who:read()

r_who:close()

Context =   Context or {}
Context.deploy_path =   "/home/"..who.."/littlebot/"

local deploy_exists = io.open(Context.deploy_path .. "deploy.sh", "r")

if not deploy_exists then
    -- write one update sh into it
    --
    deploy_exists = io.open(Context.deploy_path .. "deploy.sh", "w")
    local cmd   =   [[
#!/bin/sh
git --git-dir=#{deploy_path}/.git --work-tree=#{deploy_path} pull
    ]]

    deploy_exists:write((cmd:gsub("#{([^}]*)}", Context)))
end
