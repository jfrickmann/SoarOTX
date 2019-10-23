-- JF F3RES Timing and score keeping, loadable part
-- Timestamp: 2019-10-22
-- Created by Jesper Frickmann
-- Telemetry script for timing and keeping scores for F3RES.

local sk = ...  -- List of variables shared between fixed and loadable parts
local Draw = soarUtil.LoadWxH("JF3R/SK.lua", sk) -- Screen size specific function

local function run(event)
	sk.winTmr = model.getTimer(0)
	sk.fltTmr = model.getTimer(1)
	
	Draw()

	if sk.state == sk.STATE_SETWINTMR and soarUtil.EvtEnter(event) then
		sk.state = sk.STATE_SETFLTTMR
	end
	
	if (sk.state > sk.STATE_LANDINGPTS and sk.winTmr.value > 0) or sk.state == sk.STATE_SETFLTTMR then
		if soarUtil.EvtExit(event) then
			-- Go back one step
			sk.state  = sk.state  - 1
		end
	end
	
	if sk.state <= sk.STATE_SETFLTTMR  then -- Set flight time before the flight
		local dt = 0
		local tgt
		
		if soarUtil.EvtInc(event) then
			dt = 60
		end
		
		if soarUtil.EvtDec(event) then
			dt = -60
		end
		
		if sk.state == sk.STATE_SETWINTMR then
			tgt = sk.winTmr.start + dt
			if tgt < 60 then
				tgt = 5940
			elseif tgt > 5940 then
				tgt = 60
			end
			model.setTimer(0, {start = tgt, value = tgt})
		
			soarUtil.ShowHelp({ enter = "NEXT", ud = "SET WINDOW" })
		else
			tgt = sk.fltTmr.start + dt
			if tgt < 60 then
				tgt = 60
			elseif tgt > sk.winTmr.start then
				tgt = sk.winTmr.start
			end
			model.setTimer(1, {start = tgt, value = tgt})
		
			soarUtil.ShowHelp({ exit = "BACK", ud = "SET FLIGHT" })		
		end
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
			sk.state = sk.STATE_SAVE
		end
		
		soarUtil.ShowHelp({ enter = "NEXT", ud = "SET POINTS" })
		
	elseif sk.state == sk.STATE_SAVE then
		if soarUtil.EvtEnter(event) then -- Record scores if user pressed ENTER
			local logFile = io.open("/LOGS/JF F3RES Scores.csv", "a")
			if logFile then
				local nameStr = model.getInfo().name

				local now = getDateTime()
				local dateStr = string.format("%04d-%02d-%02d", now.year, now.mon, now.day)
				local timeStr = string.format("%02d:%02d", now.hour, now.min)

				io.write(logFile, string.format("%s,%s,%s,%s,", nameStr, dateStr, timeStr, sk.landingPts))
				io.write(logFile, string.format("%s,%s,%s,%s\n", sk.winTmr.start, sk.winTmr.value, sk.fltTmr.start, sk.fltTmr.value))

				io.close(logFile)
			end
			
			sk.state = sk.STATE_SETWINTMR
		end

		-- Do not record scores
		if soarUtil.EvtExit(event) then 
			sk.state = sk.STATE_SETWINTMR
		end
	end
end  --  run()

return {run = run}