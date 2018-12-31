-- Timing and score keeping, loadable user interface for altimeter based tasks
-- Timestamp: 2018-12-31
-- Created by Jesper Frickmann

local 	exitTask = 0 -- Prompt to save task before EXIT
local stopWindow = 0 -- Prompt to stop flight timer first
local yScaleMax = 50 -- For plotting

local Draw -- Function to draw the screen for specific transmitter

local function DrawGraph(dot)
	local xx1
	local xx2
	local xMax = sk.taskWindow / plugin.heightInt + 1
	
	local yy1
	local yy2
	local m

	-- Rescale if necessary
	if plugin.ceiling >= yScaleMax then
		yScaleMax = math.ceil(plugin.ceiling / 25) * 25
	end
		
	-- Find linear transformation from Y to screen pixel
	m = (12 - LCD_H) / yScaleMax
	
	-- Horizontal grid lines
	for i = 25, yScaleMax, 25 do
		yy1 = m * i + LCD_H - 1
		lcd.drawLine(0, yy1, xMax, yy1, DOTTED, GRAY)
		lcd.drawNumber(xMax + 1, yy1 - 3, i, SMLSIZE)
	end
	
	-- Vertical grid lines
	for i = 0, sk.taskWindow, 60 do
		xx1 = i / plugin.heightInt
		lcd.drawLine(xx1, LCD_H, xx1, 8, DOTTED, GRAY)
	end

	-- Plot the graph
	for i = 1, #plugin.heights - 1 do
		yy1 = m * plugin.heights[i] + LCD_H - 1
		yy2 = m * plugin.heights[i + 1] + LCD_H - 1
		lcd.drawLine(i - 1, yy1, i, yy2, SOLID, FORCE)
		
		-- Rescale if necessary
		if plugin.heights[i] >= yScaleMax then
			yScaleMax = math.ceil(plugin.heights[i] / 25) * 25
		end
	end

	-- Line through zero
	lcd.drawLine(0, LCD_H - 1, xMax, LCD_H - 1, SOLID, FORCE)

	-- Draw lines to illustrate scores for recorded flights
	for i = 1, #sk.scores do
		xx1 = (sk.scores[i].start + 10) / plugin.heightInt
		xx2 = (sk.scores[i].start + sk.scores[i].time) / plugin.heightInt
		yy1 = m * sk.scores[i].launch + LCD_H - 1

		-- Launch height
		if sk.task == TASK_HEIGHT_GAIN or sk.task == TASK_HEIGHT_POKER then
			lcd.drawLine(xx1, yy1, xx2, yy1, dot, FORCE)
		elseif sk.task == TASK_THROW_LOW then
			yy2 = m * 100 + LCD_H - 1
			lcd.drawLine(xx1, yy1, xx1, yy2, dot, FORCE)
			lcd.drawLine(xx1 - 2, yy2, xx1 + 2, yy2, dot, FORCE)
		end
		
		-- Flight time
		if sk.task == TASK_CEILING then
			yy1 = m * yScaleMax + LCD_H - 1
			lcd.drawLine(xx1, 63, xx1, yy1, dot, FORCE)
			lcd.drawLine(xx2, 63, xx2, yy1, dot, FORCE)
		end
		
		-- Max height
		if sk.task ~= TASK_THROW_LOW and sk.task ~= TASK_1ST2GAIN50 then
			xx1 = sk.scores[i].maxTime / plugin.heightInt
			yy1 = m * sk.scores[i].launch + LCD_H - 1
			yy2 = m * sk.scores[i].maxHeight + LCD_H - 1
			lcd.drawLine(xx1, yy1, xx1, yy2, dot, FORCE)
		end

		-- Climb rate in 1st to +50
		if sk.task == TASK_1ST2GAIN50 then
			xx1 = sk.scores[i].maxTime / plugin.heightInt
			
			if sk.scores[i].gain >= plugin.targetGain then
				xx2 = xx1
			else
				xx2 = sk.taskWindow / plugin.heightInt
			end
			
			yy1 = m * sk.scores[i].launch + LCD_H - 1
			yy2 = m * sk.scores[i].maxHeight + LCD_H - 1

			lcd.drawLine(0, yy1, xx1, yy1, dot, FORCE)
			lcd.drawLine(xx1, yy1, xx1, yy2, dot, FORCE)

			if sk.state == sk.STATE_FINISHED then
				lcd.drawLine(xx1, yy2, xx2, yy2, dot, FORCE)
				lcd.drawLine(0, yy1, xx2, yy2, dot, FORCE)

				-- Calculate final score as time to gain 50 m, possibly extrapolating
				if sk.scores[i].gain == 0 then
					sk.scores[i].time = 0
				elseif sk.scores[i].gain >= plugin.targetGain then
					sk.scores[i].time = sk.scores[i].maxTime
				else
					sk.scores[i].time = plugin.targetGain / sk.scores[i].gain * sk.taskWindow
				end
			end
		end
	end

	-- Draw lines to illustrate scores for current flight
	if sk.state >=sk.STATE_FLYING and plugin.launchHeight > 0 then
		xx1 = (plugin.flightStart + 10) / plugin.heightInt
		if model.getTimer(0).start == 0 then
			xx2 = sk.taskWindow / plugin.heightInt
		else
			xx2 = (plugin.flightStart + model.getTimer(0).start) / plugin.heightInt
		end
		
		-- Launch height
		if sk.task ~= TASK_CEILING then
			yy1 = m * plugin.launchHeight + LCD_H - 1
			lcd.drawLine(xx1, yy1, xx2, yy1, dot, FORCE)
		end

		-- Ceiling
		if sk.task ~= TASK_THROW_LOW then
			yy1 = m * plugin.ceiling + LCD_H - 1
			lcd.drawLine(xx1, yy1, xx2, yy1, dot, FORCE)
		end

		-- Flight time
		if sk.task == TASK_CEILING then
			yy1 = m * yScaleMax + LCD_H - 1
			lcd.drawLine(xx1, 63, xx1, yy1, dot, FORCE)
			lcd.drawLine(xx2, 63, xx2, yy1, dot, FORCE)
		end
	end

	-- In height poker, show call
	if sk.task == TASK_HEIGHT_POKER and sk.state <= sk.STATE_WINDOW then
		local att = 0
		
		if plugin.pokerCalled then att = att + BLINK + INVERS end
		lcd.drawText(2, 55, string.format("Call: %02dm", plugin.targetGain), att)
	end

	-- Show ceiling
	if sk.task == TASK_CEILING and sk.state == sk.STATE_IDLE then
		lcd.drawText(2, 55, string.format("Ceiling: %02dm", plugin.ceiling))
	end
