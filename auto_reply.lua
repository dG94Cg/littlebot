local log   =   require "bot.log"

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
        "没人,没人, 哪有人¯\\_(ツ)_/¯"
    ,   "耐心点, irc频道早就不是即时聊天的主要选择了, 都挂着 时不时看看"
    ,   "又来? (｢・ω・)｢ 腻咋不半夜去敲邻居家门问问他睡了没?"
    ,   "召唤TJM! (┙>∧<)┙へ┻┻怼他! 乍乍乎乎的, 没点耐心"
    ,   "莫要问有人没人在干啥, 有啥问啥, 莫要急躁>_<"
}

local chobsd    =   {
    ""
    ,   option  =   {
            user    =   "^chobsd_*"
        ,   len_min =   -1
        ,   len_max =   string.len("说腻妈呢乍乍乎乎的")
    }
}
match_list[chobsd]  =   {
        "腻是SPAM吧? 上来几句就跑路, 累不累?"
    ,   "是流量太贵, 还是腻时间太急, 说几句就balabala跑了"
    ,   "腻看看腻, 乍乍乎乎, 这是IRC好么"
    ,   "干啥 干啥 干啥呢腻!"
    ,   "¯\\_(ツ)_/¯"
}

match_list["干啥"]  =   {
        {
                "腻怎么整天问干啥呀?"
            ,   "去把TideBot重构一下呀, 这么闲"
            ,   "瞧瞧你这出息, 在个IRC频道问别人干啥"
            ,   "问句干啥腻就跑, 搞得咱们是吃人老虎 吓着腻了"
            ,   option  =   {
                user    =   "chobsd"
            }
        }
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
                        if match.option then
                            local o = match.option
                            if o.user and not msg[1]:match(o.user) then
                                break
                            end
                            if o.len_min and msg[2]:len() < o.len_min then
                                break
                            end
                            if o.len_max and msg[2]:len() > o.len_max then
                                break
                            end
                        end
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

    -- say something that is static config
    if  type(output)    ==  "string" then
        Host.say(msg, output)
        return
    end

    -- say something that read from table
    local r
    -- find one
    repeat 
        r =   math.random(1,#output)
        log.trace("rand => %s, data => %s", r, output[r] or "None")
    until output[r]
    -- if is table
    if type(output[r]) == "table" then
        local o = output[r].option
        output[r].index = (output[r].index or 0 ) % #output[r] + 1
        if not o then
            Host.say(msg,output[r][output[r].index] or "啊?")
        end
        if  o.user then
            if not msg[1]:match(o.user) then
                return
            end
            if o.len_min and msg[2]:len() < o.len_min then
                return
            end
            if o.len_max and msg[2]:len() > o.len_max then
                return
            end
        end
        Host.say(msg,output[r][output[r].index] or "啊?")
    else
        -- said it instead
        Host.say(msg,output[r])
    end
end


if arg and arg[1] == "test" then
    -- test
    Host = {say = print}
    auto_reply({"chobsd", "干啥"})
    return 
end



if not Host or not Host.hook then
    log.error "Auto Reply require Host.hook"
    error "Host not init?"
end
table.insert(Host.msg_listen, auto_reply)
