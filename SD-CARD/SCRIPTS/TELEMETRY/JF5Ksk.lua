-- JF F5K Timing and score keeping, fixed part
-- Timestamp: 2020-04-xx
-- Created by Jesper Frickmann
-- Depends on library functions in FUNCTIONS/JFLib.lua

wTmr = 0 -- Controls window timer with MIXES script
fTmr = 0 -- Controls flight timer with MIXES script

 -- List of variables shared between fixed and loadable parts
local sk = { }
sk.taskWindow = 0 -- Task window duration (zero counts up)
sk.launches = -1 -- Number of launches allowed, -1 for unlimited
sk.taskScores = 0 -- Number of scores in task
sk.finalScores = false -- Task scores are final

-- The following shared functions are redefined by the plugins:
sk.TargetTime = function() return 0 end -- Function setting target time for flight; will be re-defined by plugin
sk.Score = function() return end -- Function recording scores; will be re-defined by plugin
sk.Background = nil -- Optional function called by background() to do plugin business

-- Lua file to be loaded and unloaded with run() function
sk.menu = "/SCRIPTS/TELEMETRY/JF5K/MENU.lua" -- Menu file
sk.run = sk.menu -- Initially, run the menu file
sk.selectedPlugin = 1 -- Selected plugin in menu
sk.selectedTask = 0 -- Selected task in menu

-- Program states
sk.STATE_IDLE = 1 -- Task window not running
sk.STATE_PAUSE = 2 -- Task window paused, not flying
sk.STATE_FINISHED = 3 -- Task has been finished
sk.STATE_WINDOW = 4 -- Task window started, not flying
sk.STATE_LAUNCHING = 5 -- Motor launch and 10 sec. zoom
sk.STATE_FLYING = 6 -- Flight timer started but flight not yet committed
sk.STATE_FREEZE = 7 -- Freeze the flight timer when window ends
sk.state = sk.STATE_IDLE -- Current program state

-- Other shared variables
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

-- Local variables
local FM_MOTOR = 1 -- Flight mode used for motor
local altiId = getFieldInfo("Alti+").id -- Input ID for the Alti sensor
local triggerId = getFieldInfo("ls7").id -- Input ID for the trigger switch

local motorOld = getFlightMode() == FM_MOTOR -- Used for detecting when FM changes
local triggerOld = getValue(triggerId) > 0 -- Used for detecting when trigger is pulled
local altiTime = 0 -- Time to record start height
local winTimerOld -- Previous value of the window timer
local flightTimerOld -- Previous value of flight timer
local countIndex -- Index of timer count

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
	local motorStarted, motorStopped, triggerPulled

	motorStarted = getFlightMode() == FM_MOTOR
	motorOld, motorStarted, motorStopped = motorStarted, motorStarted and not motorOld, not motorStarted and motorOld

	triggerPulled = getValue(triggerId) > 0
	triggerOld, triggerPulled = triggerPulled, triggerPulled and not triggerOld
	
	if sk.state == sk.STATE_IDLE or (sk.state >= sk.STATE_WINDOW and sk.state <= sk.STATE_FLYING) then
		-- Allow flight timer to run
		fTmr = 1
	else
		fTmr = 0
	end

	if sk.state <= sk.STATE_WINDOW and sk.state ~= sk.STATE_FINISHED then
		InitializeFlight()
	end
	
	sk.flightTimer = model.getTimer(0).value
	sk.flightTime = math.abs(model.getTimer(0).start - sk.flightTimer)
	sk.winTimer = model.getTimer(1).value
	
	if sk.state < sk.STATE_WINDOW then
		-- Stop task window timer
		wTmr = 0
		
		if sk.state == sk.STATE_IDLE then
			-- Set window timer
			model.setTimer(1, { start = sk.taskWindow, value = sk.taskWindow })
			sk.winTimer = sk.taskWindow
			winTimerOld = sk.taskWindow

			-- Automatically start window and flight if motor is started
			if motorStarted then
				sk.state = sk.STATE_LAUNCHING
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
			-- Ready to start flight timer
			fTmr = 1

			-- Did the window expire?
			if sk.winTimer <= 0 and model.getTimer(1).start > 0 then
				playTone(880, 1000, 0)
				sk.state = sk.STATE_FINISHED

			elseif motorStarted then
				sk.state = sk.STATE_LAUNCHING

				if model.getTimer(0).start > 0 then
					-- Report the target time
					playDuration(model.getTimer(0).start, 0)
				else
					-- ... or beep
					playTone(1760, 100, PLAY_NOW)
				end

				if sk.launches > 0 then 
					sk.launches = sk.launches - 1
				end
			end

		elseif sk.state == sk.STATE_LAUNCHING then
			if motorStopped then
				-- Mark time to record start height
				altiTime = getTime() + 1000

			elseif altiTime > 0 and getTime() > altiTime then
				-- Record the start height
				local alti = getValue(altiId)
				if alti == 0 then alti = 50 end -- If no altimeter; default to 50
				sk.startHeight = alti
				altiTime = 0
				
				sk.state = sk.STATE_FLYING
			end
				
		elseif sk.state == sk.STATE_FLYING then
			-- If the window expires, then freeze the flight timer
			if sk.winTimer <= 0 and winTimerOld > 0 then
				sk.state = sk.STATE_FREEZE
			end
			
			-- Time counts
			if sk.flightTimer <= sk.counts[countIndex] and flightTimerOld > sk.counts[countIndex]  then
				if sk.flightTimer > 15 then
					playDuration(sk.flightTimer, 0)
				else
					playNumber(sk.flightTimer, 0)
				end
				if countIndex > 1 then countIndex = countIndex - 1 end
			elseif math.ceil(sk.flightTimer / 60) < math.ceil(flightTimerOld / 60) then
				playDuration(sk.flightTimer, 0)
			end

			if triggerPulled then
				if motorStarted then
					-- Record a zero score!
					sk.flightTime = 0
				elseif model.getTimer(0).start == 0 then
					-- Report the time after flight is done
					playDuration(sk.flightTime, 0)
				end

				sk.Score()
				
				-- Change state
				if (sk.finalScores and #sk.scores == sk.taskScores) or sk.launches == 0 then
					playTone(880, 1000, 0)
					sk.state = sk.STATE_FINISHED
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
end  --  background()

-- Forward run() call to the loadable part
local function run(event)
	soarUtil.ToggleHelp(event)
	return soarUtil.RunLoadable(sk.run, event, sk)
end

return {background = background, run = run}