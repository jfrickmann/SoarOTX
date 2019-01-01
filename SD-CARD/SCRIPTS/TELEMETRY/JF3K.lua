-- JF F3K Timing and score keeping, fixed part
-- Standalone version for third part Taranis models.
-- Timestamp: 2018-12-31
-- Created by Jesper Frickmann

wTmr = 0 -- Controls window timer with MIXES script
fTmr = 0 -- Controls flight timer with MIXES script
sk = { } -- List of variables shared between fixed and loadable parts

-- The following shared variables are redefined by loadable plugins:
sk.taskWindow = 0 -- Task window duration (zero counts up)
sk.launches = -1 -- Number of launches allowed, -1 for unlimited
sk.taskScores = 0 -- Number of scores in task
sk.finalScores = false -- Task scores are final

-- The following shared functions are redefined by the plugins:
sk.TargetTime = function() return 0 end -- Function setting target time for flight; will be re-defined by plugin
sk.Score = function() return end -- Function recording scores; will be re-defined by plugin
sk.Background = nil -- Optional function called by background() to do plugin business

-- Lua file to be loaded and unloaded with run() function
sk.menu = "/SCRIPTS/TELEMETRY/JF3K/MENU.lua" -- Menu file
sk.run = sk.menu -- Initially, run the menu file
sk.firstPlugin = 1 -- Plugin on first line of menu
sk.selectedPlugin = 1 -- Selected plugin in menu
sk.firstTask = 1 -- Task on first line of menu
sk.selectedTask = 0 -- Selected task in menu

-- Program states
sk.STATE_IDLE = 1 -- Task window not running
sk.STATE_PAUSE = 2 -- Task window paused, not flying
sk.STATE_FINISHED = 3 -- Task has been finished
sk.STATE_WINDOW = 4 -- Task window started, not flying
sk.STATE_READY = 5 -- Flight timer will be started when launch switch is released
sk.STATE_FLYING = 6 -- Flight timer started but flight not yet committed
sk.STATE_COMMITTED = 7 -- Flight timer started, and flight committed
sk.STATE_FREEZE = 8 -- Still committed, but freeze  the flight timer
sk.state = sk.STATE_IDLE -- Current program state

-- Other shared variables
sk.eowTimerStop = true -- Freeze timer automatically at the end of the window
sk.quickRelaunch = false -- Restart timer immediately
sk.scores = { } -- List of saved scores
sk.counts = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 15, 20, 30, 45, 60, 120, 180, 240} -- Flight timer countdown

-- Find dials for setting target time in Poker and height ceilings etc.
for input = 0, 31 do
	for line = 0,  model.getInputsCount(input) - 1 do
		local tbl = model.getInput(input, line)
		
		if tbl.name == "Mins" then
			sk.set1id = tbl.source
		end
		
		if tbl.name == "Secs" then
			sk.set2id = tbl.source
		end
	end
end

-- If input lines were not found, then default to S1 and S2
if not sk.set1id then sk.set1id = getFieldInfo("s1").id end
if not sk.set2id then sk.set2id = getFieldInfo("s2").id end

-- Local variables
local FM_LAUNCH = 1 -- Flight mode used for launch
local flightModeOld = getFlightMode() -- Used for detecting when FM changes
local winTimerOld -- Previous value of the window timer
local flightTimerOld -- Previous value of flight timer
local countIndex -- Index of timer count

-- Standalone version variables
local winT0 = 0 -- Start point of window timer
local flightT0 = 0 -- Start point of flight timer

-- Copied from JFutil,lua -----------------------------------------------------

-- Transmitter specific
TX_UNKNOWN = 0
TX_X9D = 1 
TX_QX7 = 2
TX_LITE = 3

do
	local ver, radio = getVersion()

	if string.find(radio, "x7") then -- Qx7
		tx = TX_QX7
		GRAY = 0
	elseif string.find(radio, "x9d") then -- X9D		
		tx = TX_X9D
		GRAY = GREY_DEFAULT
	elseif string.find(radio, "lite") then -- X-lite
		tx = TX_LITE
		GRAY = 0
	else
		tx = TX_UNKNOWN
	end
