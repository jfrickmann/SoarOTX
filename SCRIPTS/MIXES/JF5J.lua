-- Custom script for output of values from Lua to OpenTX
-- Timestamp: 2018-01-06
-- Created by Jesper Frickmann

local output = {"Tmr", "Adj"}

local function init()
	if not tmr then tmr = 0 end
	if not adj then adj = 0 end
end

local function run()
	return 10.24 * tmr + 0.5, 10.24 * adj + 0.5
end

return{output = output, init = init, run = run}