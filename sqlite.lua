local log     = require "bot.log"

local Sqlite = {}

setmetatable(Sqlite, {__index = function(_,_) return {} end})

Sqlite.create = function(sqlite)
    local sqlite    = sqlite or {}
    setmetatable(sqlite, {__index = Sqlite})
    return sqlite
end

Sqlite.database =   "bot.db"
local PWD   =   os.getenv("PWD")
log.info("DATABASE PATH: %s", PWD.."/" .. Sqlite.database)
-- action sql place here
Sqlite.sql      = {
    init        =   {   "create table if not exists msg_record (id INTEGER PRIMARY KEY AUTOINCREMENT, server vchar, channel vchar, nickname vchar, msg vchar, at timestamp);"
                    ,   "create index if not exists i_nickname_record on msg_record(nickname);"
                    ,   "create index if not exists i_server_record on msg_record(server);"
                    ,   "create index if not exists i_at_record on msg_record(at);"
                    }
    ,   insert      =   { template = "insert into msg_record (server, channel, nickname, msg, at) values ('#{server}', '#{channel}', '#{nickname}', '#{msg}', '#{at}');", type = "w" }
    ,   findone     =   { template = "select * from msg_record where nickname = '%s' order by id desc limit 1;", type = "r" }
    ,   query       =   { template =  "select * from msg_record where nickname = '%s' order by id desc limit 5;", type = "r" }
    ,   match       =   { template = "select * from msg_record where msg like '%s' order by id desc limit 5;", type = "r" }
}


local format = function(str, args)
    if not args then
        log.trace("Sqlite: Not format[%s]", str)
        return str
    end
    if type(args) ~= "table" then
        log.trace("Sqlite: Simple format[%s]", str, args)
        return str:format(args)
    end
    if str:match("#{[^}]*}") then
        log.trace("Sqlite: Table format[%s]", str)
        return str:gsub("#{([^}]*)}", args)
    end
    log.trace("Sqlite: Unpack format[%s]", str, args)
    return str:format(table.unpack(args))
end

-- execute the sqlite3 to read data
Sqlite.read     = function(sql, args, enable_log) 
    local e_sql = format(sql, args) 
    -- @TODO: make sure it only give memory file
    local t_out = os.tmpname()
    log.trace("redirect sqlite query result into [%s]", t_out)
    local h_pro = io.popen("sqlite3 -line " .. Sqlite.database .. " > " .. t_out .. " 2>>sqlite.err.log", "w")
    if not h_pro then
        log.error "fail to execute sql, can't open database"
        return nil, "fail to execute sql, can't open database"
    end
    if enable_log ~= false then
        log.debug("Execute Sql [%s]", e_sql)
    end
    h_pro:write(e_sql)
    h_pro:close()
    -- read the output
    local h_out = io.open(t_out, "r")
    if not h_out then
        local info = "not out flush data"
        log.error(info)
        return nil, info
    end
    local data  = {}
    for line in h_out:lines() do
        table.insert(data, line)
    end
    data    =   table.concat(data, "\n")
    h_out:close()
    -- delete the old one
    os.execute("rm " .. t_out)
    log.trace("Sqlite:read -> %s", data)
    return data
end

-- @desc execute the sqlite3 to insert data
Sqlite.write    = function(sql, args, enable_log) 
    local e_sql = format(sql, args) 
    local h_pro = io.popen("sqlite3 " .. Sqlite.database .. " 2>>sqlite.err.log", "w")
    log.trace("prepare to execute sql: %s", e_sql)
    --print(format("{%s}", e_sql))
    if not h_pro then
        log.error "fail to execute sql, can't open database"
        return nil, "fail to execute sql, can't open database"
    end
    if enable_log ~= false then
        log.debug("Execute Sql [%s]", e_sql)
    end
    h_pro:write(e_sql)
    h_pro:close()
end

-- @desc execute the real action
Sqlite.exec     = function(self, proc, args)
    if args then
        return self:exec {   proc = proc
                         ,   args  = args
                         }
    end

    local args   =   proc.args
    local proc  =   proc.proc
    -- check if sqlite3 is execute able
    local exists, _ = os.execute("sqlite3 --version >> /dev/null")
    if not exists then
        if Sqlite.warn["exists"] then
            return
        end
        Log.warn "sqlite3 not exists at path"
        return
    end
    if type(self.sql.init) == "table" then
        -- init the database first
        for i, line in pairs(self.sql.init) do
            Sqlite.write(line, "", false)
        end
    else
        Sqlite.write(self.sql.init)
    end
    -- sqlite3 exists, format the args to protect system
    local args  =   Sqlite.format(args)
    -- real execute code
    local sql   = self.sql[proc]
    local func  = Sqlite.write
    --log.info "init write method"
    if sql.type == "r" then
        --log.info "read method"
        func = Sqlite.read
    end
    -- protect execute the real method
    return pcall(func, sql.template, args)
end

-- @name replace the [" \ '] with wrapped by \
local replace = function(str)
    local r_str = str:gsub("\\", "\\\\"):gsub("\"", "\\\""):gsub("'", "\\'")
    log.trace("Sql:Replace => %s", r_str)
    return r_str
end

-- @desc format the list, make it won't break sql easily
Sqlite.format = function(list)
    if  not list then
        return nil
    end
    for i, v in pairs(list) do
        list[i] = replace(v)
    end
    return list
end

-- @desc parse result_set into struct, there got one problem, it can't diff from null and empty
Sqlite.parse = function(self, result_set, struct)
    local result    =   {}
    local unit      =   {}
    local c_unit    =   0
    local count     =   0
    -- count the struct meta count
    for _,_ in pairs(struct) do
        c_unit  =   c_unit + 1
    end
    -- print("start parse, c_count:", c_unit)
    -- put the meta
    for line in result_set:gmatch("[^\n]+") do
        -- print("parse line:", line)
        local field, v  =   line:match("^ *([^=]*) = (.*)")
        -- print(("parse field[%s] v[%s]"):format(field, v))
        log.trace("Sqlite:parse -> parse [%s] => [%s]", field, v)
        if  struct[field] then
            -- print("parse match meta", field, v)
            unit[field] =   v
            count   =   count + 1
        end
        if  count >= c_unit then
            table.insert(result, unit)
            count   =   0
            unit    =   {}
        end
    end
    return result
end
return Sqlite
