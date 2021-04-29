-- depends on bot.last and bot.sqlite to insert data
local Sqlite    =   require "bot.sqlite"
local log       =   require "bot.log"
local Message   =   require "bot.message"
require "bot.last"
Command = require "bot.command"

local sqlite    =   Sqlite:create({})
-- add query method
local Query     =   {}


-- @name match_lrex
-- @desc check if v match the rule
local match_lrex    = function(lrex, v)
    local match = true
    --  must match
    while true do
        for must in pairs(lrex.must) do
            Log.info("testing [%s]", must)
            if not v:match(must) then
                match = false
                break
            end
        end
    end
    -- forbid match
    while true do
        for forbid in pairs(lrex.forbid) do
            Log.info("rejecting [%s]", must)
            if v:match(forbid) then
                match = false
                break
            end
        end
    end
    return match
end

Query.user      =   function(criteria, lrex)
    local buffer    =   {criteria .. " " .. Message.query_say}
    local max_id    = 100000000
    local last_record   =   nil
    while #buffer < 6 do
        if last_record == max_id then
            break
        end
        last_record = max_id
        local arg   =   {   proc    =   "query"
                            ,   args    =   {   criteria
                                                ,   max_id
                                                ,   20
                            }
        }
        -- read the database data
        local res, data   =   sqlite:exec(arg)
        log.trace("Query[Res: %s], Data: %s", res, data)
        if not res then
            log.error("Query -> Sql Fail to query, nickname = %s", criteria)
            error(data)
        end
        local list  =   sqlite:parse(data, {
                                id          =   ""
                            ,   nickname    =   ""
                            ,   msg         =   ""
                            ,   at          =   ""
        })
        -- format the output
        if not list then
            return Message.query_lost
        end
        log.trace(":Query Found NickName[%s] %s",criteria, Message.query_say)
        for i,v in pairs(list) do
            log.trace(":Query [%s]: %s", v.at or "[Nil At]", v.msg or "[Nil Msg]")
            --  check if the record match the filter rule
            if lrex then
                local match = match_lrex(lrex, v)
                if match then
                    table.insert(buffer, string.format("%s @ %s", v.msg, v.at))
                end
            else
                table.insert(buffer, string.format("%s @ %s", v.msg, v.at))
            end
            -- early return if list has contain enought element
            if #buffer >= 6 then
                return table.concat(buffer, "\n")
            end
            max_id  =   v.id
        end
    end
    return table.concat(buffer, "\n")
end

Query.msg       =   function(criteria, lrex)
    local max_id    = 100000000
    local buffer    =   {}
    local last_record = nil
    local self      =   true
    while #buffer < 6 do
        if last_record == max_id then
            break
        end
        last_record = max_id
        local arg   =   {   proc    =   "match"
                            ,   args    =   {   max_id
                                            ,   criteria
                                            ,   20
                            }
        }
        -- read the database data
        local res, data   =   sqlite:exec(arg)
        local list  =   sqlite:parse(data, {
                                nickname    =   ""
                            ,   msg         =   ""
                            ,   at          =   ""
                            ,   id          =   ""
        })
        -- format the output
        for i,v in pairs(list) do
            if self then
                self = false
            else
                --  check if the record match the filter rule
                if lrex then
                    Log.info "lrex enable"
                    local match = match_lrex(lrex, v)
                    if match then
                        table.insert(buffer, string.format("%s:%s @ %s", v.nickname, v.msg, v.at))
                    end
                else
                    table.insert(buffer, string.format("%s:%s @ %s", v.nickname, v.msg, v.at))
                end
                if #buffer >= 6 then
                    return table.concat(buffer, "\n")
                end
            end
            max_id  =   v.id
        end
    end
    return table.concat(buffer, "\n")
end

Query.unknown   =   function()
    return "Unknown Message"
end

--  @name parse_lrex
--  @desc  parse the lrex of :[+-][^ ]*
local parse_lrex  = function(str)
    if not str then return nil end
    local match = {
            must   = {}
        ,   forbid = {}
    }
    for line in str:gmatch(":([+-][^ ]*)") do
        if line:match("^%+") then
            table.insert(match.must, line:match("^%+(.*)"))
        else
            table.insert(match.forbid, line:match("^%-(.*)"))
        end
    end
end

--  @name Command#query execute the query command from irc
Command.query   =   {
        help    =   Message.query_help
    ,   execute =   function(msg)
        -- command is gonging to like :query{.user} as default or :query.msg
        local method, criteria, lrex  = msg[2]:match(":query.?([usermsg]*) ([^ ]*) ?(.*)")
        if not criteria or criteria:len()==0 then
            log.trace ":query lost the criteria"
            Host.say(msg,   Message.query_lost)
            return 
        end
        local proc  =   Query.user
        if method and method:len()>0 then
            proc    =   Query[method]
        end
        local res, data =   pcall(proc, criteria, parse_lrex(lrex))
        log.trace("Query => [%s] [%s]", res, err or "SUCCESS")
        if not res then
            Host.say(msg, Message.query_error)
            log.error(":query, fail, C[%s], method[%s], error: %s", criteria, method or "user", data)
            return
        end
        Log.info("Out => [%s]", data)
        Host.say(msg, data, {channel = true})
    end
}