end -- DrawGraph()

if tx == TX_X9D then
	function Draw()
		local att
		
		DrawMenu(sk.taskName)
		DrawGraph(DOTTED)
		
		-- Timers
		lcd.drawText(LCD_W - 46, 15, "W")
		
		if sk.state == sk.STATE_FINISHED then
			att = BLINK + INVERS
		else
			att = 0
		end
		
		lcd.drawTimer(LCD_W - 32, 12, sk.winTimer, MIDSIZE + att)

		lcd.drawText(LCD_W - 46, 33, "F")
		
		if sk.flightTimer < 0 then
			att = BLINK + INVERS
		else
			att = 0
		end
		
		lcd.drawTimer(LCD_W - 32, 30, sk.flightTimer,  MIDSIZE + att)

		-- QR and EoW
		if sk.eowTimerStop then
			lcd.drawText(LCD_W - 18, 50, "EoW", SMLSIZE + INVERS)
		end
		
		if sk.quickRelaunch then
			lcd.drawText(LCD_W - 33, 50, "QR", SMLSIZE + INVERS)
		end

		-- Scores
		for i = 1, sk.taskScores do
			local x = 86
			local dy = 14
			
			lcd.drawNumber(LCD_W - x, dy * i, i)
			lcd.drawText(LCD_W - x + 6, dy * i, ".")
			
			if i > #sk.scores then
				lcd.drawText(LCD_W - x + 10, dy * i, "- - -")
			elseif sk.task == TASK_1ST2GAIN50 then
				if sk.state == sk.STATE_FINISHED then
					lcd.drawTimer(LCD_W - x + 10, dy * i, sk.scores[i].time)
				else
					lcd.drawText(LCD_W - x + 10, dy * i, "---")
				end
			elseif sk.task == TASK_THROW_LOW then
				lcd.drawText(LCD_W - x + 10, dy * i, string.format("%02dp", sk.scores[i].gain))
			elseif sk.task == TASK_HEIGHT_GAIN or sk.task == TASK_HEIGHT_POKER then
				lcd.drawText(LCD_W - x + 10, dy * i, string.format("%02dm", sk.scores[i].gain))
			else
				lcd.drawTimer(LCD_W - x + 10, dy * i, sk.scores[i].time)
			end
		end
	end  --  Draw()

