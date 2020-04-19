-- JF F5J Timing and score keeping, fixed part
-- Timestamp: 2020-04-18
-- Created by Jesper Frickmann

local sk = { } -- Variables shared with the loadable part
local FM_MOTOR = 2 -- Motor flight mode
local FM_KAPOW = 3 -- Motor flight mode
local triggerId = getFieldInfo("ls9").id -- Input ID for the trigger switch
local armId = getFieldInfo("ls30").id -- Input ID for motor arming
local altiId = getFieldInfo("Alti+").id -- Input ID for the Alti sensor
local altiTime -- Time for recording start height
local prevMt -- Previous motor timer value
local prevFt -- Previous flight timer value

-- Program states, shared with loadable part
sk.STATE_INITIAL = 0 -- Set flight time before the flight
sk.STATE_MOTOR= 1 -- Motor running
sk.STATE_GLIDE = 2 -- Gliding
sk.STATE_LANDINGPTS = 3 -- Landed, input landing points
sk.STATE_STARTHEIGHT = 4 -- Input start height
sk.STATE_TIME = 5 -- Input flight time
sk.STATE_SAVE = 6 -- Ready to save
sk.state = sk.STATE_INITIAL
sk.myFile = "/SCRIPTS/TELEMETRY/JF5J/SK.lua" -- Score keeper user interface file

local FlashArmed = soarUtil.LoadWxH("ARMED.lua") -- Screen size specific warning function

-- Set timer GV
local function SetGVTmr(tmr)
	model.setGlobalVariable(8, 0, tmr)
end

local function background()
	local motorOn = (getFlightMode() == FM_MOTOR) -- Motor running
	
	if sk.state == sk.STATE_INITIAL then
		sk.landingPts = 0
		sk.startHeight = 0
		SetGVTmr(1) -- Ready to start the flight timer

		if motorOn then
			prevMt = model.getTimer(1).value
			altiTime = 0
			sk.state = sk.STATE_MOTOR
		end
	elseif sk.state == sk.STATE_MOTOR then
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
			
		if not motorOn then -- Motor stopped; record the start height in 10 sec.
			if altiTime == 0 then
				altiTime = getTime() + 1000
			end
			
			if getValue(triggerId) < 0 then -- Trigger switch released
				prevFt = model.getTimer(0).value
				SetGVTmr(0) -- Ready to stop the flight timer
				sk.state = sk.STATE_GLIDE
			end
		end
	elseif sk.state == sk.STATE_GLIDE then
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
			sk.startHeight = alti
			altiTime = 0
		end
		
		if motorOn then -- Motor restart; score a zero
			sk.state = sk.STATE_SAVE
			model.setTimer(0, {value = 0})
			sk.startHeight = 0
		elseif getValue(armId) < 0 and getValue(triggerId) > 0 and getTime() > altiTime or
											getFlightMode() == FM_KAPOW then -- Stop timer and record scores
			sk.state = sk.STATE_LANDINGPTS
			local ft = model.getTimer(0)
			model.setTimer(0, {value = ft.start - ft.value})
			playDuration(ft.start - ft.value)
		end
	end
end  --  background()

-- Forward run() call to the loadable part
local function run(event)
	soarUtil.ToggleHelp(event)
	soarUtil.RunLoadable(sk.myFile, event, sk)
	if getValue(armId) >0 then FlashArmed() end
end

return {background = background, run = run}