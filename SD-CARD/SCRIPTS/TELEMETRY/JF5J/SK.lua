-- JF F5J Timing and score keeping, loadable part
-- Timestamp: 2019-10-22
-- Created by Jesper Frickmann
-- Telemetry script for timing and keeping scores for F5J.

local sk = ...  -- List of variables shared between fixed and loadable parts
local sbFile = "/SCRIPTS/TELEMETRY/JF5J/SB.lua" -- Score browser user interface file
local Draw = soarUtil.LoadWxH("JF5J/SK.lua", sk) -- Screen size specific function

local function run(event)
	sk.fltTmr = model.getTimer(0)
	sk.motTmr = model.getTimer(1)
	
	Draw()
	
	if sk.state == sk.STATE_INITIAL then -- Set flight time before the flight
		local dt = 0
		
		-- Show score browser
		if soarUtil.EvtExit(event) then
			sk.myFile = sbFile
		elseif soarUtil.EvtInc(event) then
			dt = 60
		elseif soarUtil.EvtDec(event) then
			dt = -60
		end
		
		local tgt = sk.fltTmr.start + dt
		if tgt < 60 then
			tgt = 5940
		elseif tgt > 5940 then
			tgt = 60
		end
		model.setTimer(0, {start = tgt, value = tgt})
		
		soarUtil.ShowHelp({ exit = "SHOW SCORES", ud = "SET TIME" })
		
	elseif sk.state == sk.STATE_LANDINGPTS then -- Landed, input landing points 
		local dpts = 0
		
		if soarUtil.EvtInc(event) then
			dpts = 5
		elseif soarUtil.EvtDec(event) then
			dpts = -5
		end
		
		sk.landingPts = sk.landingPts + dpts
		if sk.landingPts < 0 then
			sk.landingPts = 50
		elseif sk.landingPts  > 50 then
			sk.landingPts = 0
		end
		
		if soarUtil.EvtEnter(event) then
			sk.state = sk.STATE_STARTHEIGHT
		end
		
		soarUtil.ShowHelp({ enter = "NEXT", ud = "SET POINTS" })
		
	elseif sk.state == sk.STATE_STARTHEIGHT then -- Input start height
		local dm = 0
		
		if soarUtil.EvtInc(event) then
			dm = 1
		elseif soarUtil.EvtDec(event) then
			dm = -1
		end
		
		sk.startHeight = sk.startHeight + dm
		if sk.startHeight < 0 then
			sk.startHeight = 0
		elseif sk.startHeight  > 300 then
			sk.startHeight = 300
		end
		
		if soarUtil.EvtEnter(event) then
			sk.state = sk.STATE_TIME
		elseif soarUtil.EvtExit(event) then
			sk.state = sk.STATE_LANDINGPTS
		end
		
		soarUtil.ShowHelp({ enter = "NEXT", exit = "BACK", ud = "SET HEIGHT" })
		
	elseif sk.state == sk.STATE_TIME then -- Input flight time
		local dt = 0
		
		if soarUtil.EvtInc(event) then
			dt = 1
		elseif soarUtil.EvtDec(event) then
			dt = -1
		end
		
		if dt ~= 0 then
			sk.fltTmr.value = sk.fltTmr.value + dt
			model.setTimer(0, sk.fltTmr)
		end
		
		if soarUtil.EvtEnter(event) then
			sk.state = sk.STATE_SAVE
		elseif soarUtil.EvtExit(event) then
			sk.state = sk.STATE_STARTHEIGHT
		end
		
		soarUtil.ShowHelp({ enter = "FINISH", exit = "BACK", ud = "SET TIME" })
		
	elseif sk.state == sk.STATE_SAVE then
		-- Record scores if user pressed ENTER
		if soarUtil.EvtEnter(event) then
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
		elseif soarUtil.EvtExit(event) then
			 -- Do not record scores if user pressed EXIT
			sk.state = sk.STATE_INITIAL
		end
	end
end  --  run()

return {run = run}