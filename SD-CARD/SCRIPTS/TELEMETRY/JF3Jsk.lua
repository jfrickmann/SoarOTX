-- JF F3J Timing and score keeping, fixed part
-- Timestamp: 2020-04-16
-- Created by Jesper Frickmann

local sk = {} -- Variables shared with the loadable part
local altiId = getFieldInfo("Alti+").id -- Input ID for the Alti sensor
local altiTime -- Time for recording start height
local prevWt -- Previous window timer value
local startHeightRec -- Start height has been recorded

-- Program states, shared with loadable part
sk.STATE_INITIAL = 0 -- Set flight time before the flight
sk.STATE_WINDOW = 1 -- Task window is active
sk.STATE_LANDINGPTS = 2 -- Landed, input landing points
sk.STATE_TIME = 3 -- Input flight time
sk.STATE_SAVE = 4 -- Ready to save
sk.state = sk.STATE_INITIAL
sk.myFile = "/SCRIPTS/TELEMETRY/JF3J/SK.lua" -- Score keeper user interface file

-- Read timer GV
local function GetGVTmr()
	return model.getGlobalVariable(8, 0)
end

-- Set timer GV
function sk.SetGVTmr(tmr)
	model.setGlobalVariable(8, 0, tmr)
end

sk.SetGVTmr(1) -- Ready to start the window timer

local function background()
	if sk.state == sk.STATE_INITIAL then
		sk.landingPts = 0
		sk.startHeight = 0
		startHeightRec = false

		if GetGVTmr() == 2 then -- Window started
			altiTime = 0
			sk.state = sk.STATE_WINDOW
			prevWt = model.getTimer(0).value
		end
	elseif sk.state == sk.STATE_WINDOW then
		if not startHeightRec and GetGVTmr() == 3 then -- Flight timer started; record the start height in 10 sec.
			if altiTime == 0 then
				altiTime = getTime() + 1000
			elseif getTime() > altiTime then -- Record the start height
				sk.startHeight = getValue(altiId)
				startHeightRec = true
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
		
		prevWt = wt
		
		if GetGVTmr() == 0 then -- Stop timer and record scores
			sk.state = sk.STATE_LANDINGPTS
		end
	end
end  --  background()

-- Forward run() call to the loadable part
local function run(event)
	soarUtil.ToggleHelp(event)
	return soarUtil.RunLoadable(sk.myFile, event, sk)
end

return {background = background, run = run}