end

-- For loading and unloading of programs with the small shell script
local programs = {} -- List of loaded programs
local states = {} -- Program states are used for managing loading and unloading
local locked = false -- Lock to ensure that only one program is loaded at a time
local ST_WAITING = 0 -- Wait and mark other programs before loading
local ST_STANDBY = 1 -- Marked programs are swept; standing by for loading
local ST_LOADED = 2 -- Program loaded but not yet initialized
local ST_RUNNING = 3 -- Program is loaded, initialized, and running
local ST_MARKED = 4 -- Programs are marked inactive and swept if not running

-- Input value for the receiver battery
local RBat
do
	local batField = getFieldInfo("RBat")
	
	if batField then
		RBat = function()
			return getValue(batField.id)
		end
	else
		RBat = function()
			return 0
		end
	end
end

-- Draw the basic menu with border and title
if tx == TX_X9D then
	function DrawMenu(title)
		local now = getDateTime()
		local infoStr = string.format("%1.1fV %02d:%02d", RBat(), now.hour, now.min)

		lcd.clear()
		lcd.drawText(LCD_W, 0, infoStr, RIGHT)
		lcd.drawScreenTitle(title, 0, 0)
	end -- DrawMenu()
elseif tx == TX_QX7 or tx == TX_LITE then
	function DrawMenu(title)
		local now = getDateTime()
		local infoStr = string.format("%1.1fV %02d:%02d", RBat(), now.hour, now.min)

		lcd.clear()
		lcd.drawScreenTitle(title, 0, 0)
		lcd.drawText(LCD_W, 0, infoStr, RIGHT)
	end -- DrawMenu()
end

-- Unload a program
function Unload(file)
	programs[file] = nil
	states[file] = nil
	return collectgarbage()
end -- Unload()

-- Load program or forward run() call to the program
function RunLoadable(file, event)
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
			programs[file] = chunk()
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

-- End of JFutil.lua ---------------------------------------------------------

-- Function initializing flight timer
function InitializeFlight()
	local targetTime = sk.TargetTime()
	
	-- Get ready to count down
	countIndex = #sk.counts
	while countIndex > 1 and sk.counts[countIndex] >= targetTime do
		countIndex = countIndex - 1
	end

	-- Set flight timer
	model.setTimer(0, { start = targetTime, value = targetTime })
	sk.flightTimer = targetTime
	flightTimerOld = targetTime
end  --  InitializeFlight()

