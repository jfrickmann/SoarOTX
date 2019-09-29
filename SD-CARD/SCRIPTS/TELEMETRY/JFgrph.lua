-- JF Autoloader
-- Timestamp: 2019-09-29
-- Created by Jesper Frickmann
-- Telemetry script for automatically loading and unloading telemetry scripts
-- Depends on library functions in FUNCTIONS/JFLib.lua

local status = 0 -- 0 = has been reset, 1 = running, 2 = needs to be reset to save memory
local gr -- List of shared variables for graphing

local function init()
	gr = { }
	gr.read = "/SCRIPTS/TELEMETRY/JF/GRREAD.lua"
	gr.graph = string.format("/SCRIPTS/TELEMETRY/%ix%i/JF/GRAPH.lua", LCD_W, LCD_H)
	gr.run = gr.graph
end

local function background()
	if status == 1 then
		status = 2
	elseif status == 2 then -- If run() has not run in between, init() to save memory
		soarUtil.Unload(gr.run)
		init()
		status = 0
		return collectgarbage()
	end
end

local function run(event)
	status = 1

	if soarUtil.RunLoadable(gr.run, event, gr) then
		-- Unload to reload GRREAD if scanning is done and we start reading the first flight
		soarUtil.Unload(gr.run)
	end
end

return { init = init, background = background, run = run }