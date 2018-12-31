-- Timing and score keeping, loadable plugin part for altimeter based tasks
-- Timestamp: 2018-12-28
-- Created by Jesper Frickmann

-- Task index constants, shared between task definition and UI
local TASK_HEIGHT_GAIN = 1
local TASK_1ST2GAIN50 = 2
local TASK_CEILING = 3
local TASK_THROW_LOW = 4
local TASK_HEIGHT_POKER = 5

-- If no task is selected, then return name and task list to the menu
if sk.task == 0 then
	local name = "Altimeter"

	local tasks = {
		"V. Height gain",	
		"W. First to +50",
		"X. Under ceiling",
		"Y. Throw low 2:00",
		"Z. Height Poker"
	}

	return name, tasks
end

-- Setup task definition. Only if we are still in STATE_IDLE
if sk.state == sk.STATE_IDLE then
	local Ceiling -- Function returning height ceiling
	local RecordScore -- Function for recording scores
	
	local ceilingType -- Type of Ceiling function
	local targetTime -- Target time
	local scoreType -- Type of function recording score
	local altMaxId -- Input ID for the max. Alt sensor
	local flightData -- Time and height data for flight to be scored
	local winTimerOld = sk.winTimer
	local lastWarning = 0 -- Last time a warning that height is close to the ceiling was played
	
	--  Variables shared between task def. and UI must be added to own list
	plugin = { }
	plugin.heights = { } -- Time series of recorded heights for graph
	plugin.ceiling = 0 -- Ceiling where timer is stopped
	plugin.launchHeight = 0 -- Launch height is recorded after 10 sec.
	plugin.maxHeight = 0 -- Max. recorded height
	plugin.maxTime = 0 -- Time of max. height
	plugin.flightStart = 0 -- Time of flight start
	plugin.targetGain = 0 -- Target for height gain
	
	if tx == TX_X9D then
		plugin.heightInt = 4 -- Interval for recording heights
	else -- TX_QX7 or X-lite
		plugin.heightInt = 7
	end
	
	do
		-- Find input IDs if Alt sensor is configured
		local alt = getFieldInfo("Alti")
		if alt then
			plugin.altId = alt.id
			altMaxId = getFieldInfo("Alti+").id
		else	
			alt = getFieldInfo("Alt")
			if alt then
				plugin.altId = alt.id
				altMaxId = getFieldInfo("Alt+").id
			end
		end

		local taskData = {
			{ 3, false, 1, 0, 1 }, -- Height gain
			{ 1, false, 1, 0, 2 }, -- First to gain 50
			{ 1, false, 2, 300, 3 }, -- Under ceiling
			{ 3, false, 3, 120, 4 }, -- Throw low 2:00
			{ 3, true,  4, 0, 5 } -- Height poker
		}
		
		sk.taskWindow = 420
		sk.taskScores = taskData[sk.task][1]
		sk.finalScores = taskData[sk.task][2]

		ceilingType = taskData[sk.task][3]
		targetTime = taskData[sk.task][4]
		scoreType = taskData[sk.task][5]

	end

	-- Ceiling function
	if ceilingType == 1 then -- Set ceiling to launch + 50
		Ceiling = function()
			plugin.targetGain = 50
			
			if plugin.launchHeight == 0 then
				return 0
			else
				return plugin.launchHeight + plugin.targetGain
			end
		end
	elseif ceilingType == 2 then -- Set ceiling with knob
		Ceiling = function()
			if sk.state == sk.STATE_IDLE then
				return 50 + 5 * math.floor(0.99 + getValue(sk.set1id) / 204.8)
			else
				return plugin.ceiling
			end

		end
	elseif ceilingType == 3 then -- No ceiling
		Ceiling = function() 
			return 0 
		end
	else -- Set ceiling to launch + adjustable
		Ceiling = function()
			if not plugin.pokerCalled then
				plugin.targetGain = 25 + math.floor(0.99 + getValue(sk.set1id) / 41)
			end
			 
			if plugin.launchHeight == 0 then
				return 0
			else
				return plugin.launchHeight + plugin.targetGain
			end
		end
	end

	-- TargetTime function
	sk.TargetTime = function()
		return targetTime
	end
	
	-- Score function
	if scoreType == 1 then -- Best height gains
		RecordScore = function(flightData)
			local n = #sk.scores
			local i = 1
			local j = 0

			-- Find the position where the new score is going to be inserted
			if n == 0 then
				j = 1
			else
				-- Find the first position where existing score is smaller than the new score
				while i <= n and j == 0 do
					if flightData.gain > sk.scores[i].gain then j = i end
					i = i + 1
				end
				
				if j == 0 then j = i end -- New score is smallest; end of the list
			end

			-- If the list is not yet full; let it grow
			if n < sk.taskScores then n = n + 1 end

			-- Insert the new score and move the following scores down the list
			for i = j, n do
				flightData, sk.scores[i] = sk.scores[i], flightData
			end
		end -- RecordScore()
		
	elseif scoreType == 2 then -- 1st to gain 50
		RecordScore = function(flightData)
			-- Record flight if gain improved over previous
			if #sk.scores == 0 or flightData.gain > sk.scores[1].gain then
				sk.scores[1] = flightData
			end
			
			-- If we made it to the target, then the task is finished
			if flightData.maxHeight >= plugin.ceiling and plugin.ceiling > 0 then
				sk.finalScores = true
			end
		end -- RecordScore()
		
	elseif scoreType == 3 then -- Ceiling; record last flight
		RecordScore = function(flightData)
			sk.scores[1] = flightData
		end -- RecordScore()
		
	elseif scoreType == 4 then -- Throw Low
		RecordScore = function(flightData)
			-- Did we get a launch height and make the time?
			if flightData.launch > 0 and flightData.time >= targetTime then
				-- Score is 100 - launch height
				flightData.gain = 100 - flightData.launch
				sk.scores[#sk.scores + 1] = flightData
			end
		end -- RecordScore()

	else -- Height Poker
		RecordScore = function(flightData)
			-- Did make the call?
			if flightData.gain >= plugin.targetGain then
				flightData.gain = plugin.targetGain
				sk.scores[#sk.scores + 1] = flightData
				plugin.pokerCalled = false
			end
		end -- RecordScore()
		
	end

	sk.Score = function(zero)
		-- Record scores
		local flightData = {
			time = sk.flightTime,
			start = plugin.flightStart,
			launch = plugin.launchHeight,
			maxHeight = plugin.maxHeight,
			maxTime = plugin.maxTime,
			gain = plugin.maxHeight - plugin.launchHeight
		}
		
		if zero or plugin.launchHeight == 0 then
			flightData.time = 0
			flightData.gain = 0
		end

		RecordScore(flightData)
	end -- sk.Score()
	
	sk.Background = function()
		plugin.ceiling = Ceiling()
	
		if sk.state >= sk.STATE_WINDOW then
			-- Save height timeseries
			if sk.winTimer >=0 and sk.winTimer <= model.getTimer(1).start and 
			math.floor(sk.winTimer / plugin.heightInt) ~= math.floor(winTimerOld / plugin.heightInt) then
				plugin.heights[#plugin.heights + 1] = getValue(plugin.altId)			
			end

			if sk.state == sk.STATE_READY then
				plugin.launchHeight = 0
				plugin.maxHeight = 0
				plugin.maxTime = 0
				plugin.flightStart = 0
			end
			
			if sk.state >= sk.STATE_FLYING then
				if plugin.flightStart == 0 then
					plugin.flightStart = math.abs(model.getTimer(1).start - sk.winTimer)
				end
				
				if sk.state < sk.STATE_FREEZE then
					-- Update launch and max. height
					local mh = getValue(altMaxId)
					local now = getTime()
					
					if plugin.launchHeight == 0 and sk.flightTime > 10 then
						plugin.launchHeight = mh
					end
					
					if mh > plugin.maxHeight then
						plugin.maxHeight = mh
						plugin.maxTime = sk.flightTime + plugin.flightStart
					end
					
					mh = getValue(plugin.altId)
					if plugin.ceiling > 0 and mh >= plugin.ceiling - 3 and lastWarning < now then
						playNumber(mh, 9)
						lastWarning = now + 300
					end

					-- If height ceiling is broken, then freeze the flight timer
					if plugin.ceiling > 0 and plugin.maxHeight > plugin.ceiling then
						sk.state = sk.STATE_FREEZE
						playTone(1760, 100, PLAY_NOW)
					end
				end
				
				if sk.state == sk.STATE_COMMITTED then
					-- Call Poker
					if sk.task == TASK_HEIGHT_POKER then 
						plugin.pokerCalled = true
					end				
				end
			end
		end

		winTimerOld = sk.winTimer
	end -- sk.Background()

end  --  If STATE_IDLE

-- User interface follows in own closure to allow cleanly unloading if another telemetry screen is activated
do
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
end