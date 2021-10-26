# IRC BOT

## DEPRECATED, my mind flee away. don't worry there is a lot IRC BOT exists at github, and my one is ungly and useless. It even require a weechat.

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
- [-] hexchat support
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
- [ ] colorize msg!
- [ ] privmsg support


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

## Command

- :sm     give user a mark, ``:sm littleme Admin`` as mark, ``:sm littleme`` as read
- :say    let bot said something, ``:say hello world``
- :lua    ``:lua ${code}``  execute the lua code with some protection
    > print mean say to channel, say mean say to command sender
    > usage: :lua print "hello world"
- :last   ``:last ${nickname}``  to know last msg he said
- :query  ``:query ${nickname}``  to know what he said at last 5 msg
- :help   a urgly help manual
- :auth   check out if you're authed, change the admin list at init.lua#Context.admin
- :reload reload the code, warn: if code load error, bot will crash
- :update update current code from git, you need fix the path before use
- :mute tell bot to shut up or allow to speak


## Hack and Development

add lua file with ``require "bot.command"`` if you wana add some function.

- Host.say

    Host.say depends on Host.command
    - @arg source :: ``{server="irc server name for weechat to find buffer",target="who you wana msg to, #channel_name or nickname"}``
    - @arg msg    :: the message
    - @arg option :: ``{channel=true}``, won't add command sender name as prefix like "user: msg" if channel is true ,design for further use
- Command.retrieve

    execute only when not command match, why do i add this????

- Host.msg_listen

    execute at everytime when message reach

- sanbox.lua

    not safe sandbox here, impl it as your wish, code is .... kind of smelly, it should got loop protect and io,os,package,loadfile,dofile,load protect

    > WARN: require is not protect by sandbox here, impl it as your need
- command.fuc.execute = function (msg) the msg

    msg is create by msg_head.lua
    ```lua
    msg = {
        nickname
    ,   msg
    ,   server  =   server
    ,   target  =   channel_name|nickname
    }```
    > not primsg support now
