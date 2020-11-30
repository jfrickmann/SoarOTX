-- JF F3K Timing and score keeping, fixed part
-- Timestamp: 2020-11-24
-- Created by Jesper Frickmann
-- Depends on library functions in FUNCTIONS/JFLib.lua

local LS_ALT = getFieldInfo("ls1").id -- Input ID for allowing altitude calls
local LS_ALT10 = getFieldInfo("ls6").id -- Input ID for altitude calls every 10 sec.

local prevFM = getFlightMode() -- Used for detecting when FM changes
local prevWt -- Previous value of the window timer
local prevFt -- Previous value of flight timer
local countIndex -- Index of timer count
local sk = { }

-- List of variables shared between fixed and loadable parts
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
sk.selectedPlugin = 1 -- Selected plugin in menu
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
sk.counts = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 15, 20, 30, 45} -- Flight timer countdown

-- Find dials for setting target time in Poker and height ceilings etc.
for input = 0, 31 do
	local tbl = model.getInput(input, 0)
	
	if tbl and tbl.name == "Dial" then
		sk.dial = tbl.source
	end
end

-- If input lines were not found, then default to S1 and S2
if not sk.dial then sk.dial = getFieldInfo("s1").id end

-- Make sure that timers are stopped
soarUtil.SetGVTmr(0)

-- Function initializing flight timer
local function InitializeFlight()
	local targetTime = sk.TargetTime()
	
	-- Get ready to count down
	countIndex = #sk.counts
	while countIndex > 1 and sk.counts[countIndex] >= targetTime do
		countIndex = countIndex - 1
	end

	-- Set flight timer
	model.setTimer(0, { start = targetTime, value = targetTime })
	sk.flightTimer = targetTime
	prevFt = targetTime
end  --  InitializeFlight()

local function background()	
	local flightMode = getFlightMode()
	local launchPulled = (flightMode == soarUtil.FM_LAUNCH and prevFM ~= flightMode)
	local launchReleased = (flightMode ~= prevFM and prevFM == soarUtil.FM_LAUNCH)
	prevFM = flightMode

	if launchPulled then -- Reset altitude
		soarUtil.ResetAlt()
	end
	
	soarUtil.callAlt = (getValue(LS_ALT10) > 0) -- Call alt every 10 sec.

	if sk.state <= sk.STATE_READY and sk.state ~= sk.STATE_FINISHED then
		InitializeFlight()
	end
	
	sk.flightTimer = model.getTimer(0).value
	sk.flightTime = math.abs(model.getTimer(0).start - sk.flightTimer)
	sk.winTimer = model.getTimer(1).value
	
	if sk.state < sk.STATE_WINDOW then
		if sk.state == sk.STATE_IDLE then
			-- Set window timer
			model.setTimer(1, { start = sk.taskWindow, value = sk.taskWindow })
			sk.winTimer = sk.taskWindow
			prevWt = sk.taskWindow

			-- Automatically start window and flight if launch switch is released
			if launchPulled then
				sk.state = sk.STATE_READY
			end
		end

	else
		-- Did the window expire?
		if prevWt > 0 and sk.winTimer <= 0 then
			playTone(880, 1000, 0)

			if sk.state < sk.STATE_FLYING then
				sk.state = sk.STATE_FINISHED
			elseif sk.eowTimerStop then
				sk.state = sk.STATE_FREEZE
			end
		end

		if sk.state == sk.STATE_WINDOW then
			if launchPulled then
				sk.state = sk.STATE_READY
			elseif launchReleased then
				-- Play tone to warn that timer is NOT running
				playTone(1760, 200, 0, PLAY_NOW)
			end
			
		elseif sk.state == sk.STATE_READY then
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
			-- Time counts
			if sk.flightTimer <= sk.counts[countIndex] and prevFt > sk.counts[countIndex]  then
				if sk.flightTimer > 15 then
					playDuration(sk.flightTimer, 0)
				else
					playNumber(sk.flightTimer, 0)
				end
				if countIndex > 1 then countIndex = countIndex - 1 end
			elseif sk.flightTimer > 0 and math.ceil(sk.flightTimer / 60) < math.ceil(prevFt / 60) then
				playDuration(sk.flightTimer, 0)
			end
			
			if sk.state == sk.STATE_FLYING then
				-- Within 10 sec. "grace period", cancel the flight
				if launchPulled then
					sk.state = sk.STATE_WINDOW
				end

				-- After 5 seconds, commit flight
				if sk.flightTime >= 10 then
					sk.state = sk.STATE_COMMITTED

					-- Call launch height
					if getValue(LS_ALT) > 0 then
						playNumber(soarUtil.altMax, soarUtil.altUnit)
					end
					
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
				if (sk.finalScores and #sk.scores == sk.taskScores) or sk.launches == 0
				or (sk.taskWindow > 0 and sk.winTimer <= 0) then
					playTone(880, 1000, 0)
					sk.state = sk.STATE_FINISHED
				elseif sk.quickRelaunch then
					sk.state = sk.STATE_READY
				else
					sk.state = sk.STATE_WINDOW
				end
			end			
		end
		
		prevWt = sk.winTimer
		prevFt = sk.flightTimer
	end

	if sk.state < sk.STATE_WINDOW or sk.state == sk.STATE_FREEZE then
		-- Stop both timers
		soarUtil.SetGVTmr(0)
	elseif sk.state == sk.STATE_WINDOW then
		-- Start task window timer, but not flight timer
		soarUtil.SetGVTmr(1)
	elseif sk.state == sk.STATE_FLYING then
		-- Start both timers
		soarUtil.SetGVTmr(2)
	end

	-- If loadable part provides a Background() function then execute it here
	if sk.Background then sk.Background() end	
end  --  background()

-- Forward run() call to the loadable part
local function run(event)
	soarUtil.ToggleHelp(event)
	return soarUtil.RunLoadable(sk.run, event, sk)
end

return {background = background, run = run}