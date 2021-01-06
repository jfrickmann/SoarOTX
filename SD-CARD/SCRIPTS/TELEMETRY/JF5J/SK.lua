-- JF F5J Timing and score keeping, loadable part
-- Timestamp: 2021-01-02
-- Created by Jesper Frickmann
-- Telemetry script for timing and keeping scores for F5J.

local sk = ...  -- List of variables shared between fixed and loadable parts
local sbFile = "/SCRIPTS/TELEMETRY/JF5J/SB.lua" -- Score browser user interface file
local Draw = soarUtil.LoadWxH("JF5J/SK.lua", sk) -- Screen size specific function

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
		if event == EVT_VIRTUAL_EXIT then
			-- Show score browser
			sk.myFile = sbFile
		end

		model.setTimer(0, {start = sk.target, value = sk.target})
		soarUtil.ShowHelp({ exit = "SHOW SCORES", ud = "SET TIME" })

	elseif sk.state == sk.STATE_GLIDE then
		if event == EVT_VIRTUAL_ENTER then
			if sk.target == 0 then
				sk.target = math.max(60, 60 * math.floor(sk.flightTimer.value / 60))
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
			dpts = 5
		elseif event == EVT_VIRTUAL_DEC or event == EVT_VIRTUAL_DEC_REPT then
			dpts = -5
		end
		
		sk.landingPts = sk.landingPts + dpts
		if sk.landingPts < 0 then
			sk.landingPts = 50
		elseif sk.landingPts  > 50 then
			sk.landingPts = 0
		end
		
		if event == EVT_VIRTUAL_ENTER then
			sk.state = sk.STATE_STARTHEIGHT
		end
		
		soarUtil.ShowHelp({ enter = "NEXT", ud = "SET POINTS" })
		
	elseif sk.state == sk.STATE_STARTHEIGHT then -- Input start height
		local dm = 0
		
		if event == EVT_VIRTUAL_INC or event == EVT_VIRTUAL_INC_REPT then
			dm = 1
		elseif event == EVT_VIRTUAL_DEC or event == EVT_VIRTUAL_DEC_REPT then
			dm = -1
		end
		
		sk.startHeight = sk.startHeight + dm
		if sk.startHeight < 0 then
			sk.startHeight = 0
		elseif sk.startHeight  > 300 then
			sk.startHeight = 300
		end
		
		if event == EVT_VIRTUAL_ENTER then
			sk.state = sk.STATE_TIME
		elseif event == EVT_VIRTUAL_EXIT then
			sk.state = sk.STATE_LANDINGPTS
		end
		
		soarUtil.ShowHelp({ enter = "NEXT", exit = "BACK", ud = "SET HEIGHT" })
		
	elseif sk.state == sk.STATE_TIME then -- Input flight time
		local dt = 0
		
		if event == EVT_VIRTUAL_INC or event == EVT_VIRTUAL_INC_REPT then
			dt = 1
		elseif event == EVT_VIRTUAL_DEC or event == EVT_VIRTUAL_DEC_REPT then
			dt = -1
		end
		
		if dt ~= 0 then
			sk.flightTimer.value = sk.flightTimer.value + dt
			model.setTimer(0, sk.flightTimer)
		end
		
		if event == EVT_VIRTUAL_ENTER then
			sk.state = sk.STATE_SAVE
		elseif event == EVT_VIRTUAL_EXIT then
			sk.state = sk.STATE_STARTHEIGHT
		end
		
		soarUtil.ShowHelp({ enter = "FINISH", exit = "BACK", ud = "SET TIME" })
		
	elseif sk.state == sk.STATE_SAVE then
		-- Record scores if user pressed ENTER
		if event == EVT_VIRTUAL_ENTER then
			local logFile = io.open("/LOGS/JF F5J Scores.csv", "a")
			if logFile then
				local nameStr = model.getInfo().name

				local now = getDateTime()
				local dateStr = string.format("%04d-%02d-%02d", now.year, now.mon, now.day)
				local timeStr = string.format("%02d:%02d", now.hour, now.min)

				io.write(logFile, string.format("%s,%s,%s,", nameStr, dateStr, timeStr))
				io.write(logFile, string.format("%s,%4.1f,", sk.landingPts, sk.startHeight))
				io.write(logFile, string.format("%s,%s\n", sk.flightTimer.start, sk.flightTimer.value))

				io.close(logFile)
			end
			
			sk.state = sk.STATE_INITIAL
			sk.target = math.max(60, sk.flightTimer.start)

		elseif event == EVT_VIRTUAL_EXIT then
			 -- Do not record scores if user pressed EXIT
			sk.state = sk.STATE_INITIAL
			sk.target = math.max(60, sk.flightTimer.start)

		end
	end
	
	Draw()
	
end  --  run()

return {run = run}