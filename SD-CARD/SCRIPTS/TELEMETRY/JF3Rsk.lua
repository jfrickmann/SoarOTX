-- JF F3RES Timing and score keeping, fixed part
-- Timestamp: 2020-05-20
-- Created by Jesper Frickmann

local LS_ALT = getFieldInfo("ls1").id -- Input ID for allowing altitude calls
local LS_ALT10 = getFieldInfo("ls6").id -- Input ID for altitude calls every 10 sec.
local LS_TRIGGER = getFieldInfo("ls7").id -- Input ID for the trigger switch

local sk = {} -- Variables shared with the loadable part
local altiTime -- Time for recording start height
local prevWt -- Previous window timer value
local TriggerOld = (getValue(LS_TRIGGER) > 0) -- Previous position
local flightModeOld = getFlightMode() -- To be able to detect flight mode changes

-- Program states, shared with loadable part
sk.STATE_SETWINTMR = 0 -- Set window time before the flight
sk.STATE_SETFLTTMR = 1 -- Set flight time before the flight
sk.STATE_WINDOW = 2 -- Task window is active
sk.STATE_FLYING = 3 -- Flight timer is running
sk.STATE_LANDINGPTS = 4 -- Landed, input landing points
sk.STATE_TIME = 5 -- Input flight time
sk.STATE_SAVE = 6 -- Ready to save
sk.state = sk.STATE_SETWINTMR
sk.myFile = "/SCRIPTS/TELEMETRY/JF3R/SK.lua" -- Lua file to be loaded and unloaded

soarUtil.FM_LAUNCH = 1 -- No Adjust mode here!
soarUtil.SetGVTmr(0)

local function background()
	local flightMode = getFlightMode()
	local trigger = (getValue(LS_TRIGGER) > 0)
	local triggerPulled = (trigger and not triggerOld)
	local triggerReleased = (not trigger and triggerOld)	
	triggerOld = trigger

	soarUtil.callAlt = (getValue(LS_ALT10) > 0) -- Call alt every 10 sec.
	
	sk.windowTimer = model.getTimer(0)
	sk.flightTimer = model.getTimer(1)
	
	if sk.state == sk.STATE_SETWINTMR then
		sk.landingPts = 0
		sk.startHeight = 0

		if triggerReleased then -- Window started
			playTone(1760, 100, PLAY_NOW)
			sk.state = sk.STATE_WINDOW
			soarUtil.SetGVTmr(1)
			prevWt = model.getTimer(0).value
			altiTime = 0
		end

		-- Reset altitude if launch mode entered
		if flightMode == soarUtil.FM_LAUNCH and flightModeOld ~= flightMode then
			soarUtil.ResetAlt()
		end

	elseif sk.state == sk.STATE_WINDOW then
		if triggerPulled then
			-- Start flight timer
			playTone(1760, 100, PLAY_NOW)
			soarUtil.SetGVTmr(2)
			sk.state = sk.STATE_FLYING
			altiTime = getTime() + 1000
			sk.startHeight = soarUtil.altMax
		end

	elseif sk.state == sk.STATE_FLYING then
		-- Record (and announce) start height
		if altiTime > 0 and getTime() > altiTime then
			altiTime = 0
			sk.startHeight = soarUtil.altMax
			
			if getValue(LS_ALT) > 0 then
				playNumber(soarUtil.altMax, soarUtil.altUnit)
			end
		end

		local wt = model.getTimer(0).value -- Current window timer value
		local cnt -- Count interval
		
		if wt > 120 then
			cnt = 60
		elseif wt >60 then
			cnt = 15
		elseif wt >10 then
			cnt = 5
		else
			cnt = 1
		end
		
		if math.ceil(prevWt / cnt) > math.ceil(wt / cnt) then
			if wt > 10 then
				playDuration(wt, 0)
			elseif wt > 0 then
				playNumber(wt, 0)
			end
		end
		
		-- Stop flight when the window expires
		if wt <= 0 and prevWt > 0 then
			soarUtil.SetGVTmr(1)
		end
		
		prevWt = wt
		
		if triggerPulled then -- Stop timer and record scores
			playTone(1760, 100, PLAY_NOW)
			sk.state = sk.STATE_LANDINGPTS
			soarUtil.SetGVTmr(0)

			model.setTimer(1, {value = sk.flightTimer.start - sk.flightTimer.value})
			playDuration(sk.flightTimer.start - sk.flightTimer.value)
		end
	end
	
	flightModeOld = flightMode
end  --  background()

-- Forward run() call to the loadable part
local function run(event)
	soarUtil.ToggleHelp(event)
	return soarUtil.RunLoadable(sk.myFile, event, sk)
end

return {background = background, run = run}