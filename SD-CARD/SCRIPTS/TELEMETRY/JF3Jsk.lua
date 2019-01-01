-- JF F3J Timing and score keeping, fixed part
-- Timestamp: 2018-12-31
-- Created by Jesper Frickmann
-- Telemetry script for timing and keeping scores for F3J.
-- Depends on library functions in FUNCTIONS/JFLib.lua
-- Depends on custom script exporting the value of global "tmr" to OpenTX

local myFile = "/SCRIPTS/TELEMETRY/JF3J/SK.lua" -- Lua file to be loaded and unloaded
local winId = getFieldInfo("ls21").id -- Input ID for window timer
local flightId = getFieldInfo("ls23").id -- Input ID for flight timer
local altiId = getFieldInfo("Alti+").id -- Input ID for the Alti sensor
local altiTime -- Time for recording start height
local prevWt -- Previous window timer value
local startHeightRec -- Start height has been recorded

-- Program states, shared with loadable part
sk = {} -- Variables shared with the loadable part
local sk = sk -- Local reference is faster than a global
sk.STATE_INITIAL = 0 -- Set flight time before the flight
sk.STATE_WINDOW = 1 -- Task window is active
sk.STATE_LANDINGPTS = 2 -- Landed, input landing points
sk.STATE_SAVE = 3 -- Ready to save
sk.state = sk.STATE_INITIAL

local function background()
	if sk.state == sk.STATE_INITIAL then
		sk.landingPts = 0
		sk.startHeight = 0
		startHeightRec = false
		tmr = 1 -- Ready to start the window timer

		if getValue(winId) > 0 then -- Window started
			altiTime = 0
			sk.state = sk.STATE_WINDOW
			tmr = 0
			prevWt = model.getTimer(0).value
		end
	elseif sk.state == sk.STATE_WINDOW then
		if not startHeightRec and getValue(flightId) > 0 then -- Flight timer started; record the start height in 10 sec.
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
		
		if getValue(winId) < 0 then -- Stop timer and record scores
			sk.state = sk.STATE_LANDINGPTS
		end
	end
end  --  background()

-- Forward run() call to the loadable part
local function run(event)
	return RunLoadable(myFile, event)
end

return {background = background, run = run}