-- JF F3J Timing and score keeping, loadable part
-- Timestamp: 2021-01-02
-- Created by Jesper Frickmann

local sbFile = "/SCRIPTS/TELEMETRY/JF3J/SB.lua" -- Score browser user interface file
local sk = ...  -- List of variables shared between fixed and loadable parts
local Draw = soarUtil.LoadWxH("JF3J/SK.lua", sk) -- Screen size specific function

local function run(event)
	local dt = 0

	-- Set flight time
	if sk.target > 0 then
		dt = 0
		
		if event == EVT_VIRTUAL_INC or event == EVT_VIRTUAL_INC_REPT then
			dt = 60
		elseif event == EVT_VIRTUAL_DEC or event == EVT_VIRTUAL_DEC_REPT then
			dt = -60
		end
		
		sk.target = sk.target + dt

		if sk.target < 60 then
			sk.target = 5940
		elseif sk.target > 5940 then
			sk.target = 60
		end
	end
	
	if sk.state == sk.STATE_INITIAL then
		-- Show score browser
		if event == EVT_VIRTUAL_EXIT then
			sk.myFile = sbFile
		end

		model.setTimer(0, {start = sk.target, value = sk.target})
		model.setTimer(1, {start = 0, value = 0})
		
		soarUtil.ShowHelp({ exit = "SHOW SCORES", ud = "SET TIME" })

	elseif sk.state == sk.STATE_FLYING then
		if event == EVT_VIRTUAL_ENTER then
			if sk.target == 0 then
				sk.target = math.max(60, 60 * math.floor(sk.windowTimer.value / 60))
			else
				model.setTimer(0, {start = sk.target, value = sk.target})
				sk.target = 0
			end
			
		elseif event == EVT_VIRTUAL_EXIT then
			sk.target = 0
		end
		
		if sk.target > 0 then
			soarUtil.ShowHelp({ enter = "RE-SET TIME" })
		else
			soarUtil.ShowHelp({ enter = "RE-SET TIME" , exit = "ESCAPE", ud = "CHANGE" })
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
			local logFile = io.open("/LOGS/JF F3J Scores.csv", "a")
			if logFile then
				local nameStr = model.getInfo().name

				local now = getDateTime()
				local dateStr = string.format("%04d-%02d-%02d", now.year, now.mon, now.day)
				local timeStr = string.format("%02d:%02d", now.hour, now.min)

				io.write(logFile, string.format("%s,%s,%s,", nameStr, dateStr, timeStr))
				io.write(logFile, string.format("%s,%4.1f,", sk.landingPts, sk.startHeight))
				io.write(logFile, string.format("%s,%s,%s\n", sk.windowTimer.start, sk.windowTimer.value, sk.flightTimer.value))

				io.close(logFile)
			end
			
			sk.state = sk.STATE_INITIAL
			sk.target = math.max(sk.windowTimer.start)

		elseif event == EVT_VIRTUAL_EXIT then -- Do not record scores if user pressed EXIT
			sk.state = sk.STATE_INITIAL
			sk.target = math.max(sk.windowTimer.start)
			
		end
	end
	
	Draw()
	
end  --  run()

return {run = run}