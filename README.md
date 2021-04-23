# IRC BOT

there is a little irc bot for hexchat and weechat.   
> at first i thought hexchat-bot is more easier to write. actually it does

Weechat provide more design, but it didn't mean it **take more difficult** to build a bot.  

Wrote by *= Lua =*

> PS: i love this little impl of lisp, lol

## Develop Route

- [x] irc bot
- [x] hot swap
- [x] safe code eval
    * [x] irc command execute
    * [ ] url download execute
- [x] simple storage
- [x] simple sqlite
- [x] last word record
- [x] query msg
- [ ] xmpp support
- [x] weechat support
- [-] name swap
        > support by hexchat, not weechat now
- [-] remote code update
        > not complete, but support by git
- [ ] remote code execute 
- [ ] remote authorize code execute
- [ ] bt magnet download manage
    * [x] magnet parse
    * [ ] url biterront download
    * [ ] add download task into qbittorrent-nox
    * [ ] list download task from qbittorrent-nox
    * [ ] resume download task at qbittorrent-nox
    * [ ] delete download task at qbittorrent-nox


## struct

- command.lua   provide the command that is support by **bot**

    > bot will search the command table as command source.  
    > Usage: echo.lua
    ```lua
    local command = require "bot.command"

    command.lua =   {
            help    =   ":echo hello world"
        ,   execute =   function(msg)
            Host.say(msg, msg[2]:match(":echo (.*)"))
        end
    }
    ```
- init.lua  the main logical by bot, provide Context, start up by host
    > most command is writen at init.lua actually,  littlebot was born with only one littlebot.lua at first
    * update is design by my condition, change it as your wish

- sandbox.lua   sandbox for lua, protect the lua environment at most situation
    > there is danger at execute :lua command by other user at irc, i suggest isolate the weechat that run littlebot as low level system user
- sqlite.lua    ugly support for sqlite, use by query.lua
    > no ffi, just execute sqlite by shell, so here is danger about shell inject
- storage.lua   ugly support for storage, use by early command
    > no ffi, just write data as lua file, may danger be with yom
- log.lua ugly simple support for log
    > i fuck my mind, i should import simple log module from luarocks
- bt.lua    just a little magnet parse
    > i got wireguard net, sorry for slow work here
- message.lua  for message view
- xmpp.lua/xmpp_head.lua xmpp support is on working
    > should i use python to impl or use dino core as ffi support?
    > weechat.hook_proccess may as a hack way to support xmpp here
- query.lua/last.lua    record the message from irc chat, :query {nickname}, :last {nickname} to list last word, :query.msg {msg} to find command
    > buggy one
