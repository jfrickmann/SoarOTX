-- JF F3J Timing and score keeping, fixed part
-- Timestamp: 2018-05-20
-- Created by Jesper Frickmann
-- Telemetry script for timing and keeping scores for F3J.
-- Depends on library functions in FUNCTIONS/JFLib.lua
-- Depends on custom script exporting the value of global "tmr" to OpenTX

local myFile = "/SCRIPTS/TELEMETRY/JF3JskLd.lua" -- Lua file to be loaded and unloaded
local winId = getFieldInfo("ls21").id -- Input ID for window timer
local flightId = getFieldInfo("ls23").id -- Input ID for flight timer
local altiId = getFieldInfo("Alti+").id -- Input ID for the Alti sensor
local altiTime -- Time for recording start height
local prevWt -- Previous window timer value
local startHeightRec -- Start height has been recorded

-- Program states, shared with loadable part
skLocals = {} -- Local variables shared with the loadable part
skLocals.STATE_INITIAL = 0 -- Set flight time before the flight
skLocals.STATE_WINDOW = 1 -- Task window is active
skLocals.STATE_LANDINGPTS = 2 -- Landed, input landing points
skLocals.STATE_SAVE = 3 -- Ready to save
skLocals.state = skLocals.STATE_INITIAL

local function background()
	if skLocals.state == skLocals.STATE_INITIAL then
		skLocals.landingPts = 0
		skLocals.startHeight = 0
		startHeightRec = false
		tmr = 1 -- Ready to start the window timer

		if getValue(winId) > 0 then -- Window started
			altiTime = 0
			skLocals.state = skLocals.STATE_WINDOW
			tmr = 0
			prevWt = model.getTimer(0).value
		end
	elseif skLocals.state == skLocals.STATE_WINDOW then
		if not startHeightRec and getValue(flightId) > 0 then -- Flight timer started; record the start height in 10 sec.
			if altiTime == 0 then
				altiTime = getTime() + 1000
			elseif getTime() > altiTime then -- Record the start height
				skLocals.startHeight = getValue(altiId)
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
			skLocals.state = skLocals.STATE_LANDINGPTS
		end
	end
end  --  background()

-- Forward run() call to the loadable part
local function run(event)
	return LdRun(myFile, event)
end

return {background = background, run = run}