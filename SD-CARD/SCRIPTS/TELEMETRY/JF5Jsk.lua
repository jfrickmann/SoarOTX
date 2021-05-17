-- JF F5J Timing and score keeping, fixed part
-- Timestamp: 2021-05-16
-- Created by Jesper Frickmann

local FM_KAPOW = 3 -- KAPOW flight mode
local LS_ALT = getFieldInfo("ls1").id -- Input ID for allowing altitude calls
local LS_ALT10 = getFieldInfo("ls8").id -- Input ID for altitude calls every 10 sec.
local LS_TRIGGER = getFieldInfo("ls9").id -- Input ID for the trigger switch
local LS_ARM = getFieldInfo("ls23").id -- Input ID for motor arming

local offTime -- Time motor off
local prevCnt -- Previous motor off count
local prevMt -- Previous motor timer value
local prevFt -- Previous flight timer value
local prevArm = (getValue(LS_ARM) > 0) -- Previous arming state

local FlashArmed = soarUtil.LoadWxH("ARMED.lua") -- Screen size specific warning function
local sk = { } -- Variables shared with the loadable part
sk.target = math.max(60, model.getTimer(0).start)

-- Program states, shared with loadable part
sk.myFile = "/SCRIPTS/TELEMETRY/JF5J/SK.lua" -- Score keeper user interface file
sk.STATE_INITIAL = 0 -- Set flight time before the flight
sk.STATE_MOTOR= 1 -- Motor running
sk.STATE_GLIDE = 2 -- Gliding
sk.STATE_LANDINGPTS = 3 -- Landed, input landing points
sk.STATE_STARTHEIGHT = 4 -- Input start height
sk.STATE_TIME = 5 -- Input flight time
sk.STATE_SAVE = 6 -- Ready to save
sk.state = sk.STATE_INITIAL

soarUtil.SetGVTmr(0) -- Flight timer off

local function background()
	local cnt -- Count interval
	local motorOn = (getFlightMode() == soarUtil.FM_LAUNCH) -- Motor running

	local armedNow = (getValue(LS_ARM) > 0)
	prevArm, armedNow = armedNow, armedNow and not prevArm	

	soarUtil.callAlt = (getValue(LS_ALT10) > 0) -- Call alt every 10 sec.
	
	sk.flightTimer = model.getTimer(0) -- Current flight timer value
	sk.motorTimer = model.getTimer(1) -- Current motor timer value
		
	if sk.state == sk.STATE_INITIAL then
		sk.landingPts = 0
		sk.startHeight = 100 -- default if no Alt

		-- Reset altitude if the motor was armed now
		if armedNow then
			soarUtil.ResetAlt()
		end
		
		if motorOn then
			sk.state = sk.STATE_MOTOR
			soarUtil.SetGVTmr(1) -- Flight timer on
			prevMt = model.getTimer(1).value
			offTime = 0
			sk.target = 0
		end

	elseif sk.state == sk.STATE_MOTOR then
		local mt = sk.motorTimer.value -- Current motor timer value
		local sayt -- Timer value to announce (we don't have time to say "twenty-something")
		
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
			
		if not motorOn then -- Motor stopped; start 10 sec. count and record start height
			if offTime == 0 then
				offTime = getTime()
				prevCnt = 1
			end
			
			if getValue(LS_TRIGGER) < 0 then -- Trigger switch released
				prevFt = model.getTimer(0).value
				sk.state = sk.STATE_GLIDE
			end
		end

	elseif sk.state == sk.STATE_GLIDE then
		local ft = sk.flightTimer.value
		
		-- Count down flight time
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
		
		if offTime > 0 then
			-- 10 sec. count after motor off
			cnt = math.floor((getTime() - offTime) / 100)
			
			if cnt > prevCnt then
				prevCnt = cnt
				
				if cnt >= 10 then
					offTime = 0 -- No more counts

					-- Time to record start height
					local alt = soarUtil.altMax
					if alt > 0 then
						sk.startHeight = alt
					end
					
					if getValue(LS_ALT) > 0 then
						-- Call launch height
						playNumber(alt, soarUtil.altUnit)
					else
						playNumber(cnt, 0)
					end
				else
					playNumber(cnt, 0)
				end
			end
		end
		
		if getValue(LS_TRIGGER) > 0 and offTime == 0 then
			-- Stop timer and record scores
			sk.state = sk.STATE_LANDINGPTS
			soarUtil.SetGVTmr(0) -- Flight timer off

			model.setTimer(0, {value = sk.flightTimer.start - sk.flightTimer.value})
			playDuration(sk.flightTimer.start - sk.flightTimer.value)
		end
	end
	
	-- Motor restart; score a zero
	if (sk.state == sk.STATE_GLIDE or sk.state == sk.STATE_LANDINGPTS) and motorOn then
		sk.state = sk.STATE_SAVE
		model.setTimer(0, {value = 0})
		sk.startHeight = 0
	end
end  --  background()

-- Forward run() call to the loadable part
local function run(event)
	soarUtil.ToggleHelp(event)
	soarUtil.RunLoadable(sk.myFile, event, sk)
	if getValue(LS_ARM) >0 then FlashArmed() end
end

return {background = background, run = run}