local function background()	
	local flightMode = getFlightMode()
	local launchPulled, launchReleased

	if flightMode == FM_LAUNCH and flightModeOld ~= FM_LAUNCH then
		launchPulled = true
	elseif flightMode ~= FM_LAUNCH and flightModeOld == FM_LAUNCH then
		launchReleased = true
	end
	
	if sk.state < sk.STATE_READY or sk.state == sk.STATE_FREEZE then
		-- Stop flight timer
		fTmr = 0
	end

	if sk.state <= sk.STATE_READY and sk.state ~= sk.STATE_FINISHED then
		InitializeFlight()
	end
	
	-- Standalone version timer control
	if sk.state ~= STATE_IDLE then
		local now = getTime()
		local flight_start = model.getTimer(0).start
		local win_start = model.getTimer(1).start
		
		-- Update window timer
		if wTmr == 0 then
			winT0 = 0
		elseif winT0 == 0 then
			winT0 = now - 100 * math.abs(win_start - sk.winTimer)
		end

		if winT0 > 0 then
			-- To emulate radio timer, count down for postive start value and count of for zero start value
			if win_start > 0 then
				sk.winTimer = win_start - math.floor((now - winT0) / 100)
			else
				sk.winTimer = math.floor((now - winT0) / 100)
			end
		end
		
		-- Override radio timer
		model.setTimer(1, { value = sk.winTimer })

		-- Update flight timer
		if fTmr == 0 or launchPulled then
			flightT0 = 0
		elseif flightT0 == 0 and sk.state > sk.STATE_READY then
			flightT0 = now
		end
		
		if flightT0 > 0 then
			-- To emulate radio timer, count down for postive start value and count of for zero start value
			if flight_start > 0 then
				sk.flightTimer = flight_start - math.floor((now - flightT0) / 100)
			else
				sk.flightTimer = math.floor((now - flightT0) / 100)
			end
		end
		
		-- Override radio timer
		model.setTimer(0, { value = sk.flightTimer })

		sk.flightTime = math.abs(flight_start - sk.flightTimer)
	end

	
	if sk.state < sk.STATE_WINDOW then
		-- Stop task window timer
		wTmr = 0
		
		if sk.state == sk.STATE_IDLE then
			-- Set window timer
			model.setTimer(1, { start = sk.taskWindow, value = sk.taskWindow })
			sk.winTimer = sk.taskWindow
			winTimerOld = sk.taskWindow

			-- Automatically start window and flight if launch switch is released
			if launchPulled then
				sk.state = sk.STATE_READY
			end
		end

	else
		-- Start task window timer
		wTmr = 1

		-- Beep at the beginning and end of the task window
		if (winTimerOld > 0 and sk.winTimer <= 0) or (winTimerOld > sk.taskWindow and sk.winTimer <= sk.taskWindow) then
			playTone(880, 1000, PLAY_NOW)
		end
	
		if sk.state == sk.STATE_WINDOW then
			if sk.winTimer <= 0 and model.getTimer(1).start > 0 then
				sk.state = sk.STATE_FINISHED
			elseif launchPulled then
				sk.state = sk.STATE_READY
			elseif launchReleased then
				-- Play tone to warn that timer is NOT running
				playTone(1760, 200, 0, PLAY_NOW)
			end
			
		elseif sk.state == sk.STATE_READY then
			-- Ready to start flight timer
			fTmr = 1

			if launchReleased then
				sk.state = sk.STATE_FLYING

				if model.getTimer(0).start > 0 then
					-- Report the target time
					playDuration(model.getTimer(0).start, 0)
				else
					-- ... or beep
					playTone(1760, 100, PLAY_NOW)
				end
			end

		elseif sk.state >= sk.STATE_FLYING then
			if sk.state < sk.STATE_FREEZE then
				-- If the window expires, then freeze the flight timer
				if sk.winTimer <= 0 and winTimerOld > 0 and sk.eowTimerStop then
					sk.state = sk.STATE_FREEZE
				end
			
				-- Is it time to count down?
				if sk.flightTimer <= sk.counts[countIndex] and flightTimerOld > sk.counts[countIndex]  then
					if sk.flightTimer > 15 then
						playDuration(sk.flightTimer, 0)
					else
						playNumber(sk.flightTimer, 0)
					end
					if countIndex > 1 then countIndex = countIndex - 1 end
				end
			end
			
			if sk.state == sk.STATE_FLYING then
				-- Within 5 sec. "grace period", cancel the flight
				if launchPulled then
					sk.state = sk.STATE_WINDOW
				end

				-- After 5 seconds, commit flight
				if sk.flightTime > 5 then
					sk.state = sk.STATE_COMMITTED

					if sk.launches > 0 then 
						sk.launches = sk.launches - 1
					end
				end
				
			elseif launchPulled then
				-- Report the time after flight is done
				if model.getTimer(0).start == 0 then
					playDuration(sk.flightTime, 0)
				end

				sk.Score()
				
				-- Change state
				if sk.winTimer <= 0 or (sk.finalScores and #sk.scores == sk.taskScores) or sk.launches == 0 then
					sk.state = sk.STATE_FINISHED
				elseif sk.quickRelaunch then
					sk.state = sk.STATE_READY
				else
					sk.state = sk.STATE_WINDOW
				end
			end			
		end
		
		winTimerOld = sk.winTimer
		flightTimerOld = sk.flightTimer
	end

	-- If loadable part provides a Background() function then execute it here
	if sk.Background then sk.Background() end
	
	flightModeOld = flightMode
end  --  background()

-- Forward run() call to the loadable part
local function run(event)
	return RunLoadable(sk.run, event)
end

return {background = background, run = run}