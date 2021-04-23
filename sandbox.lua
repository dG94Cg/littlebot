local sandbox = { rom = {}}
local V1 = {}
local V2 = {}

local LIB_LOAD = {}
-- main 
local __main__ = function ()
    if  arg and arg[1] == "test" then
        print "test 1"
        print (sandbox.run "print(1)")
        assert(print)
        print "test 1 with print env"
        print (sandbox.run ("print(1)", function (env) env._G.print = print end))
        print "test loop"
        print (sandbox.run ("while(1) do end"))
        print "test print _G"
        print (sandbox.run ("for i,v in pairs(io) do print(i,v) end", function (env) env._G.print = print end))
        print "test load"
        local code = "load(\"print(1)\")()"
        print (sandbox.run ("load (code)()", function(_,_G) _G.code = code end))
    end
end

-- patch_path 
-- patch the path, to make code only load this path file
local patch_path = function(x)
    return (x:gsub("%.%./", "/"):gsub("^/*",""))
end
-- delegate_os
-- delegate safe function
local delegate_os = function(origin)
    os = {clock = origin.clock, date = origin.date, time = origin.time, getenv = origin.getenv}
end
-- package only leave preload, loaded table
local delegate_package = function(origin)
    package = {preload = origin.preload, loaded = origin.loaded}
end
local delegate_dofile = function(origin)
    dofile = function (x) origin(patch_path(x)) end
end
local delegate_loadfile = function(origin)
    loadfile = function (x) origin(patch_path(x)) end
end
local loop_protect = function(debug)
    local i = 0
    local limit_step = function(max)
        return function(event, line)
            i = i + 1
            if i > max then
                i = 0
                error(("program in sandbox step limit by %s line"):format(max/10))
            end
        end
    end
    debug.sethook(limit_step(1500000), "l")
end

local sandbox_recovery = function(context, protect, LIB_LOAD)
    -- V1 has sandbox recovery only
    if context.version == V1 then
        for i,v in pairs(protect) do
            _G[i] = v
            if protect.package.preload[i] == LIB_LOAD then
                protect.package.preload[i] = v
            end
            if protect.package.loaded[i] == LIB_LOAD then
                protect.package.loaded[i] = v
            end
        end
    end
end
-- save and clear env
local save_env = function(context, _G)
    -- V1 should save env manual
    if context.version == V1 then
        for i,v in pairs(_G) do
            context._G[i] = v
        end
    end
    if context.version == V2 then
        _G[context.id] = nil
    end
end
-- hook env for execute
local pre_hook = function(context, str)
    if context.version == V1 then
        return str
    end
    if context.version == V2 then
        local id = "_G_" .. math.random(0, 100000) .. os.time()
        context.id = id
        _G[id] = context._G
        return "-- execute at sandbox \nlocal _ENV = "..id.." \n" .. str  
    end
    error "unknow version"
end
-- create_context
local create_context = function(context_origin)
    local context = type(context_origin) == "table" and context_origin or {}
    context.version = context.version and context.version or V2
    context._G = context._G and context._G or {}
    setmetatable(context, {
        __index = function(table, name)
            return function() end
        end
    })
    if context_origin  == nil then
        return context
    end
    if type(context_origin) == "function" then
        context.init = context_origin
    end
    return context
end

-- protect_table
sandbox.protect_table = function(content)
    if type(content) ~= "table" then
        return content
    end
    local shell = {}
    setmetatable(shell, {
        __index = function(table, name)
            if content[name] == false  then return false end
            if not content[name]  then return nil end
            return sandbox.protect_table(content[name])
        end
    })
    return shell
end
local protect_table = sandbox.protect_table

local setEnv = function(context, code)
    return "local _ENV = " .. context.id .. " \n"..code
end

-- protect env for version
local protect_env = function(context)
    local protect = {
        print = print,
        io = io,
        debug = debug,
        os = os,
        loadfile = loadfile,
        dofile = dofile,
        package = package,
    }
    if context and type(context.protect) == "table" then
        -- copy the protect
        for i,v in pairs(context.protect) do
            protect[i] = v
        end
    end
    local protect_by_version = {
        [V1] = function(context) 
            for i in pairs(protect) do
                _G[i] = nil
                if protect.package.preload[i] then
                    protect.package.preload[i] = LIB_LOAD
                end
                if protect.package.loaded[i] then
                    protect.package.loaded[i] = LIB_LOAD
                end
            end
            delegate_os(protect.os)
            delegate_package(protect.package)
            delegate_loadfile(protect.loadfile)
            delegate_dofile(protect.dofile)
            return protect
        end,
        [V2] = function (context)
            context._G = context._G or {}
            local delegate  = {
                loadfile = function(path) return loadfile(patch_path(path)) end,
                dofile = function(path) return dofile(patch_path(path)) end,
                os = { time = os.time, date = os.date, clock = os.clock},
                io = {},
                package = {},
                load = function(code) return load(setEnv(context, code)) end
            }
            setmetatable(context._G,
                { __index = function(table, name)
                    if delegate[name] then return delegate[name] end
                    if not protect[name] and name ~= context.id then
                        return protect_table(_G[name])
                    end
                    return delegate[name]
                end
                }
                )
            return protect
        end
    }
    return protect_by_version[context.version](context)
end
-- library define
sandbox.run = function (func_str, context)
    local context = create_context(context)
    -- pre hook
    func_str = pre_hook(context, func_str)
    -- protect env
    local protect_env = protect_env(context)

    -- execute env context
    context:init(context._G)
    -- load function
    local fuc, err = (loadstring and loadstring or load)(func_str)
    -- init success and result
    local suc, res 
    if fuc then
        -- set loop protect in debug
        loop_protect(protect_env.debug)
        -- execute code
        do
            -- protect protect
            local protect 
            suc, res = pcall(fuc)
        end
        protect_env.debug.sethook()
    else
        res = err
        weechat.print(log_buff,"fail to load:"..func_str)
    end
    -- save environment
    save_env(context, _G)
    -- recovery env
    sandbox_recovery(context, protect_env, LIB_LOAD)
    -- format result
    if suc then
        res = (res and (">> " .. tostring(res)) or ">> (done)" ) .. os.date(" %w@%W")
        if context and type(context.info) == "function" then
            log.trace(log.dump(msg))
            --context.info(res)
        end
        return res
    else
        weechat.print(log_buff,"fail to execute:"..func_str)
        if context and type(context.error) == "function"  then
            context.error(res)
        end
        return ">> (error) " .. res
    end
end

-- execute main
__main__()

return sandbox
