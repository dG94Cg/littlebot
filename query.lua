-- depends on bot.last and bot.sqlite to insert data
local Sqlite    =   require "bot.sqlite"
local log       =   require "bot.log"
local Message   =   require "bot.message"
require "bot.last"
Command = require "bot.command"

local sqlite    =   Sqlite:create({})
-- add query method
local Query     =   {}

Query.user      =   function(criteria)
    local arg   =   {   proc    =   "query"
                    ,   args    =   {   criteria    }}
    -- read the database data
    local res, data   =   sqlite:exec(arg)
    log.trace("Query[Res: %s], Data: %s", res, data)
    if not res then
        log.error("Query -> Sql Fail to query, nickname = %s", criteria)
        error(data)
    end
    local list  =   sqlite:parse(data, {
                            nickname    =   ""
                        ,   msg         =   ""
                        ,   at          =   ""
    })
    -- format the output
    local buffer    =   {criteria .. " " .. Message.query_say}
    if not list then
        return Message.query_lost
    end
    log.trace(":Query Found NickName[%s] %s",criteria, Message.query_say)
    for i,v in pairs(list) do
        log.info(":Query [%s]: %s", v.at or "[Nil At]", v.msg or "[Nil Msg]")
        table.insert(buffer, string.format("%s @ %s", v.msg, v.at))
    end
    return table.concat(buffer, "\n")
end

Query.msg       =   function(criteria)
    local arg   =   {   proc    =   "match"
                    ,   args    =   {   criteria    }}
    -- read the database data
    local res, data   =   sqlite:exec(arg)
    local list  =   sqlite:parse(data, {
                            nickname    =   ""
                        ,   msg         =   ""
                        ,   at          =   ""
    })
    -- format the output
    local buffer    =   {}
    for i,v in pairs(list) do
        table.insert(buffer, string.format("%s:%s @ %s", v.nickname, v.msg, v.at))
    end
    return table.concat(buffer, "\n")
end

Query.unknown   =   function()
    return "Unknown Message"
end


Command.query   =   {
        help    =   Message.query_help
    ,   execute =   function(msg)
        -- command is gonging to like :query{.user} as default or :query.msg
        local method, criteria  = msg[2]:match(":query.?([usermsg]*) ([^ ]*)")
        if not criteria or criteria:len()==0 then
            log.trace ":query lost the criteria"
            Host.say(msg,   Message.query_lost)
            return 
        end
        local proc  =   Query.user
        if method and method:len()>0 then
            proc    =   Query[method]
        end
        local res, data =   pcall(proc, criteria)
        log.trace("Query => [%s] [%s]", res, err or "SUCCESS")
        if not res then
            Host.say(msg, Message.query_error)
            log.error(":query, fail, C[%s], method[%s], error: %s", criteria, method or "user", data)
            return
        end
        Host.say(msg, data, {channel = true})
    end
}
