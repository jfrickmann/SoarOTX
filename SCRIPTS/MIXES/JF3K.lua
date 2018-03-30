-- Custom script for output of values from Lua to OpenTX
-- Timestamp: 2018-01-30
-- Created by Jesper Frickmann

local output = {"WTmr", "FTmr", "Adj"}

local function init()
	if not fTmr then fTmr = 0 end
	if not adj then adj = 0 end
end

local function run()
	if windowRunning then
		return 10.74, 10.24 * fTmr + 0.5, 10.24 * adj + 0.5
	else
		return 0, 0, 10.24 * adj + 0.5
	end
end

return{output = output, init = init, run = run}