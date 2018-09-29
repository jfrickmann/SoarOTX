-- JF F3RES Timing and score keeping, fixed part
-- Timestamp: 2018-09-14
-- Created by Jesper Frickmann
-- Telemetry script for timing and keeping scores for F3RES.
-- Depends on library functions in FUNCTIONS/JFLib.lua
-- Depends on custom script exporting the value of global "tmr" to OpenTX

local myFile = "/SCRIPTS/TELEMETRY/JF3RskLd.lua" -- Lua file to be loaded and unloaded
local winId = getFieldInfo("ls16").id -- Input ID for window timer
local flightId = getFieldInfo("ls18").id -- Input ID for flight timer
local altiId = getFieldInfo("Alti+").id -- Input ID for the Alti sensor
local altiTime -- Time for recording start height
local prevFt -- Previous flight timer value
local startHeightRec -- Start height has been recorded

-- Program states, shared with loadable part
skLocals = {} -- Local variables shared with the loadable part
skLocals.STATE_SETWINTMR = 0 -- Set window time before the flight
skLocals.STATE_SETFLTTMR = 1 -- Set flight time before the flight
skLocals.STATE_WINDOW = 2 -- Task window is active
skLocals.STATE_LANDINGPTS = 3 -- Landed, input landing points
skLocals.STATE_SAVE = 4 -- Ready to save
skLocals.state = skLocals.STATE_SETWINTMR

local function background()
	if skLocals.state <= skLocals.STATE_SETFLTTMR then
		skLocals.landingPts = 0
		tmr = 1 -- Ready to start the window timer

		if getValue(winId) > 0 then -- Window started
			skLocals.state = skLocals.STATE_WINDOW
			tmr = 0
			prevFt = model.getTimer(1).value
		end
	elseif skLocals.state == skLocals.STATE_WINDOW then
		local ft = model.getTimer(1)
		local cnt -- Count interval
		
		if ft.value > 120 then
			cnt = 60
		elseif ft.value >60 then
			cnt = 15
		elseif ft.value >10 then
			cnt = 5
		else
			cnt = 1
		end
		
		if math.ceil(prevFt / cnt) > math.ceil(ft.value / cnt) then
			if ft.value > 10 then
				playDuration(ft.value, 0)
			elseif ft.value > 0 then
				playNumber(ft.value, 0)
			end
		end
		
		prevFt = ft.value
		
		if getValue(winId) < 0 then -- Stop timer and record scores
			model.setTimer(1, {value = ft.start - ft.value})
			skLocals.state = skLocals.STATE_LANDINGPTS
		end
	end
end  --  background()

-- Forward run() call to the loadable part
local function run(event)
	return LdRun(myFile, event)
end

return {background = background, run = run}