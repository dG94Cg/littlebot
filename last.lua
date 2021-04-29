-- last, record the last word of somebody say
--
local storage = require "bot.storage"
local log     = require "bot.log"
local Sqlite  = (require "bot.sqlite"):create({})
local Message = require "bot.message"

local last_record   = storage.take("last_record")
local record = function(msg)
    --weechat.print("", msg[1].." say: "..msg[2])
    if not msg[1] then
        return
    end
        -- won't record the bot say
    if msg[1]:lower():match("^littlebot.*") then
        log.trace("we don't record the bot[%s] said", msg[1])
        return
    end
    last_record[msg[1]] = last_record[msg[1]] or {}
    local last          = last_record[msg[1]]
    local swap          = {}
    while true do
        for i,v in ipairs(last) do
            last[i] = swap
            swap    = v
            if i > 5 then
                break
            end
        end
        last[#last+1] = swap
        break
    end
    --log.info("last word [%s]@%s", (swap or {}).msg or "None", #last)
    last[1]     = {
        msg =   msg[2]
    ,   at  =   os.date("%m-%d %H:%M:%S")
    }
    Sqlite:exec {       proc  = "insert"
                  ,     args  = {  nickname = msg[1]
                                 , msg = msg[2]
                                 , server = msg.server
                                 , channel = msg.target
                                 , at   =   os.date("%Y-%m-%d %H:%M:%S")
                                 }
                  }
    --weechat.print("", msg[1].." record last " ..msg[2])
    --weechat.print("", msg[1].." record last " ..msg[2])
    return
end

table.insert(Host.msg_listen, record)

Command.last = {
    execute = function(msg)
        local nickname      =   msg[2]:match(":last *([^ ]*)") or "None"
        local last          = last_record[nickname]    or  {}
        -- if last is execute at self, use the second sentence
        if msg[1] == nickname then
            last            = last[2]
        else
            last            = last[1]
        end

        if last then
            Host.say(msg, string.format(Message.last_say, nickname, last.at, last.msg))
            return
        end
        Host.say(msg, string.format(Message.last_lost, nickname or Message.last_nil))
    end,
    help = Message.last_help
}

return Command.last
