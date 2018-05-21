-- JF Autoloader
-- Timestamp: 2018-05-21
-- Created by Jesper Frickmann
-- Telemetry script for automatically loading and unloading telemetry scripts
-- Depends on library functions in FUNCTIONS/JFLib.lua

local myFile = "/SCRIPTS/TELEMETRY/JF3JsbLd.lua" -- Lua file to be loaded and unloaded

local function run(event)
	return LdRun(myFile, event)
end

return {run = run}
