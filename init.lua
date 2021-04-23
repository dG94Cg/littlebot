-- design for inject host, require HOST [weechat/hexchat]
-- suggest use weechat for complete support



local weechat = weechat
local hexchat = hexchat
local Message = require "bot.message"

PluginName = "bot"
Host = hexchat or {}

Host.msg_listen = {}
Host.hook = {}

SERVER = "freenode"

Sandbox = require "bot.sandbox"
Storage = require "bot.storage"
Command = require "bot.command"
Log = require "bot.log"
Xmpp = require "bot.xmpp"
Version = "0.5.1"

-- command plugin import here
require "bot.last"
require "bot.query"

Http_match = "(https?://[%w./%d%&%=%?_+-]*)"

-- not support manual controll input now
function log_input()

end
function log_close()

end
-- weechat compatible layer
local log_buff -- design for weechat use
if weechat then
    -- register plugin
    Host.register = function()
        weechat.register("LittleBot", "Littleme", Version, "MIT", "A Irc Bot Writen on Lua for Weechat", "", "")
        weechat.hook_config("plugins.var.lua." .. PluginName .. ".*", "reload","")
    end
    -- weechat require plugin register first
    if not BOT_REG then
        pcall(Host.register,"bot", Version, "Bot on lua with sandbox")
        BOT_REG = {}
    end
    -- create one buffer for log display
    log_buff  = weechat.buffer_new("LittleBotLog","log_input","","log_close","");
    table.insert(Log.handler, function(level, record)
      weechat.print(log_buff, ("%s [%s] (%s:%s) %s"):format(record.date, level, (record.line or {})[1] or "",(record.line or {})[2] or "", record.log))
    end)

    -- log file output
    -- @TODO fix the broken log file output
    local PWD = os.getenv("PWD")
    table.insert(Log.handler, Log.file_handler(PWD .. "/irc_bot.%d.log",function(path)
      return path:format(os.date("%y-%m-%d")) end))

    -- command for controll irc raw command
    -- @see Host.say it depends command
    Host.command = function(command_str, source)
        Log.trace("execute RAW Command " .. command_str)
        local buff = source and (source.server .. "," .. source.target)
                        or ""
        Log.debug("[NICK] buff: " .. buff .. " Command: ".. command_str)
        weechat.command(buff or "", command_str)
    end
    -- hook print, invoke the hook when message came, bot design for hexchat first
    -- so we got hook_print here not hook_signal here
    Host.hook_print = function(hook_type, hook)
        Log.trace("Hook [%s] hook [%s]", hook_type, hook)
        return {
            hook = weechat.hook_signal("*,irc_in2_*", "host_global_msg_hook", ""),
            unhook = function(self)
                weechat.unhook(self.hook)
            end
        }
    end
    -- exists reason same as hook_print, weechat contain no hook_upload
    Host.hook_unload = function(hook)
        Log.trace("Weechat support no hook_unload for [%s]", hook)
    end
    -- take nick from weechat to get info
    -- not support by hexchat
    Host.get_info = function(source, info_type)
        Log.trace("Weechat get_info source[%s] info_type[%s]", source, info_type)
        local NICK = weechat.info_get("irc_nick", source.server)
        Log.trace( "nick: " .. NICK .. " server:" .. (source.server or "nil"))
        return NICK
    end

    -- default say command for easy out put
    -- if privchat buffer exists, change the source target into the nickname for buffer(privchat)
    -- @source contain the server and channel and reply target info
    -- @msg message should send
    -- @option decide it's send to channel public or add one nickname as prefix
    Host.say = function(source, msg, option)
        local CHANNEL = option and option.channel
        local BUFFER_NAME = source.server ..","..source.target
        Log.trace( "SAY to channel [" .. BUFFER_NAME .. "]")
        --weechat.print(log_buff, "info_get BUFFER_NAME : "..BUFFER_NAME.." => " .. weechat.info_get("irc_buffer",BUFFER_NAME))
        weechat.command(weechat.info_get("irc_buffer",BUFFER_NAME),
        "/say " .. (not CHANNEL and (source[1] .. ": " .. msg) or msg))
    end
end

