-- Custom script for output of values from Lua to OpenTX
-- Timestamp: 2020-04-08
-- Created by Jesper Frickmann

local output = {"WTmr", "FTmr", "Adj", "Lnch"}

local function init()
	if not wTmr then wTmr = 0 end
	if not fTmr then fTmr = 0 end
	if not adj then adj = 0 end
	if not launch then launch = 0 end
end

local function run()
	return 10.24 * wTmr + 0.5, 10.24 * fTmr + 0.5, 10.24 * adj + 0.5, 10.24 * launch + 0.5
end

return{output = output, init = init, run = run}