-- JF F3J Timing and score keeping, loadable part
-- Timestamp: 2019-09-18
-- Created by Jesper Frickmann
-- Telemetry script for timing and keeping scores for F3J.

local sbFile = "/SCRIPTS/TELEMETRY/JF3J/SB.lua" -- Score browser user interface file
local ui = {} -- List of  variables shared with loadable user interface
local Draw = LoadWxH("JF3J/SK.lua", ui) -- Screen size specific function

local function run(event)
	ui.winTmr = model.getTimer(0)
	ui.fltTmr = model.getTimer(1)
	
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
		
		local tgt = ui.winTmr.start + dt
		if tgt < 60 then
			tgt = 5940
		elseif tgt > 5940 then
			tgt = 60
		end
		model.setTimer(0, {start = tgt, value = tgt})
	elseif sk.state == sk.STATE_LANDINGPTS then -- Landed, input landing points 
		local dpts = 0
		
		if event == EVT_PLUS_BREAK or event == EVT_ROT_RIGHT or event == EVT_PLUS_REPT or event == EVT_RIGHT_BREAK then
			if sk.landingPts >= 90 then
				dpts = 1
			elseif sk.landingPts >= 30 then
				dpts = 5
			else
				dpts = 30
			end
		end
		
		if event == EVT_MINUS_BREAK or event == EVT_ROT_LEFT or event == EVT_MINUS_REPT or event == EVT_LEFT_BREAK then
			if sk.landingPts > 90 then
				dpts = -1
			elseif sk.landingPts > 30 then
				dpts = -5
			else
				dpts = -30
			end
		end
		
		sk.landingPts = sk.landingPts + dpts
		if sk.landingPts < 0 then
			sk.landingPts = 100
		elseif sk.landingPts  > 100 then
			sk.landingPts = 0
		end
		
		if event == EVT_ENTER_BREAK then
			sk.state = sk.STATE_TIME
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
			ui.fltTmr.value = ui.fltTmr.value + dt
			model.setTimer(1, ui.fltTmr)
		end
		
		if event == EVT_ENTER_BREAK then
			sk.state = sk.STATE_SAVE
		elseif event == EVT_MENU_BREAK or event == EVT_UP_BREAK then
			sk.state = sk.STATE_LANDINGPTS
		end
	elseif sk.state == sk.STATE_SAVE then
		if event == EVT_ENTER_BREAK then -- Record scores if user pressed ENTER
			local logFile = io.open("/LOGS/JF F3J Scores.csv", "a")
			if logFile then
				local nameStr = model.getInfo().name

				local now = getDateTime()
				local dateStr = string.format("%04d-%02d-%02d", now.year, now.mon, now.day)
				local timeStr = string.format("%02d:%02d", now.hour, now.min)

				io.write(logFile, string.format("%s,%s,%s,", nameStr, dateStr, timeStr))
				io.write(logFile, string.format("%s,%4.1f,", sk.landingPts, sk.startHeight))
				io.write(logFile, string.format("%s,%s,%s\n", ui.winTmr.start, ui.winTmr.value, ui.fltTmr.value))

				io.close(logFile)
			end
			
			sk.state = sk.STATE_INITIAL
		elseif event == EVT_MENU_BREAK or event == EVT_UP_BREAK then
			sk.state = sk.STATE_TIME
		elseif event == EVT_EXIT_BREAK then -- Do not record scores if user pressed EXIT
			sk.state = sk.STATE_INITIAL
		end
	end
	
	Draw()
end  --  run()

return {run = run}