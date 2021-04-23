local storage = {}
local rom = {}

local insert = table.insert
local concat = table.concat

storage.file_path = function (file)
return ".bot.storage." .. file .. ".lua"
end

local file_path = storage.file_path
storage.encode = function(str)
    local buff = {"&"}
    local byte = string.byte
    for i in str:gmatch(".") do
        insert(buff, byte(i))
    end
    return table.concat(buff,".")
end
storage.decode = function(str)
    if type(str) ~= "string" or not str:match("^%&") then
        return str
    end
    local buff = {}
    local char = string.char
    for i in str:gmatch("%d+") do
        local n = tonumber(i)
        if n then
            insert(buff, char(n))
        end
    end
    return table.concat(buff)
end

-- load the storage lua database
storage.take = function(name)

    local decode = storage.decode

    if not rom[name] then
        local extract = loadfile(file_path(name))
        if extract then
            rom[name] = extract()
        end
        rom[name] = rom[name] or {}
        -- decode all
        local transform = {}
        transform.recur = 
        function(data)
            local _rom = {}
            for i,v in pairs(data) do
                if type(v) == "string" then
                    _rom[decode(i)] = decode(v)
                elseif type(v) == "table" then
                    _rom[decode(i)] = transform.recur(v)
                else
                    _rom[decode(i)] = v
                end
            end
            return _rom
        end
        rom[name] = transform.recur(rom[name])
        rom[name].flush = storage.flush
        rom[name].__name = name
    end
    return rom[name]
end

storage.all = function() 
    return rom
end
storage.flush = function(table, force)
    if not force and table.__last_flush and os.time() - table.__last_flush < 30 then
        return false
    end
    table.__last_flush = os.time()
    local File = io.open(file_path(table.__name), "w")
    File:write "#!/bin/env lua\n"
    File:write "-- lua for storage version 0.1\n"
    local Buff = {}
    local _ = {}
    local count = 0
    _.serial = function(table, Name)
        insert(Buff,"local " .. Name .. " = {}\n")
        for i,v in pairs(table) do
            if type(v) ~= "function" then
                if type(v) == "table" then
                    local TName = "t" .. os.time() .. math.random(100000) .. count
                    count = count + 1
                    _.serial(v, TName)
                    insert(Buff, Name)
                    if type(i) == "string" then
                        insert(Buff, "[ [[")
                        insert(Buff, storage.encode(i))
                        insert(Buff, "]] ] = ")
                    else
                        insert(Buff,"[")
                        insert(Buff, i)
                        insert(Buff,"]")
                        insert(Buff, " = ")
                    end
                    insert(Buff, TName)
                    insert(Buff, "\n")
                else
                    insert(Buff, Name)
                    if type(i) == "string" then
                        insert(Buff, "[ [[")
                        insert(Buff, storage.encode(i))
                        insert(Buff, "]] ] = ")
                    else
                        insert(Buff,"[")
                        insert(Buff, i)
                        insert(Buff,"]")
                        insert(Buff, " = ")
                    end
                    if type(v) == "string" then
                        insert(Buff, "[[")
                        insert(Buff, storage.encode(v))
                        insert(Buff, "]]\n")
                    else
                        insert(Buff, v)
                        insert(Buff, "\n")
                    end
                end
            end
        end
    end
    _.serial(table, "rom")
    File:write(concat(Buff))
    File:write "\nreturn rom"
    File:flush()
    File:close()
    return true
end

return storage
