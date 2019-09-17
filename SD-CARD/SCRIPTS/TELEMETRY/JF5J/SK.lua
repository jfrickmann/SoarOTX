-- JF F5J Timing and score keeping, loadable part
-- Timestamp: 2019-09-16
-- Created by Jesper Frickmann
-- Telemetry script for timing and keeping scores for F5J.

local sbFile = "/SCRIPTS/TELEMETRY/JF5J/SB.lua" -- Score browser user interface file
local Draw = LoadWxH("JF5J/SK.lua", sk) -- Screen size specific function

sk.armId = getFieldInfo("ls19").id -- Input ID for motor arming

local function run(event)
	sk.fltTmr = model.getTimer(0)
	sk.motTmr = model.getTimer(1)
	
	if sk.state == sk.STATE_INITIAL then -- Set flight time before the flight
		local dt = 0
		
		-- Show score browser
		if event == EVT_MENU_BREAK then
			sk.myFile = sbFile
		end
	
		if event == EVT_PLUS_BREAK or event == EVT_ROT_RIGHT or event == EVT_PLUS_REPT or event == EVT_RIGHT_BREAK then
			dt = 60
		end
		
		if event == EVT_MINUS_BREAK or event == EVT_ROT_LEFT or event == EVT_MINUS_REPT or event == EVT_LEFT_BREAK then
			dt = -60
		end
		
		local tgt = sk.fltTmr.start + dt
		if tgt < 60 then
			tgt = 5940
		elseif tgt > 5940 then
			tgt = 60
		end
		model.setTimer(0, {start = tgt, value = tgt})
	elseif sk.state == sk.STATE_LANDINGPTS then -- Landed, input landing points 
		local dpts = 0
		
		if event == EVT_PLUS_BREAK or event == EVT_ROT_RIGHT or event == EVT_PLUS_REPT or event == EVT_RIGHT_BREAK then
			dpts = 5
		end
		
		if event == EVT_MINUS_BREAK or event == EVT_ROT_LEFT or event == EVT_MINUS_REPT or event == EVT_LEFT_BREAK then
			dpts = -5
		end
		
		sk.landingPts = sk.landingPts + dpts
		if sk.landingPts < 0 then
			sk.landingPts = 50
		elseif sk.landingPts  > 50 then
			sk.landingPts = 0
		end
		
		if event == EVT_ENTER_BREAK then
			sk.state = sk.STATE_STARTHEIGHT
		end
	elseif sk.state == sk.STATE_STARTHEIGHT then -- Input start height
		local dm = 0
		
		if event == EVT_PLUS_BREAK or event == EVT_ROT_RIGHT or event == EVT_RIGHT_BREAK then
			dm = 0.1
		end
		
		if event == EVT_PLUS_REPT or event == EVT_RIGHT_REPT then
			dm = 1
		end
		
		if event == EVT_MINUS_BREAK or event == EVT_ROT_LEFT or event == EVT_LEFT_BREAK then
			dm = -0.1
		end
		
		if event == EVT_MINUS_REPT or event == EVT_LEFT_REPT then
			dm = -1
		end
		
		sk.startHeight = sk.startHeight + dm
		if sk.startHeight < 0 then
			sk.startHeight = 0
		elseif sk.startHeight  > 300 then
			sk.startHeight = 300
		end
		
		if event == EVT_ENTER_BREAK then
			sk.state = sk.STATE_TIME
		elseif event == EVT_MENU_BREAK or event == EVT_UP_BREAK then
			sk.state = sk.STATE_LANDINGPTS
		end
	elseif sk.state == sk.STATE_TIME then -- Input flight time
		local dt = 0
		
		if event == EVT_PLUS_BREAK or event == EVT_ROT_RIGHT or event == EVT_PLUS_REPT or event == EVT_RIGHT_BREAK then
			dt = 1
		end
		
		if event == EVT_MINUS_BREAK or event == EVT_ROT_LEFT or event == EVT_MINUS_REPT or event == EVT_LEFT_BREAK then
			dt = -1
		end
		
		if dt ~= 0 then
			sk.fltTmr.value = sk.fltTmr.value + dt
			model.setTimer(0, sk.fltTmr)
		end
		
		if event == EVT_ENTER_BREAK then
			sk.state = sk.STATE_SAVE
		elseif event == EVT_MENU_BREAK or event == EVT_UP_BREAK then
			sk.state = sk.STATE_STARTHEIGHT
		end
	elseif sk.state == sk.STATE_SAVE then
		if event == EVT_ENTER_BREAK then -- Record scores if user pressed ENTER
			local logFile = io.open("/LOGS/JF F5J Scores.csv", "a")
			if logFile then
				local nameStr = model.getInfo().name

				local now = getDateTime()
				local dateStr = string.format("%04d-%02d-%02d", now.year, now.mon, now.day)
				local timeStr = string.format("%02d:%02d", now.hour, now.min)

				io.write(logFile, string.format("%s,%s,%s,", nameStr, dateStr, timeStr))
				io.write(logFile, string.format("%s,%4.1f,", sk.landingPts, sk.startHeight))
				io.write(logFile, string.format("%s,%s\n", sk.fltTmr.start, sk.fltTmr.value))

				io.close(logFile)
			end
			
			sk.state = sk.STATE_INITIAL
		elseif event == EVT_EXIT_BREAK then -- Do not record scores if user pressed EXIT
			sk.state = sk.STATE_INITIAL
		elseif event == EVT_MENU_BREAK or event == EVT_UP_BREAK then
			sk.state = sk.STATE_TIME
		end
	end
	
	Draw()
end  --  run()

return {run = run}