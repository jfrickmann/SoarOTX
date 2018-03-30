-- JF F5J Timing and score keeping, fixed part
-- Timestamp: 2018-02-25
-- Created by Jesper Frickmann
-- Telemetry script for timing and keeping scores for F5J.
-- Depends on library functions in FUNCTIONS/JFLib.lua
-- Depends on custom script exporting the value of global "tmr" to OpenTX

local myFile = "/SCRIPTS/TELEMETRY/JF5JskLd.lua" -- Lua file to be loaded and unloaded
local motorId = getFieldInfo("ls20").id -- Input ID for motor run
local triggerId = getFieldInfo("ls25").id -- Input ID for the trigger switch 
local altiId = getFieldInfo("Alti+").id -- Input ID for the Alti sensor
local altiTime -- Time for recording start height
local prevMt -- Previous motor timer value
local prevFt -- Previous flight timer value

-- Program states, shared with loadable part
skLocals = {} -- Local variables shared with the loadable part
skLocals.STATE_INITIAL = 0 -- Set flight time before the flight
skLocals.STATE_MOTOR= 1 -- Motor running
skLocals.STATE_GLIDE = 2 -- Gliding
skLocals.STATE_LANDINGPTS = 3 -- Landed, input landing points
skLocals.STATE_STARTHEIGHT = 4 -- Input start height
skLocals.STATE_SAVE = 5 -- Ready to save
skLocals.state = skLocals.STATE_INITIAL

local function background()
	if skLocals.state == skLocals.STATE_INITIAL then
		skLocals.landingPts = 0
		skLocals.startHeight = 0
		tmr = 1 -- Ready to start the flight timer

		if getValue(motorId) > 0 then -- Motor started
			prevMt = model.getTimer(1).value
			altiTime = 0
			skLocals.state = skLocals.STATE_MOTOR
		end
	elseif skLocals.state == skLocals.STATE_MOTOR then
		local mt = model.getTimer(1).value -- Current motor timer value
		local sayt -- Timer value to announce (we don't have time to say "twenty-something")
		local cnt -- Count interval
		
		if mt <= 20 then
			cnt = 5
			sayt = mt
		elseif mt < 30 then
			cnt = 1
			sayt = mt - 20
		else
			cnt = 1
			sayt = mt
		end
		
		if math.floor(prevMt / cnt) < math.floor(mt / cnt) then
			playNumber(sayt, 0)
		end
		
		prevMt = mt
			
		if getValue(motorId) < 0 then -- Motor stopped; record the start height in 10 sec.
			if altiTime == 0 then
				altiTime = getTime() + 1000
			end
			
			if getValue(triggerId) < 0 then -- Trigger switch released
				prevFt = model.getTimer(0).value
				tmr = 0 -- Ready to stop the flight timer
				skLocals.state = skLocals.STATE_GLIDE
			end
		end
	elseif skLocals.state == skLocals.STATE_GLIDE then
		local ft = model.getTimer(0).value -- Current flight timer value
		local cnt -- Count interval
		
		if ft > 120 then
			cnt = 60
		elseif ft >60 then
			cnt = 15
		elseif ft >10 then
			cnt = 5
		else
			cnt = 1
		end
		
		if math.ceil(prevFt / cnt) > math.ceil(ft / cnt) then
			if ft > 10 then
				playDuration(ft, 0)
			elseif ft > 0 then
				playNumber(ft, 0)
			end
		end
		
		prevFt = ft
			
		if altiTime > 0 and getTime() > altiTime then -- Record the start height
			local alti = getValue(altiId)
			if alti == 0 then alti = 100 end -- If no altimeter; default to 100
			skLocals.startHeight = alti
			altiTime = 0
		end
		
		if getValue(motorId) > 0 then -- Motor restart; score a zero
			skLocals.state = skLocals.STATE_SAVE
			model.setTimer(0, {value = 0})
			skLocals.startHeight = 0
		elseif getValue(triggerId) > 0 and getTime() > altiTime then -- Stop timer and record scores
			skLocals.state = skLocals.STATE_LANDINGPTS
			local ft = model.getTimer(0)
			model.setTimer(0, {value = ft.start - ft.value})			
		end
	end
end  --  background()

-- Forward run() call to the loadable part
local function run(event)
	return LdRun(myFile, event)
end

return {background = background, run = run}