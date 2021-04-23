local Msg   =   {
        struct  =   {
            name    =   "name"
        ,   host    =   "host"
        ,   command =   "irc_command"
        ,   target  =   "irc_channel"
        ,   msg     =   "send msg data"
        ,   server  =   "irc server name"
        ,   source  =   "signal_data"
        }
}

Msg.parse   =   function(signal, r_command, signal_data)
    local msg = signal_data
    --weechat.print("", "S:"..signal .. " C:" .. command .. " SD:"..signal_data)

    -- not support for hexchat with complex parse
    if hexchat then return signal end

    -- only weechat support this level parse
    local source,command,target,data = msg:match("([^ ]*) ([^ ]*) ([^ ]*) :(.*)")
    if not source then
        Log.trace(("can not parse msg[%s]"):format(msg))
        return {}
    end
    local name, host = source:match(":([^!]*)![^@]*@(.*)")
    Log.trace(("name[%s] host[%s] command[%s] target[%s] msg[%s]")
                    :format(name or "", host or "", command or "", target or "", data or ""))
    --weechat.print("", ("name[%s] host[%s] command[%s] target[%s] msg[%s]")
      --              :format(name or "", host or "", command or "", target or "", data or ""))
    msg =   {
            name
        ,   data
        ,   name = name
        ,	host = host
        ,	command = command
        ,	target = target
        ,	msg = data
        ,	server = r_command:match("([^,]*)") or "nil"
        ,	source = signal_data
    }
    --weechat.print("", string.format("Server[%s] Source[%s]", msg.server or "", msg.source or ""))
    return msg
end

return Msg