-- hexchat layer
if hexchat then
    -- say method
    Host.say = function(source, msg, option)
        if option and option.channel then
            Host.command("say " .. msg)
        else
            Host.command("say " .. source[1] .. ": " .. msg)
        end
    end
    -- not support by hexchat, so just give it out
    -- @TODO complete the real function
    Host.get_info = function(source, info_type)
        return "LittleBot"
    end
end

-- BOT Context
Context = {
    admin   =   {
            "littleme"
        ,   "littleme_"
    }
,   deploy_path =   "/home/git/bot/"
,   auth    =   function(name)
        for _, v in ipairs(Context.admin) do
            if  v == name then
                return true
            end
        end
        return false
    end
}

-- Hook list, not useful here
Host.hook_list = {}

-- check if list contain the value
Util = {
    contain = function(list, value)
        for _,v in pairs(list) do
            if v == value then
                return true
            end
        end
    end
}

-- mute add for the bot
-- protect bot from flood speak so that bot won't get banned from server
do
    local say_action = Host.say
    local mute = false
    Command.mute = {
        execute = function(msg)
            if not mute then
                say_action(msg, Message.muted)
            end
            mute = not mute
            if not mute then
                say_action(msg, Message.unmuted)
            end
        end
    }
    Host.say = function(source, msg, option)
        if mute then return end
        local mem = Storage.take "say"
        if not mem.last_say then
            mem.last_say = {
                at = os.time()
            }
        end
        if os.time() - mem.last_say.at < 60 then
            mem.last_say.count = (mem.last_say.count or 0) + 1
        else
            mem.last_say.count = 0
            mem.last_say.at = os.time()
        end
        if mem.last_say.count > 10 then
            say_action(msg, Message.auto_muted)
            mute = true
            return
        end
        local auth = Context.auth(source[1])
        if not auth then
            if mem[source[1]] and os.time() - mem[source[1]].last <= 15 then
                if mem[source[1]].warn and os.time() - mem[source[1]].warn <= 15 then
                    return
                end
                say_action(source, Message.ignore)
                mem[source[1]].warn = os.time()
                return
            end
        end
        if not mem[source[1]] then mem[source[1]] = {} end
        mem[source[1]].last = os.time()
        say_action(source, msg, option)
    end
end

-- ## INTI COMMAND ##



-- @aim execute the update code, for git situation
Command.update = {
  execute = function(msg)
      if not Context.auth(msg[1]) then
          Host.say(msg, Message.not_allow)
          return
      end
      Host.say(msg, Message.uploading)
      local res,data = os.execute("sh " .. Context.deploy_path .. "deploy.sh 1>> /dev/null 2>> /dev/null")
      if not res then
          Host.say(msg, Message.deploy_fail)
      else
          pcall(Command.version, data)
      end
      Host.reload()
  end
}

-- @aim lua, execute code at sandbox
Command.lua = {
    execute = function(msg)
       Sandbox.run(msg[2]:sub(5,msg[2]:len()), Context.init(msg))
    end
}

-- @aim tell if user is authed
Command.auth = {
    execute = function(msg)
        if Context.auth(msg[1]) then
            Host.say(msg, Message.auth_pass)
        else
            Host.say(msg, Message.auth_fail)
        end
    end
}

-- @aim rename
Command.rename = {
    execute = function (msg)
        if Context.auth(msg[1]) then
            Host.command("/nick " .. msg[2]:match("rename ([^ ]*)"), msg)
            Log.trace("execute nick " .. msg[2]:match("rename ([^ ]*)"))
        else
            Host.say(msg, Message.not_allow)
        end
    end
}

-- @aim reload the code
-- @warn bot will crash if code load error
Command.reload = {
    execute = function(msg)
       local auth = msg[1]:match("littleme_*") or  (math.random(1,10) == 1)
       if auth then
           Host.reload()
           Host.say(msg," reload at " .. os.date(),{channel = true})
       else
           Host.say(msg, Message.not_allow2)
       end
    end
}

