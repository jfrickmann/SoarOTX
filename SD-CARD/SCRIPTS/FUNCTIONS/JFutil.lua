-- JF Utility Library
-- Timestamp: 2020-04-12
-- Created by Jesper Frickmann

soarUtil = { } -- Global "namespace"
soarUtil.showHelp = (model.getGlobalVariable(4, 1) == 1) -- Show help text in screens

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
function soarUtil.LoadWxH(file, ...)
	-- Add the path to the files for radio's screen resolution
	local file = string.format("/SCRIPTS/TELEMETRY/%ix%i/%s/", LCD_W, LCD_H, file)
	
	local chunk = loadScript(file)
	return chunk(...)
end  --  LoadWxH()

-- And now use it to load ransmitter specific global graphics functions
soarUtil.LoadWxH("JFutil.lua")

-- Unload a program
function soarUtil.Unload(file)
	programs[file] = nil
	states[file] = nil
	return collectgarbage()
end -- Unload()

-- Load program or forward run() call to the program
function soarUtil.RunLoadable(file, event, ...)
	if states[file] == nil then
		-- First, acquire the lock
		if locked then
			return
		else
			locked = true
		end
		
		-- Wait and sweep inactive programs before loading
		soarUtil.InfoBar(" Loading . . .", 0, 0)

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
				soarUtil.Unload(f)
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
			print(0, 0, "ERROR loading the script: ", file, " ", err)
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

-- Key event handlers
function soarUtil.EvtEnter(event)
	return event == EVT_ENTER_BREAK
end -- EvtEnter()

function soarUtil.EvtExit(event)
	return event == EVT_EXIT_BREAK
end -- EvtExit()

function soarUtil.EvtInc(event)
	return event == EVT_PLUS_BREAK or event == EVT_PLUS_REPT or event == EVT_ROT_RIGHT or event == EVT_UP_BREAK
end -- EvtInc()

function soarUtil.EvtDec(event)
	return event == EVT_MINUS_BREAK or event == EVT_MINUS_REPT or event == EVT_ROT_LEFT or event == EVT_DOWN_BREAK
end -- EvtDec()

function soarUtil.EvtRight(event)
	return event == EVT_PLUS_BREAK or event == EVT_PLUS_REPT or event == EVT_ROT_RIGHT or event == EVT_RIGHT_BREAK
end -- EvtRight()

function soarUtil.EvtLeft(event)
	return event == EVT_MINUS_BREAK or event == EVT_MINUS_REPT or event == EVT_ROT_LEFT or event == EVT_LEFT_BREAK
end -- EvtLeft()

function soarUtil.EvtUp(event)
	return event == EVT_PLUS_BREAK or event == EVT_PLUS_REPT or event == EVT_ROT_LEFT or event == EVT_UP_BREAK
end -- EvtUp()

function soarUtil.EvtDown(event)
	return event == EVT_MINUS_BREAK or event == EVT_MINUS_REPT or event == EVT_ROT_RIGHT or event == EVT_DOWN_BREAK
end -- EvtDown()

-- Some radios do not have MENU and SHIFT buttons
if not (EVT_MENU_BREAK or EVT_SHIFT_BREAK) and EVT_LEFT_BREAK then
	EVT_MENU_BREAK = bit32.bor(EVT_LEFT_BREAK, EVT_RIGHT_BREAK)
end

-- Show or hide help text
function soarUtil.ToggleHelp(event)
	if event == EVT_MENU_BREAK or event == EVT_SHIFT_BREAK then
		local sh = 1 - model.getGlobalVariable(4, 1)
		model.setGlobalVariable(4, 1, sh)
		soarUtil.showHelp = (sh == 1)
	end
end -- ToggleHelp()

-- Return timer as text string
function soarUtil.TmrStr(secs)
	local m = math.floor(secs / 60)
	local s = secs - 60 * m
	return string.format("%02i:%02i", m, s)
end -- TmrStr()

-- Write the current flight mode to a telemetry sensor.
-- Create a sensor named "FM" with id 0x5050 in telemetry.
-- DIY DATA IDs 0x5000 - 0x52ff in opentx/radio/src/telemtry/frsky.h
local function run()
	local fm = getFlightMode()
	setTelemetryValue(0x5050, 0, 0, fm, 0, 0, "FM")
end -- run()

return {run = run}