local Command   =   require "bot.command"
local Sqlite    =   require "bot.sqlite"
local Log       =   require "bot.log"
local Message   =   require "bot.message"

local storage   =   Sqlite.create {
        sql =   {
                init    =   {
                    "create table if not exists sm_record (id INTEGER PRIMARY KEY AUTOINCREMENT, nickname vchar, sm_name vchar, at  timestamp, unique(nickname, sm_name));"
                ,   "create index if not exists i_sm_record_nickname on sm_record(nickname);"
                }
                -- insert into database
            ,   insert  =   {
                    template    =   "insert into sm_record (nickname, sm_name, at) values('#{nickname}', '#{name}', '#{at}');"
                ,   type    =   "w"
                }
                --  query from database
            ,   query   =   {
                    template    =   "select sm_name, at from sm_record where nickname = '#{nickname}' order by id desc;"
                ,   type    =   "r"
                }
            ,   __name  =   "sm_record"
        }
}

Log.info("Init Sql[%s]",storage.sql.__name)

local contain = function(list, name)
    for i,v in pairs(list) do
        if  v.sm_name == name then
            return true
        end
    end
    return false
end


math.randomseed(os.time())

-- @aim mark one user with one meta
Command.sm = {
    execute = function(msg)
        local _, Name, Meta = Command.sm.takeMeta(msg[2])
        local res, data = storage:exec {   proc    =   "query",
                            args    =   {
                                nickname    =   Name
                            }
                        }
        if not res then
            Log.error("sql query error for :sm, error: %s", data or "")
            return
        end
        local list = storage:parse(data, {
                sm_name     =   "sm_name"
            ,   at          =   "sm_at"
        }) or {}
        if Meta then
            Log.debug("Command :sm [Name => " .. Name .. "] [Meta => " .. Meta .."]")
            if not contain(list, Meta) then
                storage:exec {  proc    =   "insert"
                              , args    =   {
                                  nickname  =   Name
                                , name      =   Meta
                                , at        =   os.date("%Y-%m-%d %H:%M:%S")
                              }
                          }
                Host.say(msg, "Pushed! ~^_^~")
            else
                Host.say(msg, Message.sm_dupl)
            end
        else
            local node  =   list[math.random(math.max(#list,1))] or {}
            Meta = node.sm_name or Message.sm_lost
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
