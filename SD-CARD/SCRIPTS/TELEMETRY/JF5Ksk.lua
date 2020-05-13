-- JF F5K Timing and score keeping, fixed part
-- Timestamp: 2020-05-13
-- Created by Jesper Frickmann
-- Depends on library functions in FUNCTIONS/JFLib.lua

local LS_ALT = getFieldInfo("ls1").id -- Input ID for allowing altitude calls
local LS_ALT10 = getFieldInfo("ls7").id -- Input ID for altitude calls every 10 sec.
local LS_TRIGGER = getFieldInfo("ls8").id -- Input ID for the trigger switch
local LS_ARM = getFieldInfo("ls22").id -- Input ID for motor arming

local FlashArmed = soarUtil.LoadWxH("ARMED.lua") -- Screen size specific warning function
local prevMotor = (getFlightMode() == soarUtil.FM_LAUNCH) -- Used for detecting when FM changes
local prevTrigger = getValue(LS_TRIGGER) > 0 -- Used for detecting when trigger is pulled
local altTime = 0 -- Time to record start height
local prevWt -- Previous value of the window timer
local prevFt -- Previous value of flight timer
local prevArm = (getValue(LS_ARM) > 0) -- Previous arming state
local countIndex -- Index of timer count
local sk = { }

 -- List of variables shared between fixed and loadable parts
sk.taskWindow = 0 -- Task window duration (zero counts up)
sk.launches = -1 -- Number of launches allowed, -1 for unlimited
sk.taskScores = 0 -- Number of scores in task
sk.finalScores = false -- Task scores are final
sk.startHeight = 0 -- Start height

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
sk.STATE_FINISHED = 2 -- Task has been finished
sk.STATE_PAUSE = 3 -- Task window paused, not flying
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

-- Functions for getting and setting launch height
function sk.GetStartHeight()
	return model.getGlobalVariable(6, 0) 
end -- GetStartHeight()

function sk.SetStartHeight(height)
	model.setGlobalVariable(6, 0, height)
end -- SetStartHeight()

-- Global variable stops motor at cutoff altitude
local function MotorStop(x)
	model.setGlobalVariable(6, soarUtil.FM_LAUNCH, x)
end -- MotorStop()

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

soarUtil.SetGVTmr(0) -- Flight timer off
MotorStop(0) -- Allow motor to run

local function background()	
	local motorStarted, motorStopped, triggerPulled, armedNow

	motorStarted = (getFlightMode() == soarUtil.FM_LAUNCH)
	prevMotor, motorStarted, motorStopped = motorStarted, (motorStarted and not prevMotor), (not motorStarted and prevMotor)

	triggerPulled = (getValue(LS_TRIGGER) > 0)
	prevTrigger, triggerPulled = triggerPulled, (triggerPulled and not prevTrigger)
	
	armedNow = (getValue(LS_ARM) > 0)
	prevArm, armedNow = armedNow, armedNow and not prevArm
	
	soarUtil.callAlt = (getValue(LS_ALT10) > 0) -- Call alt every 10 sec.
	
	if sk.state <= sk.STATE_WINDOW and sk.state ~= sk.STATE_FINISHED then
		InitializeFlight()

		-- Reset altitude if the motor was armed now
		if armedNow then
			soarUtil.ResetAlt()
		end
	end
	
	sk.flightTimer = model.getTimer(0).value
	sk.flightTime = math.abs(model.getTimer(0).start - sk.flightTimer)
	sk.winTimer = model.getTimer(1).value
	
	if sk.state == sk.STATE_IDLE then
		-- Set window timer
		model.setTimer(1, { start = sk.taskWindow, value = sk.taskWindow })
		sk.winTimer = sk.taskWindow
		prevWt = sk.taskWindow
	end
	
	if motorStarted and (sk.state == sk.STATE_IDLE or sk.state == sk.STATE_WINDOW) then
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
	
	if sk.state >= sk.STATE_WINDOW then
		-- Did the window expire?
		if prevWt > 0 and sk.winTimer <= 0 then
			playTone(880, 1000, 0)

			if sk.state == sk.STATE_WINDOW then
				sk.state = sk.STATE_FINISHED
			else
				sk.state = sk.STATE_FREEZE
			end
		end

		if sk.state == sk.STATE_LAUNCHING then
			local alt = soarUtil.altMax
			local cutoff = sk.GetStartHeight()
			
			if alt >= cutoff then
				MotorStop(1)
			end
			
			if motorStopped then
				-- Mark time to record start height
				altTime = getTime() + 1000
				
			elseif altTime > 0 and getTime() > altTime then
				sk.state = sk.STATE_FLYING
				MotorStop(0)

				-- If no altimeter; default to nominal height
				if alt == 0 then
					alt = cutoff
				end

				-- Record the start height
				sk.startHeight = alt
				altTime = 0

				-- Call launch height
				if getValue(LS_ALT) > 0 then
					playNumber(alt, soarUtil.altUnit)
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
			elseif math.ceil(sk.flightTimer / 60) < math.ceil(prevFt / 60) then
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
				if (sk.finalScores and #sk.scores == sk.taskScores) or sk.launches == 0
				or (sk.taskWindow > 0 and sk.winTimer <= 0) then
					playTone(880, 1000, 0)
					sk.state = sk.STATE_FINISHED
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
	else
		-- Start both timers
		soarUtil.SetGVTmr(2)
	end
		
	-- If loadable part provides a Background() function then execute it here
	if sk.Background then sk.Background() end	
end  --  background()

-- Forward run() call to the loadable part
local function run(event)
	soarUtil.ToggleHelp(event)
	soarUtil.RunLoadable(sk.run, event, sk)
	if getValue(LS_ARM) >0 then FlashArmed() end
end

return {background = background, run = run}