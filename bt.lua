
-- only support the magnet download now, bt torrent is a little timeout lol

-- magnet url : magnet:?xt=urn:btih:cce33693e87df22e7f8b77e694f298f4212a2ff8&tr=http://www.acg23.com:2710/announce

Log = require "bot.log"
Command = require "bot.command"

local bt = {}

-- redirect retrieve command after recieve the magnet command
Command.magnet = {
    execute = function(msg)
        Command.retrieve = function(msg)

        end
    end
}

Command.download = {

}

-- auto add some tracker into this magnet
local addTracker = function(str, context)

end

-- simple check the url, validate if support
bt.check = function(url)
    if url == nil then return false end
    return url:lower():match("magnet:%?xt=urn:%w*:%w*")
end


-- real parse the magnet url
bt.parse = function(url)
    url = url:lower()
    Log.debug("parse url [%s]", url)
    -- try to support all
    local HEAD = url:match("magnet:%?xt=urn:%w*:")
    if not HEAD then
        error "url not magnet url"
    end
    -- DN maybe is not exists
    local FILE = {}
    -- TR maybe is not exists
    local TR = {}
    local LAST = url:sub(("magnet:"):len())
    -- split part the mark the it
    for part in LAST:gmatch("[%&%?]([^%&]*)") do
        local HEAD, BODY = part:match("(.*)=(.*)")
        if HEAD == "tr" then
            table.insert(TR, BODY)
        end
        if HEAD == "ws" then
            Log.debug("not support ws(webseed) now")
        end
        
        if HEAD == "dn" then
            -- set the last resource name
            if not FILE[#FILE] or FILE[#FILE].name then
                FILE[#FILE+1] = {}
            end
            FILE[#FILE].name = BODY
            Log.debug("found name:"..BODY.." for " .. (FILE[#FILE].hash or "none"))
        end

        -- insert the real download seed body
        if HEAD == "xt" then
            -- match the hash type now
            if not FILE[#FILE] or FILE[#FILE].hash then
                FILE[#FILE+1] = {}
            end
            local NODE = FILE[#FILE]
            NODE.type, NODE.hash = BODY:match("urn:(%w*):(%w*)")
            Log.debug("found type:"..NODE.type..", hash:"..NODE.hash)
        end
    end
    return {file = FILE, tracker = TR, format = bt.format}
end

-- format the magnet struct into string
bt.format = function(self)
    local insert = table.insert
    local BUILDER = {"magnet:"}
    for i, file in pairs(self.file) do
        -- insert the hash and file url
        -- xt=urn:btih:${hash}
        insert(BUILDER, (i==1 and "?" or "&") .. "xt=urn:"..file.type..":"..file.hash)
        if file.name then
            insert(BUILDER, "&dn="..file.name)
        end
    end
    for i, tracker in pairs(self.tracker) do
        insert(BUILDER, "&tr="..tracker)
    end
    return table.concat(BUILDER)
end

-- execute one command to start the bt download
-- default use the transimmion, but how to add it into the download list
bt.execute = function(url)
    local EXE = os.getenv("BT_CLIENT") or "transimmion-cli"
    local OPT = os.getenv("BT_CLIENT_OPT") or ""
    -- brute execute the command
    os.execute(EXE .. " " .. OPT .." '" .. url .. "' >> /dev/null &")
end

if arg then
    if not arg[1] then
        print "Magnet parse, usage: lua $file magnet_url"
        return
    end
    -- easy test
    print(bt.parse(arg[1]):format())
end
