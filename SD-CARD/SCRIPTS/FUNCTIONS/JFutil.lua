-- JF Library
-- Timestamp: 2019-09-13
-- Created by Jesper Frickmann
-- Has a few shared functions and variables for telemetry and functions scripts
-- Works together with a small shell script to load and unload program and telemetry scripts.
-- Method for loading and unloading telemetry scripts was provided by Guido ter Horst "l shems"

-- For loading and unloading of programs with the small shell script
local programs = {} -- List of loaded programs
local states = {} -- Program states are used for managing loading and unloading
local locked = false -- Lock to ensure that only one program is loaded at a time
local ST_WAITING = 0 -- Wait and mark other programs before loading
local ST_STANDBY = 1 -- Marked programs are swept; standing by for loading
local ST_LOADED = 2 -- Program loaded but not yet initialized
local ST_RUNNING = 3 -- Program is loaded, initialized, and running
local ST_MARKED = 4 -- Programs are marked inactive and swept if not running

-- Load a file chunk for Tx specific screen size
function LoadWxH(file, ...)
	-- Add the path to the files for radio's screen resolution
	file = string.format("/SCRIPTS/TELEMETRY/%ix%i/%s/", LCD_W, LCD_H, file)
	
	local chunk = loadScript(file)
	return chunk(...)
end  --  LoadWxH()

-- And now use it to load ransmitter specific global graphics functions
LoadWxH("JFutil.lua")

-- Unload a program
function Unload(file)
	programs[file] = nil
	states[file] = nil
	return collectgarbage()
end -- Unload()

-- Load program or forward run() call to the program
function RunLoadable(file, event, ...)
	if states[file] == nil then
		-- First, acquire the lock
		if locked then
			return
		else
			locked = true
		end
		
		-- Wait and sweep inactive programs before loading
		DrawMenu(" Loading . . .", 0, 0)

		-- Mark all programs as inactive
		for f in pairs(states) do
			states[f] = ST_MARKED
		end

		-- Except this one, which is waiting
		states[file] = ST_WAITING
	elseif states[file] == ST_WAITING then
		-- Sweep inactive programs
		for f, st in pairs(states) do
			if st == ST_MARKED then
				Unload(f)
			end
		end
		states[file] = ST_STANDBY
	elseif states[file] == ST_STANDBY then
		locked = false

		-- Load the program
		local chunk, err = loadScript(file) 

		if chunk then
			programs[file] = chunk(...)
			states[file] = ST_LOADED			
			return collectgarbage()
		else
			err = string.gsub(err, file .. ":", "")
			lcd.clear()
			lcd.drawText(0, 0, "ERROR loading the script:", SMLSIZE)
			lcd.drawText(0, 10, file, SMLSIZE)
			lcd.drawText(0, 20, err, SMLSIZE)
		end

	elseif states[file] == ST_LOADED then
		states[file] = ST_RUNNING

		-- Pass an init() call to the loaded program
		if programs[file].init then
			return programs[file].init()
		end
	elseif programs[file].run then
		states[file] = ST_RUNNING
		
		-- Pass on the run(event) call to the loaded program
		return programs[file].run(event)
	end
end -- RunLoadable()

-- Write the current flight mode to a telemetry sensor.
-- Create a sensor named "FM" with id 0x5050 in telemetry.
-- DIY DATA IDs 0x5000 - 0x52ff in opentx/radio/src/telemtry/frsky.h
local function run()
	local fm = getFlightMode()
	setTelemetryValue(0x5050, 0, 0, fm, 0, 0, "FM")
end -- run()

return {run = run}