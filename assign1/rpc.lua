local util = require("common.util")
local posix = require("posix")
local Pipe = util.Pipe
local mod = {}

function mod.serialize(t)
	-- nil to nil
	-- true to true, false to false
	-- string abcd"{( to "abcd\"@{\{"
    -- number to number
    -- {["foo"]="bar",t={}, [1] = 2} to ("foo"=bar)("t"=())(1=2)
    -- support float, empty string and string
    -- support visual-same non-string and string index
	local rst = ""
	-- character "() is used for paser, so convert 
	-- these char in origin string variable
    function escape_char(s)
        local t = string.gsub(s, "\"", "\\\"")
        t = string.gsub(t, "{", "@{")
        t = string.gsub(t, "}", "@}")
        t = string.gsub(t, "%(", "\\{")
        t = string.gsub(t, "%)", "\\}")
        return t
    end
    function pr(t)
		if type(t) == "table" then
			-- check is t is an empty table
            local not_empty = false
            for k, v in pairs(t) do
                if type(k) == "string" then
                    rst = rst .. "(\"" .. escape_char(k) .. "\"="
                elseif k == true then
                    rst = rst .. "(true="
                elseif k == false then
                    rst = rst .. "(false="
                else
                    -- k is number
                    rst = rst .. "(" .. k .. "="
                end
                pr(v)
                rst = rst .. ")"
                not_empty = true
            end
            if not not_empty then
                rst = rst .. "()"
            end
        elseif type(t) == "number" then
            rst = rst .. tostring(t)
        elseif type(t) == "string" then
            rst = rst .. "\"" .. escape_char(t) .. "\""
        elseif type(t) == "boolean" then
            if t == true then
                rst = rst .. "true"
            else
                rst = rst .. "false"
            end
        elseif t == nil then
            rst = rst .. "nil"
        end
    end
    pr(t, 0)
    return rst
	-- return nil
end


-- split by the first occurance
function mod.split2(str, pat) 
	local words = {}
	idx = string.find(str, pat)
	if idx == nil then
		return words
	end
	table.insert(words, string.sub(str, 1, idx - 1))
	table.insert(words, string.sub(str, idx + 1))
	return words
end


function mod.deserialize(s)
	-- Your code here
	function escape_char_undo(s)
        local t = string.gsub(s, "\\}", ")")
        t = string.gsub(t, "\\{", "(")
        t = string.gsub(t, "\\\"", "\"")
        t = string.gsub(t, "@{", "{")
        t = string.gsub(t, "@}", "}")
        return t
    end
	-- table here can not be simply appended like string
	-- so each time pr is used, it returns its part.
	-- rst is a local variable inside pr
    function pr(s)
        local rst = nil
        if s:sub(1, 1) == "(" then
            rst = {}
            for t in string.gmatch(s, "%b()") do
                t = t:sub(2, -2)
                if t == "" then
                    return rst
                elseif t:sub(1, 1) == "\"" then
                    local idx = 2
                    -- now t is "string"  =something
                    --          ↑↑     ↑           ↑
                    --          12    idx         -1 
                    while t:sub(idx, idx) ~= "\"" or t:sub(idx - 1, idx - 1) == "\\" do
                        idx = idx + 1
                    end
                    rst[escape_char_undo(t:sub(2, idx - 1))] = pr(t:sub(idx + 2, -1))
                elseif t:sub(1, 4) == "true" then
                    rst[true] = pr(t:sub(6, -1))
                elseif t:sub(1, 5) == "false" then
                    rst[false] = pr(t:sub(7, -1))
                else
                    local idx = 1
                    while t:sub(idx, idx) ~= "=" do
                        idx = idx + 1
                    end
                    rst[tonumber(t:sub(1, idx - 1))] = pr(t:sub(idx + 1, -1))
                end
            end
		elseif s:sub(1, 1) == "\"" then
			-- string
            rst = escape_char_undo(s:sub(2, -2))
        elseif s == "true" then
            rst = true
        elseif s == "false" then
            rst = false
        elseif s == "nil" then
            rst = nil
        else
            rst = tonumber(s)
        end
        return rst
    end
    return pr(s)
	-- return nil
end

function tablelength(T)
	local count = 0
	for _ in pairs(T) do
		count = count + 1
	end
	return count
end


function mod.rpcify(class)
	local MyClassRPC = {}
	
    function MyClassRPC.exit(r_inst)
        Pipe.write(r_inst.to_child_pipe, mod.serialize({name = "exit", args = ""}))
        posix.wait(pid)
    end
	-- for each method in class, make its RPC version
    for k, v in pairs(class) do
        if type(v) == "function" then
            if k == "new" then
                -- create method "new"
                MyClassRPC["new"] = function(...)
                    local to_child_pipe = Pipe.new()
                    local to_parent_pipe = Pipe.new()
                    local pid = posix.fork()
                    if pid == 0 then
                        -- child here
                        -- print("child activated") -- for debug
                        local inst = class.new(...)
                        while true do
                            local cmd_str = Pipe.read(to_child_pipe)
                            local cmd = mod.deserialize(cmd_str)
                            -- print("child receives cmd " .. cmt_str) -- for debug
                            if cmd.name == "exit" then
                                os.exit()
                            else
                                local return_val = class[cmd.name](inst, table.unpack(cmd.args))
                                local return_str = mod.serialize(return_val)
                                -- print("child: executed " .. cmd.name .. " and return " .. return_str) -- for debug
                                Pipe.write(to_parent_pipe, return_str)
                            end
                        end
                    else
                        -- parent here 
                        -- should return a handle
                        return {to_child_pipe = to_child_pipe, to_parent_pipe = to_parent_pipe}
                    end
                end
            else
                -- create other methods
                MyClassRPC[k] = function(t, ...) 
                    cmd = mod.serialize({name = k, args = {...}})
                    -- print("host passes cmd " .. cmd) -- for debug
                    Pipe.write(t.to_child_pipe, cmd)
                    local return_str = Pipe.read(t.to_parent_pipe)
                    -- print("host receives result of " .. k .. ", which is " .. return_str) -- for debug
                    return mod.deserialize(return_str)
                end
                MyClassRPC[k .. "_async"] = function(t, ...)
                    local args = {...}
                    function ret()
                        return MyClassRPC[k](t, table.unpack(args))
                    end
                    return ret
                end
            end
        end
    end
	return MyClassRPC 
end


return mod
