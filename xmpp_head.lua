-- define the type of struct
local message = {
        jid     = ""
    ,   data    = ""
    ,   to_jid  = ""
    ,   __type  = ".xmpp.message"
        -- message:create({jid = "user@xmpp.com", data = "xmpp chat message"})
        -- @param self for sweet use
        -- @param jid_or_struct the jid or a struct contain all arg
        -- @param data the message data
        -- @param to_jid who receive the message, it should be the bridge name
        -- create one message
    ,   create  = function(self, jid_or_struct, data, to_jid)
        local one = {}
        setmetatable(one, {__index = self})
        if not data then
            one.jid     = jid_or_struct.jid
            one.data    = jid_or_struct.data
            one.to_jid  = jid_or_struct.to_jid
        else
            return self:create({
                jid     =   jid_or_struct
            ,   data    =   data
            ,   to_jid  = to_jid
            })
        end
        return one
    end
}

return {message=message}
