-- JF F3J Timing and score keeping, fixed part
-- Timestamp: 2021-05-17
-- Created by Jesper Frickmann

local FM_KAPOW = 3 -- KAPOW flight mode
local LS_ALT = getFieldInfo("ls1").id -- Input ID for allowing altitude calls
local LS_ALT10 = getFieldInfo("ls8").id -- Input ID for altitude calls every 10 sec.
local LS_TRIGGER = getFieldInfo("ls9").id -- Input ID for the trigger switch

local altTime -- Time for recording start height
local prevWt -- Previous window timer value
local TriggerOld = (getValue(LS_TRIGGER) > 0) -- Previous position
local flightModeOld = getFlightMode() -- To be able to detect flight mode changes
local sk = {} -- Variables shared with the loadable part
sk.target = math.max(60, model.getTimer(0).start)

-- Program states, shared with loadable part
sk.STATE_INITIAL = 0 -- Set flight time before the flight
sk.STATE_WINDOW = 1 -- Task window is active
sk.STATE_FLYING = 2 -- Flight timer is running
sk.STATE_LANDINGPTS = 3 -- Landed, input landing points
sk.STATE_TIME = 4 -- Input flight time
sk.STATE_SAVE = 5 -- Ready to save
sk.state = sk.STATE_INITIAL
sk.myFile = "/SCRIPTS/TELEMETRY/JF3J/SK.lua" -- Score keeper user interface file

soarUtil.SetGVTmr(0)

local function background()
	local flightMode = getFlightMode()
	local trigger = (getValue(LS_TRIGGER) > 0)
	local triggerPulled = (trigger and not triggerOld)
	local triggerReleased = (not trigger and triggerOld)	
	triggerOld = trigger

	sk.windowTimer = model.getTimer(0)
	sk.flightTimer = model.getTimer(1)

	soarUtil.callAlt = (getValue(LS_ALT10) > 0) -- Call alt every 10 sec.
	
	if sk.state == sk.STATE_INITIAL then
		sk.landingPts = 0
		sk.startHeight = 0

		if triggerReleased then -- Window started
			playTone(1760, 100, PLAY_NOW)
			sk.state = sk.STATE_WINDOW
			soarUtil.SetGVTmr(1)
			prevWt = model.getTimer(0).value
			altTime = 0
			sk.target = 0
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
			altTime = getTime() + 1000
			sk.startHeight = soarUtil.altMax
		end

	elseif sk.state == sk.STATE_FLYING then
		-- Record (and announce) start height
		if altTime > 0 and getTime() > altTime then
			sk.startHeight = soarUtil.altMax
			altTime = 0
			
			-- Call launch height
			if getValue(LS_ALT) > 0 then
				playNumber(sk.startHeight, soarUtil.altUnit)
			end
			
			if sk.startHeight == 0 then sk.startHeight = 100 end -- If no altimeter; default to 100
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
		
		if triggerPulled and getTime() > altTime then
			-- Stop timer and record scores
			playTone(1760, 100, PLAY_NOW)
			sk.state = sk.STATE_LANDINGPTS
			soarUtil.SetGVTmr(0)
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