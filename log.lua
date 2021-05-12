#/bin/env lua

-- lua log

local log = {}

log.level = {
    ERROR   = 1,
    WARN    = 2,
    INFO    = 3,
    DEBUG   = 4,
    TRACE   = 5
}
local env_level = os.getenv("VERBOSE") or "DEBUG"
log.current_level = log.level[env_level:upper()]

local trace = function()
    local lines = {}
    for i in debug.traceback():gmatch("[^\n]*") do
        lines[#lines + 1] = table.pack(i:match("([^\t][^:]*):(%d*): in function '([^']*)'"))
    end
    return lines
end

local noNil = function(rom)
    for i=1,#rom do
        rom[i] = rom[i] or "[nil]"
    end
    return rom
end

if not table.pack then
    local stack = {}
    table.pack = function(...)
        return {...}
    end
    stack.unpack = function(rom, ...)
        if #rom > 0 then
            local i = rom[#rom]
            rom[#rom] = nil
            if not i then
                i = "nil"
            else
                i = tostring(i)
            end
            return stack.unpack(rom,i,...)
        end
        return ...
    end
    table.unpack = function(rom)
        return stack.unpack(rom,nil)
    end
end

setmetatable(log, {
    __index = function(value, name)
        if log.level[name:upper()] then
            if log.level[name:upper()] > log.current_level then
                return function() end
            end
               return function(msg, ...)
                for i,v in pairs(log.handler) do
                   local data = string.format(msg, table.unpack(noNil(table.pack(...))))
                   if weechat then
                       weechat.print(log_buff, "[LOG] => " .. data)
                   end
                   pcall(v, name:upper(), { level = i, log = data, config = value, date = os.date("%Y-%m-%d %H:%M:%S"), line = trace()[4]})
               end
            end
        end
    end
})

log.handler = {}
log.file_handler = function(path, custom)
    return function(level, record)
        if type(custom) == "function" then
            path = custom(path)
        end
        local file = io.open(path,"a")
        file:write(("%s [%s] (%s:%s) %s\n"):format(record.date, level, record.line[1],record.line[2], record.log))
        file:flush()
        file:close()
    end
end

log.dump = function(x)
    if not x then
        return "nil"
    end
    local buff = {"{ "}
    for i,v in pairs(x) do
        if (type(v) == "string" or type(v) == "number")
            and (type(i) == "string" or type(i) == "number")then
            table.insert(buff, i)
            table.insert(buff, " = ")
            table.insert(buff, v)
            table.insert(buff,", ")
        end
    end
    buff[#buff] = " }"
    return table.concat(buff)
end
return log
