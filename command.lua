local GitCommandGen = function(command)
    return "git --git-dir=$HOME/bot/.git --work-tree=$HOME/bot " .. command
end

local command = {
    version         = {
        execute = function(source)
            local Read = io.popen(GitCommandGen("rev-parse HEAD"), "r")
            local Version = Read:read("a*")
            Read:close()
            host.say(source, "现在版本为: " .. Version)
        end
    }
}

return command
