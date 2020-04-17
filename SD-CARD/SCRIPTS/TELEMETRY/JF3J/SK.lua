-- JF F3J Timing and score keeping, loadable part
-- Timestamp: 2020-04-17
-- Created by Jesper Frickmann

local sbFile = "/SCRIPTS/TELEMETRY/JF3J/SB.lua" -- Score browser user interface file
local sk = ...  -- List of variables shared between fixed and loadable parts
local ui = soarUtil.LoadWxH("JF3J/SK.lua", sk) -- Screen size specific function

local function run(event)
	ui.winTmr = model.getTimer(0)
	ui.fltTmr = model.getTimer(1)

	ui.Draw()

	if sk.state == sk.STATE_INITIAL then -- Set flight time before the flight
		local dt = 0
		
		-- Show score browser
		if soarUtil.EvtExit(event) then
			sk.myFile = sbFile
		end
	
		if soarUtil.EvtInc(event) then
			dt = 60
		end
		
		if soarUtil.EvtDec(event) then
			dt = -60
		end
		
		local tgt = ui.winTmr.start + dt
		if tgt < 60 then
			tgt = 5940
		elseif tgt > 5940 then
			tgt = 60
		end

		model.setTimer(0, {start = tgt, value = tgt})
		model.setTimer(1, {start = 0, value = 0})
		
		soarUtil.ShowHelp({ exit = "SHOW SCORES", ud = "SET TIME" })
		
	elseif sk.state == sk.STATE_LANDINGPTS then -- Landed, input landing points 
		local dpts = 0
		
		if soarUtil.EvtInc(event) then
			if sk.landingPts >= 90 then
				dpts = 1
			elseif sk.landingPts >= 30 then
				dpts = 5
			else
				dpts = 30
			end
		end
		
		if soarUtil.EvtDec(event) then
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
		
		if soarUtil.EvtEnter(event) then
			sk.state = sk.STATE_TIME
		end
		
		soarUtil.ShowHelp({ enter = "NEXT", ud = "SET POINTS" })
		
	elseif sk.state == sk.STATE_TIME then -- Input flight time
		local dt = 0
		
		if soarUtil.EvtInc(event) then
			dt = 1
		end
		
		if soarUtil.EvtDec(event) then
			dt = -1
		end
		
		if dt ~= 0 then
			ui.fltTmr.value = ui.fltTmr.value + dt
			model.setTimer(1, ui.fltTmr)
		end
		
		if soarUtil.EvtEnter(event) then
			sk.state = sk.STATE_SAVE
		elseif soarUtil.EvtExit(event) then
			sk.state = sk.STATE_LANDINGPTS
		end
		
		soarUtil.ShowHelp({ enter = "FINISH", exit = "BACK", ud = "SET TIME" })
		
	elseif sk.state == sk.STATE_SAVE then
		if soarUtil.EvtEnter(event) then -- Record scores if user pressed ENTER
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
			sk.SetGVTmr(1) -- Ready to start the window timer

		elseif soarUtil.EvtExit(event) then -- Do not record scores if user pressed EXIT
			sk.state = sk.STATE_INITIAL
			sk.SetGVTmr(1) -- Ready to start the window timer
			
		end
	end
end  --  run()

return {run = run}