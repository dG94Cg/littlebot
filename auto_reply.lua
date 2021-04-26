local log   =   require "bot.log"

if not Host or not Host.hook then
    log.error "Auto Reply require Host.hook"
    error "Host not init?"
end


local stupid_question   =   {
            "有人么%?*$"    
        ,   "有人吗%?*$"    
        ,   "有人%?*$"    
        ,   "在么?%?*$"
        ,   "在?干啥呢?%?*$"
        ,   "在干什么%?*$"
        ,   "没人么?%?*$"
        ,   "^[喂唯惟唯]+%?*$"
        ,   "is someone here?*"
        ,   option  =   {
            user    =   ".*"
        ,   len_min =   -1
        ,   len_max =   99999
        }
}


local match_list    =   {

}

-- auto reply list
match_list[stupid_question] =   {
        "没人,没人, 哪有人¯\_(ツ)_/¯"
    ,   "耐心点, irc频道早就不是即时聊天的主要选择了, 都挂着 时不时看看"
    ,   "又来? (｢・ω・)｢ 腻咋不半夜去敲邻居家门问问他睡了没?"
    ,   "召唤TJM! (┙>∧<)┙へ┻┻怼他! 乍乍乎乎的, 没点耐心"
    ,   "莫要问有人没人在干啥, 有啥问啥, 莫要急躁>_<"
}


local auto_reply    =   function(msg)
    if not msg[2] then
        return
    end
    local output
    while true do
        for match, list in pairs(match_list) do
            if  type(match) == "table" then
                for i,line in ipairs(match) do
                    if  msg[2]:match(line) then
                        output  =   list
                        break
                    end
                end
            end
            if  type(match) == "string" then
                if  msg[2]:match(match) then
                    output  =   list
                    break
                end
            end
        end
    break
    end

    if not output then
        log.trace("[%s] Not Match", msg[2])
        return
    end

    if  type(output)    ==  "string" then
        Host.say(msg, output)
        return
    end
    local r
    repeat 
        r =   math.random(1,#output)
        log.trace("rand => %s, data => %s", r, output[r] or "None")
    until output[r]
    Host.say(msg,output[r])
end

table.insert(Host.msg_listen, auto_reply)