else -- TX_QX7 or X-lite
	function Draw()
		local att
		
		DrawMenu(sk.taskName)
		DrawGraph(SOLID)
		
		-- Timers
		if sk.state == sk.STATE_FINISHED then
			att = BLINK + INVERS
		else
			att = 0
		end
		
		lcd.drawTimer(LCD_W, 12, sk.winTimer, MIDSIZE + RIGHT + att)

		if sk.flightTimer < 0 then
			att = BLINK + INVERS
		else
			att = 0
		end
		
		lcd.drawTimer(LCD_W, 30, sk.flightTimer,  MIDSIZE + RIGHT + att)

		-- QR and EoW
		if sk.eowTimerStop then
			lcd.drawText(LCD_W - 18, 50, "EoW", SMLSIZE + INVERS)
		end
		
		if sk.quickRelaunch then
			lcd.drawText(LCD_W - 33, 50, "QR", SMLSIZE + INVERS)
		end

		-- Scores
		for i = 1, sk.taskScores do
			local x = 62
			local dy = 14
			
			if i > #sk.scores then
				lcd.drawText(LCD_W - x + 10, dy * i, "---")
			elseif sk.task == TASK_1ST2GAIN50 then
				if sk.state == sk.STATE_FINISHED then
					lcd.drawTimer(LCD_W - x + 10, dy * i, sk.scores[i].time)
				else
					lcd.drawText(LCD_W - x + 10, dy * i, "---")
				end
			elseif sk.task == TASK_THROW_LOW then
				lcd.drawText(LCD_W - x + 10, dy * i, string.format("%02dp", sk.scores[i].gain))
			elseif sk.task == TASK_HEIGHT_GAIN or sk.task == TASK_HEIGHT_POKER then
				lcd.drawText(LCD_W - x + 10, dy * i, string.format("%02dm", sk.scores[i].gain))
			else
				lcd.drawTimer(LCD_W - x + 10, dy * i, sk.scores[i].time)
			end
		end
	end  --  Draw()
end

local function run(event)
	-- Do we have an altimeter?
	if not plugin.altId then
		lcd.clear()
		lcd.drawText(10,10,"Altimeter", DBLSIZE)
		lcd.drawText(10,30,"not found", DBLSIZE)
		
		if event ~= 0 then
			sk.run = sk.menu
		end

	elseif exitTask == -1 then -- Popup menu active
		local menuReply = popupInput("Save scores?", event, 0, 0, 0)

		-- Record scores if user pressed ENTER
		if menuReply == "OK" then
			local now = getDateTime()
			local dateStr = string.format("%04d-%02d-%02d", now.year, now.mon, now.day)
			local timeStr = string.format("%02d:%02d", now.hour, now.min)
			local nameStr = model.getInfo().name
			local logFile = io.open("/LOGS/JF F3K Scores.csv", "a")
			if logFile then
				io.write(logFile, string.format("%s,%s,%s,%s", nameStr, sk.taskName, dateStr, timeStr))
				for i = 1, #sk.scores do
					if sk.task == TASK_HEIGHT_GAIN or sk.task == TASK_HEIGHT_POKER then
						io.write(logFile, string.format(",%im", sk.scores[i].gain))
					elseif sk.task == TASK_THROW_LOW then
						io.write(logFile, string.format(",%ip", sk.scores[i].gain))
					else
						io.write(logFile, string.format(",%i", sk.scores[i].time))
					end
				end
				io.write(logFile, "\n")
				io.close(logFile)
			end
		end

		-- Dismiss the popup menu and move on
		if menuReply ~= 0 then
			sk.run = sk.menu
		end

	elseif exitTask > 0 then
		if getTime() > exitTask then
			exitTask = 0
		else
			if tx == TX_X9D then
				DrawMenu(" " .. sk.taskName .. " ")
				lcd.drawText(38, 18, "Stop window timer", MIDSIZE)
				lcd.drawText(38, 40, "before leaving task.", MIDSIZE)
			else -- TX_QX7 or X-lite
				DrawMenu(sk.taskName)
				lcd.drawText(8, 15, "Stop window", MIDSIZE)
				lcd.drawText(8, 30, "timer before", MIDSIZE)
				lcd.drawText(8, 45, "leaving task.", MIDSIZE)
			end
		end
	
	elseif stopWindow > 0 then
		if getTime() > stopWindow then
			stopWindow = 0
		else
			if tx == TX_X9D then
				DrawMenu(" " .. sk.taskName .. " ")
				lcd.drawText(30, 18, "Stop the flight timer", MIDSIZE)
				lcd.drawText(30, 40, "before pausing window.", MIDSIZE)
			else -- TX_QX7 or X-lite
				DrawMenu(sk.taskName)
				lcd.drawText(8, 15, "Stop the flight", MIDSIZE)
				lcd.drawText(8, 30, "timer before", MIDSIZE)
				lcd.drawText(8, 45, "pausing window.", MIDSIZE)
			end
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
			-- Add 10 sec. to window timer, if a new task is started
			if sk.state == sk.STATE_IDLE and sk.winTimer > 0 then
				sk.winTimer = sk.winTimer + 10
				model.setTimer(1, { start=sk.winTimer, value=sk.winTimer })
			end

			if sk.state <= sk.STATE_PAUSE then
				-- Start task window
				sk.state = sk.STATE_WINDOW
				playTone(1760, 100, PLAY_NOW)
			elseif sk.state == sk.STATE_WINDOW then
				-- Pause task window
				sk.state = sk.STATE_PAUSE
				playTone(1760, 100, PLAY_NOW)
			elseif sk.state >= sk.STATE_READY then
				stopWindow = getTime() + 100
			end
		end
		
		if (event == EVT_MENU_LONG or event == EVT_SHIFT_LONG) and sk.state == sk.STATE_COMMITTED then
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