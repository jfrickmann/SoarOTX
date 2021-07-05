-- JF Utility Library
-- Timestamp: 2021-07-05
-- Created by Jesper Frickmann

soarUtil = { } -- Global "namespace"
soarUtil.FM_ADJUST = 1 -- Adjustment flight mode
soarUtil.FM_LAUNCH = 2 -- Launch/motor flight mode
soarUtil.GV_BAT = 6 -- GV used for battery warning in FM_ADJUST

soarUtil.showHelp = (model.getGlobalVariable(4, 1) == 1) -- Show help text in screens
soarUtil.bat = 0 -- Battery sensor
soarUtil.alt = 0 -- Altimeter sensor
soarUtil.altMax = 0 -- Max. alt.
soarUtil.altUnit = 9 -- Altitude units (m)
soarUtil.callAlt = false -- Call altitude every 10 sec.

-- For loading and unloading of programs with the small shell script
local programs = {} -- List of loaded programs
local states = {} -- Program states are used for managing loading and unloading
local locked = false -- Lock to ensure that only one program is loaded at a time
local ST_WAITING = 0 -- Wait and mark other programs before loading
local ST_STANDBY = 1 -- Marked programs are swept; standing by for loading
local ST_LOADED = 2 -- Program loaded but not yet initialized
local ST_RUNNING = 3 -- Program is loaded, initialized, and running
local ST_MARKED = 4 -- Programs are marked inactive and swept if not running

-- For telemetry
local idBat -- Id of battery sensor
local nextWarning = 0 -- Timer between low battery warnings
local afterLaunch = 0 -- Time period after launch where battery warning threshold is lowered
local rescan = 0 -- Rescan battery sensor, because Cels can be a little slow getting started

local idAlt -- Id of altimeter sensor
local nextCall = 0 -- Timer between altitude announcements
local UpdateAlt -- Update altitude reading
local zeroAlt = 0 -- Internal zero'ing of altimetry

-- From OpenTX 2.3.11 we can reset Alt from Lua:
do
	local ver, radio, maj, minor, rev = getVersion() -- TODO remove legacy
	
	if maj >= 2 and ((minor >= 3 and rev >= 11) or minor >= 4) then
		zeroAlt = nil
		idAlt = nil
		
		-- Reset altimeter
		function soarUtil.ResetAlt()
			for i = 0, 31 do
				if model.getSensor(i).name == "Alt" then 
					model.resetSensor(i)
					break
				end
			end
		end

		-- Read altimeter
		UpdateAlt = function()
			soarUtil.alt = getValue("Alt")
			soarUtil.altMax = getValue("Alt+")
		end
		
	else -- Otherwise, zero alt internally in this program
	
		-- Reset internal altimeter
		function soarUtil.ResetAlt()
			zeroAlt = soarUtil.alt + zeroAlt
			soarUtil.alt = 0
			soarUtil.altMax = 0
		end
		
		UpdateAlt = function()
			soarUtil.alt = getValue("Alt") - zeroAlt

			if soarUtil.alt > soarUtil.altMax then
				soarUtil.altMax = soarUtil.alt
			end
			
			-- Create a zero'd Alti sensor
			setTelemetryValue(0x5051, 0, 224, soarUtil.alt, 0, 0, "Alti") 
		end
	end
end

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
			lcd.drawText(0, 8, "ERROR loading the script: ", SMLSIZE)
			lcd.drawText(0, 16, file, SMLSIZE)
			lcd.drawText(0, 24, err, SMLSIZE)
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

-- Set timer GV
function soarUtil.SetGVTmr(tmr)
	model.setGlobalVariable(8, 0, tmr)
end


-- Show or hide help text
function soarUtil.ToggleHelp(event)
	if event == EVT_VIRTUAL_MENU then
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

local function run()
	local now = getTime()
	
	-- Write the current flight mode to a telemetry sensor.
	local flightMode = getFlightMode()
	setTelemetryValue(0x5050, 0, 224, flightMode, 0, 0, "FM")
	
	-- Battery sensor
	if now > rescan then
		local field = getFieldInfo("Cels")
		if not field then field = getFieldInfo("RxBt") end
		if not field then field = getFieldInfo("A1") end
		if not field then field = getFieldInfo("A2") end
		
		if field then
			idBat = field.id
			rescan = now + 1000 -- Rescan every 10 sec.
		end
	end

	if idBat then
		local bat = getValue(idBat)
		
		if type(bat) == "table" then
			for i = 2, #bat do
				bat[1] = math.min(bat[1], bat[i])
			end

			soarUtil.bat = bat[1]
		else
			soarUtil.bat = bat
		end
	end
	
	-- Battery warnings
	if now > nextWarning then		
		local lowBat = 0.1 * model.getGlobalVariable(soarUtil.GV_BAT, soarUtil.FM_ADJUST)

		if flightMode == soarUtil.FM_LAUNCH then
			if soarUtil.bat == 0 then
				-- Warning in launch mode - is the plane off?
				playHaptic(200, 0, 1)
				playFile("lowbat.wav")
				nextWarning = now + 500
			else
				afterLaunch = now + 300
			end
		end
		
		-- If motor draws on the same battery
		if now < afterLaunch then
			lowBat = 0.9 * lowBat
		end

		if soarUtil.bat > 0 and soarUtil.bat < lowBat then
			-- Low battery warning
			playFile("lowbat.wav")
			playNumber(10 * soarUtil.bat + 0.5, 1, PREC1)
			nextWarning = now + 2000
		end
	end
	
	-- Altimeter sensor
	UpdateAlt()
	
	if soarUtil.callAlt and now > nextCall then
		playNumber(soarUtil.alt, soarUtil.altUnit)
		nextCall = now + 1000
	end
end -- run()

return {run = run}