-- @deprecate 
-- @aim print the help
Command.help = {
    execute = function(msg)
        local help = Message.help
        local buff = {help}
        for _, com in pairs(Command) do
            if type(com) == "table" and type(com.help) == "string" then
                buff[#buff+1] = com.help
            end
        end
        help = table.concat(buff,"; "):fill(_G)
        Host.say(msg, "msg "..msg[1].." "..help)
    end
}

-- @aim like echo, just say it
Command.say = {
    execute = function(msg)
        Host.say(msg, msg[2]:sub(6, msg[2]:len()))
    end,
    help = Message.say_help
}

-- @aim mark one user with one meta
Command.sm = {
    execute = function(msg)
        local rom = Storage.take "sm"
        local _, Name, Meta = Command.sm.takeMeta(msg[2])
        rom[Name] = rom[Name] or {}
        local sm = rom[Name]
        if Meta then
            Log.debug("Command :sm [Name => " .. Name .. "] [Meta => " .. Meta .."]")
            if not Util.contain(sm, Meta) then
                table.insert(sm, 1, Meta)
                rom:flush()
                Host.say(msg, "Pushed! ~^_^~")
            else
                Host.say(msg, Message.sm_dupl)
            end
        else
            Meta = sm[math.random(math.max(#sm,1))] or Message.sm_lost
            Log.debug("Command :sm tell [Name => " .. Name .. "] [Meta => " .. Meta .."]")
            Host.say(msg, Meta)
        end
    end,
    help = Message.sm_help,
    takeMeta = function(msg)
        local Com, Name, Meta = msg:match("(:sm%.?%d*) *([^ ]*) *(.*)$")
        if not Com then
            return msg:match("(:sm%.?%d*) *([^ ]*) *$")
        end
        if Meta then
            Meta = Meta:match("([^ ].*) *$")
        end
        if Meta then Meta = Meta:sub(0,50) end
        return Com, Name, Meta
    end
}

-- replace string that wrap by {name} with env[name]
string.fill = function(str, env)
    env = env and env or _G
    return str:gsub("{([^}]*)}", env)
end

-- parse the rawdata
-- @note    require msg_head
local parse_rawdata = require "bot.msg_head".parse

-- msg callback, invoke by host when message came
host_global_msg_hook = function(signal, command, signal_data)
    Log.trace(("receive signal[%s] command[%s] data[%s]"):format(signal, command, signal_data))
    -- parse the raw data into msg
    local msg       =   parse_rawdata(signal, command, signal_data)

    -- skip for weechat receive the PONG
    if weechat and command:match("PONG$") then
        -- no reply for PONG
        return
    end

    -- execute the msg hook chains
    for name, hook in pairs(Host.msg_listen) do
        local _, err_msg = pcall(hook, msg)
        if err_msg then
            Log.error(string.format("[%s] handle msg error [%s]",
                name,
                err_msg))
        end
    end
    -- execute the Context.execute
    if Context then 
        local res, err  =   pcall(Context.execute, msg)
        if not res then
            Log.error("fail to execute command[Nick => %s] error: %s", msg[1], err)
            if weechat then
                weechat.print(log_buff, "ERROR:"..err)
            end
        end
    end
end



-- execute the message hook
-- message hook will be invoke for each message came
local function execute_msg_hook(msg)
    if msg.command and Host.hook[msg.command] then
        if type(Host.hook[msg.commad]) == "function" then
            Host.hook[msg.command](msg)
        elseif type(Host.hook[msg.command]) == "table" then
            for _, fuc in pairs(Host.hook[msg.command]) do
                fuc(msg)
            end
        end
    end
end

-- match Context command and execute it
local function match_execute_command(msg)
    -- reject bot to execute command
    if msg[1]:match("bot") then
        if os.time() % 2 == 1 then
            Log.trace("BOT " .. msg[1] .." command refused")
            Host.command(msg, Message.reject_bot)
        end
        return
    end
    -- match and execute command
    for i,fuc in pairs(Command) do
        if msg[2]:match("^:"..i) then
            local res, err
            if (type(fuc) == "function") then
                res, err = pcall(fuc, msg)
            else
                res, err = pcall(fuc.execute, msg)
            end
            if not res then
                Log.error("User[%s] Fail to Execute[%s] Error: %s", msg[1], i, err)
                -- ugly print when log.error 
                if weechat then
                    weechat.print(log_buff,string.format("User[%s] Fail to Execute[%s] Error: %s", msg[1], i, err))
                end
            end
            return
        end
    end
    -- execute the command.retrieve when no command matched
    if Command.retrieve then
        if (type(Command.retrieve) == "function") then
                Command.retrieve(msg)
            else
                Command.retrieve.execute(msg)
        end
    end
end

-- Context execute
-- add some gc code here
Context.execute = function(msg)
    -- skip if not gain nick name "BOT"
    if not Host.get_info(msg, "nick"):upper():match("BOT") then
        return
    end
    -- GC check
    if collectgarbage("count") > 300000 then
        Host.say(msg,"LittleBot is Executing GC")
        -- for ugly data flsuh, should use the sql or something else
        Host.flush_data()
        collectgarbage()
    end
    -- execute the command if msg exist
    if msg[2] then
        Log.trace("Execute Msg { name = " .. (msg.name or "nil") .. ", msg = " .. msg[2] .. " }")
        local res, err  =   pcall(match_execute_command, msg)
        if  not res then
            Log.error("Fail to Execute Msg { name = " .. (msg.name or "nil") .. ", msg = " .. msg[2] .. " } Error:" .. err)
            if weechat then
                weechat.print(log_buff,"Fail to Execute Msg { name = " .. (msg.name or "nil") .. ", msg = " .. msg[2] .. " } Error:" .. err)
            end
        end
    else
        Log.trace("None Msg Command { name = "..(msg.name or "nil") .. ", command = "..(msg.command or "nil") .. " }")
    end
    -- execute the hook of command
    execute_msg_hook(msg)
end

-- ## Sandbox Part  ##
-- evil sandbox init code
local context_by_nick = {}
Context.init = function(msg)
    -- output buff
    local buff = {}
    -- limit the sandbox out put line
    local limit = 3
    -- context for nickname
    if not context_by_nick[msg[1]] then
        context_by_nick[msg[1]] = {}
    end
    -- protect area and env
    return {
        -- _G is the real env
        _G = context_by_nick[msg[1]],
        -- init method, it'll be invoke automatic
        init = function(_, _G)
            -- use say as print, say it to public
            _G.print = function(x)
                -- limit the say line
                if type(x) ~= "string" and type(x) ~= "number" then
                    x = tostring(x)
                end
                buff[#buff+1] = x
                if #buff < limit then
                    Host.say(msg, x, {channel = true})
                end
                if #buff == limit then
                    Host.say(msg, Message.reject_say)
                end
                if #buff > limit and math.random() < 1-(#buff/#buff+1) then
                    Host.say(msg, Message.leak_say .. x)
                end
            end
            -- say => irc say, real say, reply to inovker
            _G.say = function(word)
                -- @warn it may reach the code invoke limit turn
                _G.print(msg[1]..": "..word)
            end
        end,
        -- info that will be invoke as code finally step
        info = function(x)
            Host.say(msg, x)
        end,
        -- error info, invoke by error handler
        error = function(x)
            Host.say(msg, x)
        end
}
end

-- reload bot and deps
Host.reload = function()
    Host.flush_data()
    for _,hook in pairs(Host.hook_list) do
        hook:unhook()
    end
    Host.hook_list = {}
    -- @FIXME add some manual controll package
    package.loaded.bot = nil
    local loaded = {}
    for name,_ in pairs(package.loaded) do
        if type(name) == "string" and name:match("^bot") then
            -- record the package
            loaded[name] = true
            -- unload
            package.loaded[name] = nil
        end
    end
    for name in pairs(loaded) do
        if name:match("bot%.(.*)") then
            _G[name:match("bot%.(.*)")] = require(name)
        end
    end
    -- load self
    require "bot"
end

-- flush the storage data
Host.flush_data = function()
    -- not good one
    for _,storage_rom in pairs(Storage.all()) do
        storage_rom:flush(true)
    end
end


-- register bot here, weechat will register earlier then here, search Host.register
if not BOT_REG then
    pcall(Host.register,"bot", Version, "LittleBot with little help")
    BOT_REG = {}
end



-- add print hook
Host.hook_list[#Host.hook_list + 1] = Host.hook_print("Channel Message", host_global_msg_hook )

-- add auto unload hook
Host.hook_list[#Host.hook_list+1] = Host.hook_unload(Host.flush_data)

