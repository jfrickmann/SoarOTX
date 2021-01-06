-- Timing and score keeping, loadable user interface for altimeter based tasks
-- Timestamp: 2020-04-27
-- Created by Jesper Frickmann

local sk = ...  -- List of variables shared between fixed and loadable parts
local exitTask = 0 -- Prompt to save task before EXIT
local stopWindow = 0 -- Prompt to stop flight timer first

-- Screen size specific graphics functions
local ui = soarUtil.LoadWxH("JF3K/SKalti.lua", sk)

-- Draw lines to illustrate scores for recorded flights
function ui.DrawLines()
	local yCeil
	local tStart
	local tLaunch
	local yLaunch
	local tEnd
	
	for i = 1, #sk.scores do
		local tTop = sk.scores[i].maxTime
		local yTop = sk.scores[i].maxHeight

		tStart = sk.scores[i].start
		tLaunch = tStart + 10
		yLaunch = sk.scores[i].launch
		tEnd = tStart + sk.scores[i].time

		if sk.task == sk.p.TASK_HEIGHT_GAIN or sk.task == sk.p.TASK_HEIGHT_POKER then
			-- Launch and max height
			ui.DrawLine(tLaunch, yLaunch, tEnd, yLaunch)
			ui.DrawLine(tTop, yLaunch, tTop, yTop)
		end
		
		if sk.task == sk.p.TASK_THROW_LOW then
			-- Launch height
			ui.DrawLine(tLaunch, yLaunch, tLaunch, 100)
			ui.DrawLine(tLaunch - 2, yLaunch, tLaunch + 2, yLaunch)
			ui.DrawLine(tLaunch - 2, 100, tLaunch + 2, 100)
		end
		
		if sk.task == sk.p.TASK_CEILING then
			-- Flight time
			ui.DrawLine(tStart, 0, tStart, yTop)
			ui.DrawLine(tEnd, 0, tEnd, yTop)
		end
	end

	yCeil = sk.p.ceiling
	tStart = sk.p.flightStart
	tLaunch = tStart + 10
	yLaunch = sk.p.launchHeight
	
	if model.getTimer(0).start == 0 then
		tEnd = sk.taskWindow
	else
		tEnd = tStart + model.getTimer(0).start
	end

	-- Ceiling
	if sk.task == sk.p.TASK_CEILING then
		ui.DrawLine(0, yCeil, tEnd, yCeil)
	end
		
	-- Draw lines to illustrate scores for current flight
	if sk.state >=sk.STATE_FLYING and yLaunch > 0 then
		if sk.task == sk.p.TASK_CEILING or task == sk.p.TASK_THROW_LOW then
			-- Flight time
			ui.DrawLine(tStart, 0, tStart, yCeil)
			ui.DrawLine(tEnd, 0, tEnd, yCeil)
		end
		
		if sk.task == sk.p.TASK_HEIGHT_GAIN or sk.task == sk.p.TASK_HEIGHT_POKER then
			-- Ceiling and launch height
			ui.DrawLine(tLaunch, yLaunch, tEnd, yLaunch)
			ui.DrawLine(tLaunch, yCeil, tEnd, yCeil)
		end
		
		if sk.task == sk.p.TASK_THROW_LOW then
			-- Launch height
			ui.DrawLine(tLaunch, yLaunch, tLaunch, 100)
			ui.DrawLine(tLaunch - 2, yLaunch, tLaunch + 2, yLaunch)
			ui.DrawLine(tLaunch - 2, 100, tLaunch + 2, 100)
		end
	end
end -- DrawLines()

local function run(event)
	if exitTask == -1 then -- Save scores?
		ui.PromptScores()
		
		-- Record scores if user pressed ENTER
		if event == EVT_VIRTUAL_ENTER then
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
		elseif event == EVT_VIRTUAL_EXIT then
			sk.run = sk.menu
		end

	elseif exitTask > 0 then
		if getTime() > exitTask then
			exitTask = 0
		else
			ui.NotifyStopWindow()
		end
	
	elseif stopWindow > 0 then
		if getTime() > stopWindow then
			stopWindow = 0
		else
			ui.NotifyStopFlight()
		end
	
	else
		ui.Draw()

		-- Show onscreen help
		if sk.state <= sk.STATE_PAUSE then
			soarUtil.ShowHelp({ enter = "START WINDOW", exit = "LEAVE TASK", up = "QUICK RELAUNCH", down = "FREEZE TIMER at EoW" })
		elseif sk.state == sk.STATE_WINDOW then
			soarUtil.ShowHelp({ enter = "STOP WINDOW", up = "QUICK RELAUNCH", down = "FREEZE TIMER at EoW" })
		elseif sk.state < sk.STATE_COMMITTED then
			soarUtil.ShowHelp({ up = "QUICK RELAUNCH", down = "FREEZE TIMER at EoW" })
		else
			soarUtil.ShowHelp({ exit = "SCORE ZERO", up = "QUICK RELAUNCH", down = "FREEZE TIMER at EoW" })
		end

		-- Toggle quick relaunch QR
		if event == EVT_VIRTUAL_PREV or event == EVT_VIRTUAL_PREV_REPT then
			sk.quickRelaunch = not sk.quickRelaunch
			playTone(1760, 100, PLAY_NOW)
		end
		
		-- Toggle end of window timer stop EoW
		if event == EVT_VIRTUAL_NEXT or event == EVT_VIRTUAL_NEXT_REPT then
			sk.eowTimerStop = not sk.eowTimerStop
			playTone(1760, 100, PLAY_NOW)
		end

		if event == EVT_VIRTUAL_ENTER then
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
		
		if event == EVT_VIRTUAL_EXIT then
			if sk.state == sk.STATE_COMMITTED or sk.state == sk.STATE_FREEZE then
				-- Record a zero score!
				sk.Score(true)
				
				-- Change state
				if sk.winTimer <= 0 or (sk.finalScores and #sk.scores == sk.taskScores) or sk.launches == 0 then
					sk.state = sk.STATE_FINISHED
				else
					sk.state = sk.STATE_WINDOW
				end

				playTone(440, 333, PLAY_NOW)
			elseif sk.state == sk.STATE_IDLE then
				-- Quit task
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