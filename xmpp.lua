-- @name xmpp bridge
-- @desc try to send msg into xmpp, and receive the command to reply

-- load the system lib function
local insert = table.insert

-- log
local log       = require "bot.log"
-- storage = { load :: String -> {owner = String}, save :: {owner = String} -> () }
local storage   = require "bot.storage"

-- the xmpp package
local xmpp      = {}
local Message   = require "bot.xmpp_head".message

local __config  = storage.take "config"

xmpp.config = {
    -- configure the username
    username = os.getenv("XMPP_USER")       or __config.jid,
    password = os.getenv("XMPP_PASSWORD")   or __config.password,
    -- bridge   = os.getenv("XMPP_USER_BRIDGE")or __config.bridge
    -- proxy impl here
}

local buffer_record = storage.take "xmpp.buffer_record"

-- IRC => Msg => XMPP
-- XMPP => decode => IRC
-- @param msg_xml the xmpp raw data, convert it as Message struct
-- @return { command = "say/nick/lua", data = "say msg/lua command/nick name", who = "name"}
xmpp.receive = function(msg_xml)
    -- invoke the parse command
    -- @TODO change the bind to real
    local msg       = Message:create({jid = msg_xml.jid, data = msg_xml.data, to_jid = msg_xml.target})
    local com, arg  = xmpp.parse_command(msg.data)
    local f_com     = xmpp.command[com or "say"]
    local res, err  = pcall(f_com, msg, arg)
    if not res then
        log.error("Fail to Execute Command[%s] U[%s] error: %s", com or "say", msg.jid, err)
    end
end

xmpp.send = function(jid, msg)
    -- pack the msg struct
    if msg then
        return xmpp.send({jid=jid, data=msg})
    end
    local jid   = jid.jid
    local msg   = jid.data

    -- @TODO: impl the real xmpp send
end


local __search = function(map, channel_name)
    local set = {}
    for i,v in pairs(map) do
        if v.channel:match(channel_name) then
            insert(set, {id = i, channel = v.channel, server = v.server})
        end
    end
    return set
end

buffer_record.__search  = __search
-- record the id and buffer and channel name
-- buffer_record = {
--     user_name   = {
--         { channel = "channel_name", server = "freenode"}
--     },
--     __search    = __search
-- }

-- add the buffer and irc name record
xmpp.add_buffer_record = function (user_name ,server_name, irc_name)
    if not buffer_record[user_name] then
        buffer_record[user_name] = {}
    end
    insert(buffer_record[user_name], {
            channel = irc_name
        ,   sever   = server_name
    })
    return buffer_record
end



-- record the command that op from xmpp
-- command :: { Command :: { desc::String, exec::Message -> () } }
xmpp.command = {
    say     = {
            desc = "normal say information to irc"
        --  @see message contain the xmpp message
        ,   exec = function(msg)
            -- read the buffer/channel record of this jid user
                local current_record = buffer_record[msg.jid] or {}
                local id             = current_record.id or 1
                if not current_record[id] then
                    -- not current buffer, should tell the user set one buffer
                    local reply_msg = msg.jid .." don't chat at any buffer now, please join one"
                    log.debug("User[%s] try execute `say` at no buffer on [%s] Bot", msg.jid, msg.to_jid)
                    xmpp.send(Message:create({jid=msg.to_jid or xmpp.config.username, data=reply_msg, to_jid=msg.jid}))
                    return
                end
                local record    = current_record[id]
                -- send the msg to current buffer/channel for jid user
                --  because this function is almost design for weechat, not much hexchat support
                --  Host say in weechat support multi-buffer chat, so here is the answear
                Host.say({server=record.server, target=record.channel}, msg.data, {channel = true})
        end
    },
    id      = {
            desc = "switch the id of channel/buffer, switch the current one or create new one"
        ,   exec = function(msg, args)

            local all_record    = buffer_record[msg.jid]
            local id                = args[1]
            -- display current id
            if not id then
                local info = string.format("[%s] chat on Id[%s]", msg.jid, all_record.id or "None Channel, use :buffer and :id to select one channel")
                xmpp.send(Message:create({jid=msg.to_jid, data=info, to_jid = msg.jid}))
                return
            end
            -- select current channel by id
            if not arg[2] then
                if  not all_record[id] then
                    all_record.id   =   id
                    xmpp.send(Message:create({
                         jid    = msg.to_jid
                    ,    data   = string.format("[%s] current on [%s] now", msg.jid, id)
                    ,    to_jid = msg.jid}))
                    return
                end
                xmpp.send(Message:create({
                     jid    = msg.to_jid
                ,    data   = string.format("[%s] there is not channel id by [%s]", msg.jid, id)
                ,    to_jid = msg.jid}))
                return
            end
            -- switch the channel into id
            local server, channel   = args[2]:match("([^#]*)(#.*)")
            -- find the channel exists
            local set               = buffer_record.__search(all_record, channel)
            -- switch the id if set exists
            if #set > 0 then
                for i,record in pairs(set) do
                    if record.server == server then
                        -- find
                        local swap  = all_record[record.id]
                        all_record[record.id]   =   nil
                        if all_record[id] then
                            all_record[record.id]   =   all_record[id]
                        end
                        all_record[id]          =   swap
                        return
                    end
                end
            end
            -- add new id for channel if set not exists
            xmpp.add_buffer_record(msg.jid, server, channel)
            local swap          = all_record[#all_record]
            all_record[#all_record] = nil
            -- swap the record for id
            if all_record[id] then
                all_record[#all_record] =   all_record[id]
            end
            all_record[id]      = swap
        end
    },
    lua     = {
            desc = "execute the lua code"
        ,   exec = function(msg)
            -- use sandbox to deal with it
        end
    },
    stat    = {
            desc = "display the user current status, which the buffer/channel is chatting, auth-status, other information"
        ,   exec = function(msg)

        end
    },
    buffer  = {
            desc = "display all buffer or change the buffer to new one"
        ,   exec = function(msg)

        end
    },
    leave   = {
            desc = "leave one buffer, not irc leave, is mean won't transfer the irc message from channel to xmpp"
        ,   exec = function(msg)
        
        end
    },
    join    = {
            desc = "join one buffer/channel, not mean irc join(it may cause the irc join). but it should just transfer the information from irc channel into xmpp"
        ,   exec = function(msg)

        end
    },
    __meta  = {
        __index = function(target, name)
            if   target[name] then
                return target[name]
            end
            for i,v in pairs(target) do
                if i:match(name) then
                    return v
                end
            end
            error ("Command:"..name.." Not Found")
        end
    }
}

-- @name parse_command
-- @desc parse the xmpp data into command and arg
-- @desc return the say if not match com
-- @param data the xmpp chat data only the str part
xmpp.parse_command = function(data)
    local com   = data:match("^:([^ ])*")
    if not com then
        return nil
    end
    local res_arg = data:sub(2+com:len())
    local arg = {}
    -- check if only command
    if not res_arg:match("[^ ]") then
        -- split ' ' ','
        for line in res_arg:match("[^ ^,]*") do
            insert(arg, line)
        end
    end
    return com, arg
end

if not Host then
    error "require Host::table to impl all action"
end

return xmpp
