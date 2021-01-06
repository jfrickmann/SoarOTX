-- JF F3RES Timing and score keeping, loadable part
-- Timestamp: 2021-01-02
-- Created by Jesper Frickmann

local sbFile = "/SCRIPTS/TELEMETRY/JF3R/SB.lua" -- Score browser user interface file
local sk = ...  -- List of variables shared between fixed and loadable parts
local Draw = soarUtil.LoadWxH("JF3R/SK.lua", sk) -- Screen size specific function

local function run(event)
	if sk.state <= sk.STATE_SETFLTTMR  then -- Set flight time before the flight
		local dt = 0
		local tgt
		
		-- Show score browser
		if event == EVT_VIRTUAL_EXIT then
			sk.myFile = sbFile
		end
	
		if event == EVT_VIRTUAL_INC or event == EVT_VIRTUAL_INC_REPT then
			dt = 60
		end
		
		if event == EVT_VIRTUAL_DEC or event == EVT_VIRTUAL_DEC_REPT then
			dt = -60
		end
		
		if sk.state == sk.STATE_SETWINTMR then
			if event == EVT_VIRTUAL_ENTER then
				sk.state = sk.STATE_SETFLTTMR
			end
	
			tgt = sk.windowTimer.start + dt
			if tgt < 60 then
				tgt = 5940
			elseif tgt > 5940 then
				tgt = 60
			end
			model.setTimer(0, {start = tgt, value = tgt})
		
			soarUtil.ShowHelp({ enter = "NEXT", ud = "SET WINDOW" })
		else
			if event == EVT_VIRTUAL_ENTER then
				sk.state = sk.STATE_SETWINTMR
			end
	
			tgt = sk.flightTimer.start + dt
			if tgt < 60 then
				tgt = 60
			elseif tgt > sk.windowTimer.start then
				tgt = sk.windowTimer.start
			end
			model.setTimer(1, {start = tgt, value = tgt})
		
			soarUtil.ShowHelp({ exit = "BACK", ud = "SET FLIGHT" })		
		end
	elseif sk.state == sk.STATE_LANDINGPTS then -- Landed, input landing points 
		local dpts = 0
		
		if event == EVT_VIRTUAL_INC or event == EVT_VIRTUAL_INC_REPT then
			if sk.landingPts >= 90 then
				dpts = 1
			elseif sk.landingPts >= 30 then
				dpts = 5
			else
				dpts = 30
			end
		end
		
		if event == EVT_VIRTUAL_DEC or event == EVT_VIRTUAL_DEC_REPT then
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
		
		if event == EVT_VIRTUAL_ENTER then
			sk.state = sk.STATE_TIME
		end
		
		soarUtil.ShowHelp({ enter = "NEXT", ud = "SET POINTS" })
		
	elseif sk.state == sk.STATE_TIME then -- Input flight time
		local dt = 0
		
		if event == EVT_VIRTUAL_INC or event == EVT_VIRTUAL_INC_REPT then
			dt = 1
		end
		
		if event == EVT_VIRTUAL_DEC or event == EVT_VIRTUAL_DEC_REPT then
			dt = -1
		end
		
		if dt ~= 0 then
			sk.flightTimer.value = sk.flightTimer.value + dt
			model.setTimer(1, sk.flightTimer)
		end
		
		if event == EVT_VIRTUAL_ENTER then
			sk.state = sk.STATE_SAVE
		elseif event == EVT_VIRTUAL_EXIT then
			sk.state = sk.STATE_LANDINGPTS
		end
		
		soarUtil.ShowHelp({ enter = "FINISH", exit = "BACK", ud = "SET TIME" })
		
	elseif sk.state == sk.STATE_SAVE then
		if event == EVT_VIRTUAL_ENTER then -- Record scores if user pressed ENTER
			local logFile = io.open("/LOGS/JF F3RES Scores.csv", "a")
			if logFile then
				local nameStr = model.getInfo().name

				local now = getDateTime()
				local dateStr = string.format("%04d-%02d-%02d", now.year, now.mon, now.day)
				local timeStr = string.format("%02d:%02d", now.hour, now.min)

				io.write(logFile, string.format("%s,%s,%s,", nameStr, dateStr, timeStr))
				io.write(logFile, string.format("%s,%4.1f,", sk.landingPts, sk.startHeight))
				io.write(logFile, string.format("%s,%s,%s,%s\n", sk.windowTimer.start, sk.windowTimer.value, sk.flightTimer.start, sk.flightTimer.value))

				io.close(logFile)
			end
			
			sk.state = sk.STATE_SETWINTMR
			model.resetTimer(1)

		elseif event == EVT_VIRTUAL_EXIT then -- Do not record scores if user pressed EXIT
			sk.state = sk.STATE_SETWINTMR
			model.resetTimer(1)

		end
	end
	
	Draw()
end  --  run()

return {run = run}