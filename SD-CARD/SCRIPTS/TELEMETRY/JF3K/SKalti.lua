-- Timing and score keeping, loadable user interface for altimeter based tasks
-- Timestamp: 2019-09-20
-- Created by Jesper Frickmann

local sk = ...  -- List of variables shared between fixed and loadable parts
local exitTask = 0 -- Prompt to save task before EXIT
local stopWindow = 0 -- Prompt to stop flight timer first
local yScaleMax = 50 -- For plotting

local function DrawGraph(dot)
	local xx1
	local xx2
	local xMax = sk.taskWindow / sk.p.heightInt + 1
	
	local yy1
	local yy2
	local m

	-- Rescale if necessary
	if sk.p.ceiling >= yScaleMax then
		yScaleMax = math.ceil(sk.p.ceiling / 25) * 25
	end
	
	if sk.task == sk.p.TASK_THROW_LOW then
		yScaleMax = math.max(100, yScaleMax)
	end
	
	-- Find linear transformation from Y to screen pixel
	m = (12 - LCD_H) / yScaleMax
	
	-- Horizontal grid lines
	for i = 25, yScaleMax, 25 do
		yy1 = m * i + LCD_H - 1
		lcd.drawLine(0, yy1, xMax, yy1, DOTTED, LITE_COLOR)
		lcd.drawNumber(xMax + 1, yy1 - 3, i, SMLSIZE)
	end
	
	-- Vertical grid lines
	for i = 0, sk.taskWindow, 60 do
		xx1 = i / sk.p.heightInt
		lcd.drawLine(xx1, LCD_H, xx1, 8, DOTTED, LITE_COLOR)
	end

	-- Plot the graph
	for i = 1, #sk.p.heights - 1 do
		yy1 = m * sk.p.heights[i] + LCD_H - 1
		yy2 = m * sk.p.heights[i + 1] + LCD_H - 1
		lcd.drawLine(i - 1, yy1, i, yy2, SOLID, FORCE)
		
		-- Rescale if necessary
		if sk.p.heights[i] >= yScaleMax then
			yScaleMax = math.ceil(sk.p.heights[i] / 25) * 25
		end
	end

	-- Line through zero
	lcd.drawLine(0, LCD_H - 1, xMax, LCD_H - 1, SOLID, FORCE)

	-- Draw lines to illustrate scores for recorded flights
	for i = 1, #sk.scores do
		xx1 = (sk.scores[i].start + 10) / sk.p.heightInt
		xx2 = (sk.scores[i].start + sk.scores[i].time) / sk.p.heightInt
		yy1 = m * sk.scores[i].launch + LCD_H - 1

		if sk.task == sk.p.TASK_HEIGHT_GAIN or sk.task == sk.p.TASK_HEIGHT_POKER then
			-- Launch height
			lcd.drawLine(xx1, yy1, xx2, yy1, dot, FORCE)

			-- Max height
			xx1 = sk.scores[i].maxTime / sk.p.heightInt
			yy2 = m * sk.scores[i].maxHeight + LCD_H - 1
			lcd.drawLine(xx1, yy1, xx1, yy2, dot, FORCE)			
		elseif sk.task == sk.p.TASK_THROW_LOW then
			-- Launch height
			yy2 = m * 100 + LCD_H - 1
			lcd.drawLine(xx1, yy1, xx1, yy2, dot, FORCE)
			lcd.drawLine(xx1 - 2, yy1, xx1 + 2, yy1, dot, FORCE)
			lcd.drawLine(xx1 - 2, yy2, xx1 + 2, yy2, dot, FORCE)
		end
		
		-- Flight time
		if sk.task == sk.p.TASK_CEILING then
			xx1 = sk.scores[i].start / sk.p.heightInt
			yy2 = m * sk.p.ceiling + LCD_H - 1
			lcd.drawLine(xx1, LCD_H - 1, xx1, yy2, dot, FORCE)
			lcd.drawLine(xx2, LCD_H - 1, xx2, yy2, dot, FORCE)
		end
	end

	-- Ceiling
	yy1 = m * sk.p.ceiling + LCD_H - 1
	if sk.task == sk.p.TASK_CEILING then
		lcd.drawLine(0, yy1, xMax, yy1, dot, FORCE)
	end
		
	-- Draw lines to illustrate scores for current flight
	if sk.state >=sk.STATE_FLYING and sk.p.launchHeight > 0 then
		xx1 = sk.p.flightStart / sk.p.heightInt
		if model.getTimer(0).start == 0 then
			xx2 = sk.taskWindow / sk.p.heightInt
		else
			xx2 = (sk.p.flightStart + model.getTimer(0).start) / sk.p.heightInt
		end
		
		if sk.task == sk.p.TASK_CEILING then
			-- Flight time
			lcd.drawLine(xx1, LCD_H - 1, xx1, yy1, dot, FORCE)
			lcd.drawLine(xx2, LCD_H - 1, xx2, yy1, dot, FORCE)
		elseif sk.task == sk.p.TASK_HEIGHT_GAIN or sk.task == sk.p.TASK_HEIGHT_POKER then
			-- Ceiling
			lcd.drawLine(xx1, yy1, xx2, yy1, dot, FORCE)
			
			-- Launch height
			xx1 = (sk.p.flightStart + 10) / sk.p.heightInt
			yy1 = m * sk.p.launchHeight + LCD_H - 1
			lcd.drawLine(xx1, yy1, xx2, yy1, dot, FORCE)
		else
			-- Launch height
			xx1 = (sk.p.flightStart + 10) / sk.p.heightInt
			yy1 = m * sk.p.launchHeight + LCD_H - 1
			yy2 = m * 100 + LCD_H - 1
			lcd.drawLine(xx1, yy1, xx1, yy2, dot, FORCE)
			lcd.drawLine(xx1 - 2, yy1, xx1 + 2, yy1, dot, FORCE)
			lcd.drawLine(xx1 - 2, yy2, xx1 + 2, yy2, dot, FORCE)
		end
	end

	-- In height poker, show call
	if sk.task == sk.p.TASK_HEIGHT_POKER and sk.state <= sk.STATE_WINDOW then
		local att = 0
		
		if sk.p.pokerCalled then att = att + BLINK + INVERS end
		lcd.drawText(2, 55, string.format("Call: %im", sk.p.targetGain), att)
	end

	-- Show ceiling
	if sk.task == sk.p.TASK_CEILING and sk.state == sk.STATE_IDLE then
		lcd.drawText(2, 55, string.format("Ceiling: %im", sk.p.ceiling))
	end
end -- DrawGraph()

-- Screen size specific graphics functions
local Draw, PromptScores, NotifyStopWindow, NotifyStopFlight = LoadWxH("JF3K/SKalti.lua", sk, DrawGraph)

local function run(event)
	-- Do we have an altimeter?
	if not sk.p.altId then
		lcd.clear()
		lcd.drawText(10,10,"Altimeter", DBLSIZE)
		lcd.drawText(10,30,"not found", DBLSIZE)
		
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