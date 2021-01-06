-- User interface for several score keeper plugins
-- Timestamp: 2021-01-02
-- Created by Jesper Frickmann

local sk = ...  -- List of variables shared between fixed and loadable parts
local 	exitTask = 0 -- Review scores before EXIT
local stopWindow = 0 -- Notify to stop flight timer first
local selected -- In ReviewScores()
local editing -- In ReviewScores()

-- Screen size specific graphics functions
local ui = soarUtil.LoadWxH("JF5K/SK.lua", sk)
local menu = soarUtil.LoadWxH("MENU.lua") -- Screen size specific menu

local function InitReview()
	-- Are there scores to review?
	if #sk.scores > 0 then
		exitTask = -1
	else
		exitTask = -2
		return
	end
	
	selected = 1
	editing = 0
	menu.title = string.format("Total %i pt.", sk.p.totalScore)

	for i, score in ipairs(sk.scores) do
		menu.items[i] = string.format("%i. %s %4i m.", i, soarUtil.TmrStr(score[1]), score[2])
	end
end

local function ReviewScores(event)
	if event == EVT_VIRTUAL_ENTER then
		editing = editing + 1
		if editing == 3 then 
			editing = 0
			sk.p.UpdateTotal()
		end
	end
	
	if editing == 0 then
		if event == EVT_VIRTUAL_EXIT then 
			return true 
		elseif event == EVT_VIRTUAL_PREV or event == EVT_VIRTUAL_PREV_REPT then
			selected = selected - 1
			if selected == 0 then selected = #menu.items end
		elseif event == EVT_VIRTUAL_NEXT or event == EVT_VIRTUAL_NEXT_REPT then
			selected = selected + 1
			if selected > #menu.items then selected = 1 end
		end
		
		menu.Draw(selected)
		soarUtil.ShowHelp({ enter = "EDIT", ud = "SELECT", exit = "DONE" })		
	else
		local score = sk.scores[selected]
		
		if event == EVT_VIRTUAL_INC or event == EVT_VIRTUAL_INC_REPT then
			score[editing] = score[editing] + 1
		elseif event == EVT_VIRTUAL_DEC or event == EVT_VIRTUAL_DEC_REPT then
			score[editing] = score[editing] - 1
		end
		
		menu.items[selected] = string.format("%i. %s %4i m.", selected, soarUtil.TmrStr(score[1]), score[2])
		ui.DrawEditScore(editing, score)
		soarUtil.ShowHelp({ enter = "NEXT", ud = "CHANGE" })	
	end
end -- ReviewScores()

local function run(event)
	if exitTask == -2 then -- Save scores?
		ui.PromptScores()

		-- Record scores if user pressed ENTER
		if event == EVT_VIRTUAL_ENTER then
			local logFile = io.open("/LOGS/JF F5K Scores.csv", "a")
			if logFile then
				io.write(logFile, string.format("%s,%s", model.getInfo().name, sk.taskName))
				local now = getDateTime()
				io.write(logFile, string.format(",%04i-%02i-%02i", now.year, now.mon, now.day))
				io.write(logFile, string.format(",%02i:%02i", now.hour, now.min))
				io.write(logFile, string.format(",%i", sk.taskScores))
				io.write(logFile, string.format(",%i", sk.p.totalScore))
				io.write(logFile, string.format(",%i", sk.GetStartHeight()))
				
				for i = 1, #sk.scores do
					io.write(logFile, string.format(",%i,%i", sk.scores[i][1], sk.scores[i][2]))
				end
				
				io.write(logFile, "\n")
				io.close(logFile)
			end
			sk.run = sk.menu
		elseif event == EVT_VIRTUAL_EXIT then
			sk.run = sk.menu
		end

	elseif exitTask == -1 then -- Review scores
		if ReviewScores(event) then exitTask = -2 end
		
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
			soarUtil.ShowHelp({ enter = "START WINDOW", exit = "LEAVE TASK" })
		elseif sk.state == sk.STATE_WINDOW then
			soarUtil.ShowHelp({ enter = "STOP WINDOW" })
		else
			soarUtil.ShowHelp({ exit = "SCORE ZERO" })
		end

		if event == EVT_VIRTUAL_ENTER then
			if sk.state <= sk.STATE_PAUSE then
				-- Start task window
				sk.state = sk.STATE_WINDOW
			elseif sk.state == sk.STATE_WINDOW then
				-- Pause task window
				sk.state = sk.STATE_PAUSE
			elseif sk.state >= sk.STATE_LAUNCHING then
				stopWindow = getTime() + 100
			end
			
			playTone(1760, 100, PLAY_NOW)
		end

		if event == EVT_VIRTUAL_EXIT then
			if sk.state == sk.STATE_FLYING or sk.state == sk.STATE_FREEZE then
				-- Record a zero score!
				sk.flightTime = 0
				sk.Score()
				
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
				InitReview()
			else
				exitTask = getTime() + 100
			end
		end
	end
end  --  run()

return { run = run }