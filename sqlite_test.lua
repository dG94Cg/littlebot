package.path =      package.path
                ..  ";/home/tox/?/init.lua"
                ..  ";/home/tox/?.lua"
sqlite = require "bot.sqlite"
s = sqlite:create({})
print(s:exec {proc = "insert", args = {server = "freenode", channel = "#bot_irc", nickname = "me", msg = "joke|done", at = os.date("%Y-%m-%d %H:%M:%S")}})
--os.execute ("echo '" .. sqlite.sql.init .. "' | sqlite3  bot.db")
f       = io.popen "echo 'select * from msg_record;' | sqlite3 -line bot.db"
data    = f:read("a*")
f:close()
print(sqlite:exec {proc = "query", args = {"me"}})
--assert(data == select(2,sqlite:exec {proc = "query", args = {"me"}}))
res,    data    =   sqlite:exec {proc = "query", args = {"me"}}
u = sqlite:parse(data, {nickname=""})[1]
for i,v in pairs(u) do
    print(i, v)
end
print "PASS?"
