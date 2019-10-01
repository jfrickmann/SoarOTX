-- Timing and score keeping, loadable user interface for altimeter based tasks
-- Timestamp: 2019-09-29
-- Created by Jesper Frickmann

local sk = ...  -- List of variables shared between fixed and loadable parts
local exitTask = 0 -- Prompt to save task before EXIT
local stopWindow = 0 -- Prompt to stop flight timer first

-- Screen size specific graphics functions
local Draw, PromptScores, NotifyStopWindow, NotifyStopFlight = soarUtil.LoadWxH("JF3K/SKalti.lua", sk)

local function run(event)
	-- Do we have an altimeter?
	if not sk.p.altId then
		soarUtil.InfoBar("No altimeter")
		
		if event ~= 0 then
			sk.run = sk.menu
		end

	elseif exitTask == -1 then -- Save scores?
		PromptScores()
		
		-- Record scores if user pressed ENTER
		if event == EVT_ENTER_BREAK then
			local logFile = io.open("/LOGS/JF F3K Scores.csv", "a")
			if logFile then
				io.write(logFile, string.format("%s,%s", model.getInfo().name, sk.taskName))

				local now = getDateTime()				
				io.write(logFile, string.format(",%04i-%02i-%02i", now.year, now.mon, now.day))
				io.write(logFile, string.format(",%02i:%02i", now.hour, now.min))
				
				io.write(logFile, string.format(",%s,%i", sk.p.unit, sk.taskScores))
				
				local what = "gain"
				if sk.p.unit == "s" then
					what = "time"
				end
				
				local totalScore = 0
				for i = 1, #sk.scores do
					totalScore = totalScore + sk.scores[i][what]
				end
				io.write(logFile, string.format(",%i", totalScore))
				
				for i = 1, #sk.scores do
					io.write(logFile, string.format(",%i", sk.scores[i][what]))
				end
				
				io.write(logFile, "\n")
				io.close(logFile)
			end
			sk.run = sk.menu
		elseif event == EVT_EXIT_BREAK then
			sk.run = sk.menu
		end

	elseif exitTask > 0 then
		if getTime() > exitTask then
			exitTask = 0
		else
			NotifyStopWindow()
		end
	
	elseif stopWindow > 0 then
		if getTime() > stopWindow then
			stopWindow = 0
		else
			NotifyStopFlight()
		end
	
	else
		Draw()

		-- Toggle quick relaunch QR
		if event == EVT_PLUS_BREAK or event == EVT_ROT_RIGHT or event == EVT_UP_BREAK then
			sk.quickRelaunch = not sk.quickRelaunch
			playTone(1760, 100, PLAY_NOW)
		end
		
		-- Toggle end of window timer stop EoW
		if event == EVT_MINUS_BREAK or event == EVT_ROT_LEFT or event == EVT_DOWN_BREAK then
			sk.eowTimerStop = not sk.eowTimerStop
			playTone(1760, 100, PLAY_NOW)
		end

		if event == EVT_ENTER_BREAK then
			if sk.state <= sk.STATE_PAUSE then
				-- Start task window
				sk.state = sk.STATE_WINDOW
			elseif sk.state == sk.STATE_WINDOW then
				-- Pause task window
				sk.state = sk.STATE_PAUSE
			elseif sk.state >= sk.STATE_READY then
				stopWindow = getTime() + 100
			end
			
			playTone(1760, 100, PLAY_NOW)
		end
		
		if (event == EVT_MENU_LONG or event == EVT_SHIFT_LONG) 
		and (sk.state == sk.STATE_COMMITTED or sk.state == sk.STATE_FREEZE) then
			-- Record a zero score!
			sk.Score(true)
			
			-- Change state
			if sk.winTimer <= 0 or (sk.finalScores and #sk.scores == sk.taskScores) or sk.launches == 0 then
				sk.state = sk.STATE_FINISHED
			else
				sk.state = sk.STATE_WINDOW
			end

			playTone(440, 333, PLAY_NOW)
		end

		if event == EVT_EXIT_BREAK then
			-- Quit task
			if sk.state == sk.STATE_IDLE then
				sk.run = sk.menu
			elseif sk.state == sk.STATE_PAUSE or sk.state == sk.STATE_FINISHED then
				exitTask = -1
			else
				exitTask = getTime() + 100
			end
		end
	end
end  --  run()

return {run = run}