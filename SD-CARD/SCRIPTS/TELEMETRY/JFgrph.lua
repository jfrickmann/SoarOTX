-- JF Autoloader
-- Timestamp: 2019-04-28
-- Created by Jesper Frickmann
-- Telemetry script for automatically loading and unloading telemetry scripts
-- Depends on library functions in FUNCTIONS/JFLib.lua

local status = 0 -- 0 = has been reset, 1 = running, 2 = needs to be reset to save memory

local function init()
	gr = { } 	-- List of shared variables for graphing
	gr.read = "/SCRIPTS/TELEMETRY/JF/GRREAD.lua" -- Lua file to be loaded and unloaded for reading data
	gr.run = gr.read -- Loadable file currently being run
end

local function background()
	if status == 1 then
		status = 2
	elseif status == 2 then -- If run() has not run in between, init() to save memory
		Unload(gr.run)
		init()
		status = 0
		return collectgarbage()
	end
end

local function run(event)
	status = 1

	if RunLoadable(gr.run, event) then
		-- Unload to reload GRREAD if scanning is done and we start reading the first flight
		Unload(gr.run)
	end
end

return { init = init, background = background, run = run }