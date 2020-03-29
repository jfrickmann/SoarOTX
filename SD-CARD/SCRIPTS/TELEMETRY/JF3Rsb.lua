-- JF Autoloader
-- Timestamp: 2019-10-17
-- Created by Jesper Frickmann
-- Telemetry script for automatically loading and unloading telemetry scripts
-- Depends on library functions in FUNCTIONS/JFLib.lua

local myFile = "/SCRIPTS/TELEMETRY/JF3R/SB.lua" -- Lua file to be loaded and unloaded

local function run(event)
	soarUtil.ToggleHelp(event)
	return soarUtil.RunLoadable(myFile, event)
end

return {run = run}
