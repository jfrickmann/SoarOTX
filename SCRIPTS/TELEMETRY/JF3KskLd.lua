-- JF F3K Timing and score keeping, loadable part
-- Timestamp: 2018-11-01
-- Created by Jesper Frickmann
-- Telemetry script for timing and keeping scores for the official F3K tasks.

local 	taskList -- List of skLocals.task descriptions for title
local menuReply -- Holds reply from popup menu
local Draw -- Draw() function is defined for specific transmitter

-- Transmitter specific
if tx == TX_X9D then
	taskList = {
		"A. Last flight",
		"B. Two last flights 3:00",
		"B. Two last flights 4:00",
		"C. All up last down",
		"D. Ladder",
		"E. Poker",
		"F. Three best out of six",
		"G. Five best flights",
		"H. 1-2-3-4 in any order",
		"I. Three best flights",
		"J. Three last flights",
		"K. Big Ladder",
		"Quick Relaunch!",
		"Just Fly!"
	}
	skLocals.taskLaunches = {99, 99, 99, 8, 99, 99, 6, 99, 99, 99, 99, 5, 99, 99}
	skLocals.taskScores = {1, 2, 2, 8, 7, 5, 3, 5, 4, 3, 3, 5, 8, 8}

	function Draw()
		local x = 16
		local y = 17
		local split
		local n = skLocals.taskScores[skLocals.task]
		local blnk = getTime() % 100 < 50

		DrawMenu(" " .. taskList[skLocals.task] .. " ")

		-- Draw scores
		if n == 5 or n == 6 then
			split = 4
		else
			split = 5
		end

		for i = 1, n do
			if i == split then
				x = 62
				y = 17
			end

			lcd.drawNumber(x, y, i, RIGHT)
			lcd.drawText(x + 1, y, ". ")

			if i <= #skLocals.scores then
				lcd.drawTimer(x + 6, y, skLocals.scores[i])
			else
				lcd.drawText(x + 6, y, "- - -")
			end

			y = y + 10
		end
		
		lcd.drawText(58, 57, " JF F3K Score Keeper ", SMLSIZE)

		if skLocals.quickRelaunch then
			lcd.drawText(100, 19, "QR", SMLSIZE + INVERS)
		end

		if skLocals.eowTimerStop then
			lcd.drawText(97, 35, "EoW", SMLSIZE + INVERS)
		end

		lcd.drawTimer(172, 16, model.getTimer(0).value, MIDSIZE)
		if skLocals.state >= skLocals.STATE_FLYING then
			lcd.drawText(125, 19, "Flight")
		else
			lcd.drawText(125, 19, "Target")
			if skLocals.pokerCalled and blnk then
				lcd.drawFilledRectangle(124, 16, 80, 12)
			end
		end

		lcd.drawText(125, 35, "Window")
		lcd.drawTimer(172, 32, model.getTimer(1).value, MIDSIZE)

		if skLocals.state >= skLocals.STATE_WINDOW then
			if skLocals.flightTimer < 0 and blnk then
				lcd.drawFilledRectangle(124, 16, 80, 12)
			end

			if skLocals.winTimer < 0 and blnk then
				lcd.drawFilledRectangle(124, 32, 80, 12)
			end

			if skLocals.launchesLeft <= 8 then
				lcd.drawNumber(130, 48, skLocals.launchesLeft, SMLSIZE+RIGHT)
				if skLocals.launchesLeft == 1 then
					lcd.drawText(130, 48, " launch left", SMLSIZE)
				else
					lcd.drawText(130, 48, " launches left", SMLSIZE)
				end
			end

			if skLocals.state >= skLocals.STATE_COMMITTED and skLocals.pokerCalled then
				lcd.drawText(125, 48, "Next call", SMLSIZE)
				lcd.drawTimer(172, 48, PokerTime(), SMLSIZE)
			end

		else

			if skLocals.state == skLocals.STATE_FINISHED then
				lcd.drawText(125, 48, "GAME OVER!", SMLSIZE + BLINK)
			end
		end
	end  --  Draw()
else -- TX_QX7 or X-lite
	taskList = {
		"A. Last 5m",
		"B. Last 2 3m",
		"B. Last 2 4m",
		"C. AULD",
		"D. Ladder",
		"E. Poker",
		"F. Best 3 of 6 ",
		"G. 5 x 2",
		"H. 1-2-3-4",
		"I. Best 3",
		"J. Last 3",
		"K. Big Ladder",
		" Quick Relaunch!",
		" Just Fly!"
	}
	skLocals.taskLaunches = {99, 99, 99, 7, 99, 99, 6, 99, 99, 99, 99, 5, 99, 99}
	skLocals.taskScores = {1, 2, 2, 7, 7, 5, 3, 5, 4, 3, 3, 5, 7, 7}

	function Draw()
		local y = 12
		local n = skLocals.taskScores[skLocals.task]
		local blnk = getTime() % 100 < 50

		DrawMenu(taskList[skLocals.task])
		
		-- Draw scores
		for i = 1, n do
			lcd.drawNumber(10, y, i, RIGHT + SMLSIZE)
			lcd.drawText(10 + 1, y, ". ", SMLSIZE)

			if i <= #skLocals.scores then
				lcd.drawTimer(10 + 6, y, skLocals.scores[i], SMLSIZE)
			else
				lcd.drawText(10 + 6, y, "- - -", SMLSIZE)
			end

			y = y + 7
		end	
		
		lcd.drawText(47, 58, " JF F3K ", SMLSIZE)
		lcd.drawTimer(92, 12, model.getTimer(0).value, MIDSIZE)
		lcd.drawText(70, 33, "Win:")
		lcd.drawTimer(92, 30, model.getTimer(1).value, MIDSIZE)

		if skLocals.quickRelaunch then
			lcd.drawText(53, 15, "QR", SMLSIZE + INVERS)
		end

		if skLocals.eowTimerStop then
			lcd.drawText(50, 33, "EoW", SMLSIZE + INVERS)
		end

		if skLocals.state >= skLocals.STATE_FLYING then
			lcd.drawText(70, 15, "Flt:")
		else
			lcd.drawText(70, 15, "Tgt:")
			if skLocals.pokerCalled and blnk then
				lcd.drawFilledRectangle(69, 10, 55, 14)
			end
		end

		if skLocals.state >= skLocals.STATE_WINDOW then
			if skLocals.flightTimer < 0 and blnk then
				lcd.drawFilledRectangle(69, 10, 55, 12)
			end

			if skLocals.winTimer < 0 and blnk then
				lcd.drawFilledRectangle(69, 30, 55, 12)
			end

			if skLocals.launchesLeft <= 8 then
				lcd.drawNumber(50, 48, skLocals.launchesLeft, SMLSIZE)
				if skLocals.launchesLeft == 1 then
					lcd.drawText(55, 48, " launch left", SMLSIZE)
				else
					lcd.drawText(55, 48, " launches left", SMLSIZE)
				end
			end

			if skLocals.state >= skLocals.STATE_COMMITTED and skLocals.pokerCalled then
				lcd.drawText(50, 48, "Next call", SMLSIZE)
				lcd.drawTimer(92, 48, PokerTime(), SMLSIZE)
			end

		else
			
			if skLocals.state == skLocals.STATE_FINISHED then
				lcd.drawText(50, 48, "GAME OVER!", SMLSIZE + BLINK)
			end
		end
	end -- Draw()
end

-- Find input source from name of input line
local function FindInputSource(lineName)
	for input = 0, 31 do
		for line = 0,  model.getInputsCount(input) - 1 do
			local tbl = model.getInput(input, line)
			if tbl.name == lineName then
				return tbl.source
			end
		end
	end
end  --  FindInputSource()

local function InitializeWindow()
	skLocals.launches = 0
	skLocals.scores = {}
	skLocals.flying = false
	skLocals.comitted = false
	skLocals.pokerCalled = false
	
	if skLocals.task == skLocals.TASK_TURN then
		skLocals.quickRelaunch = true
	else
		skLocals.quickRelaunch = false
	end
	
	-- Give a few extra counts in 1-2-3-4
	if skLocals.task == skLocals.TASK_1234 then
		skLocals.counts = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 15, 20, 30, 45, 60, 65, 70, 75, 120,
			125, 130, 135, 180, 185, 190, 195, 240}
	else
		skLocals.counts = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 15, 20, 30, 45, 60, 120, 180, 240}
	end

	-- Set window timer
	if skLocals.task == skLocals.TASK_AULD or skLocals.task == skLocals.TASK_TURN or skLocals.task == skLocals.TASK_JUSTFL then
		skLocals.winTimer = skLocals.taskWindow[skLocals.task]
	else
		skLocals.winTimer = skLocals.taskWindow[skLocals.task]
	end
	skLocals.winTimerOld = skLocals.winTimer

	model.setTimer(1, { start=skLocals.winTimer, value=skLocals.winTimer })
	SetFlightTimer()
	skLocals.state = skLocals.STATE_IDLE
end  --  InitializeWindow()

local function init()
	saveTask = 0
	menuReply = 0

	-- Only initialize once
	if skLocals.initialized then
		return
	end
	
	skLocals.pokerMinId = FindInputSource("Mins")
	skLocals.pokerSecId = FindInputSource("Secs")
	skLocals.finalScores = {false, false, false, true, true, true, false, false, false, false, false, true, false, false}
	skLocals.taskScoreTypes = {1, 1, 1, 1, 3, 3, 2, 2, 2, 2, 1, 1, 1, 1}
	skLocals.taskWindow = {420, 420, 600, 0, 600, 600, 600, 600, 600, 600, 600, 600, 0, 0}
	
	skLocals.initialized = true -- skLocals are now completely initialized
	
	InitializeWindow()
end  --  Init()

local function run(event)
	if saveTask ~= 0 then -- Popup menu active
		menuReply = popupInput("Save scores?", event, 0, 0, 0)

		-- Record scores if user pressed ENTER
		if menuReply == "OK" then
			local now = getDateTime()
			local dateStr = string.format("%04d-%02d-%02d", now.year, now.mon, now.day)
			local timeStr = string.format("%02d:%02d", now.hour, now.min)
			local nameStr = model.getInfo().name
			local logFile = io.open("/LOGS/JF F3K Scores.csv", "a")
			if logFile then
				io.write(logFile, string.format("%s,%s,%s,%s", nameStr, taskList[saveTask], dateStr, timeStr))
				for i = 1, #skLocals.scores do
					io.write(logFile, string.format(",%d", skLocals.scores[i]))
				end
				io.write(logFile, "\n")
				io.close(logFile)
			end
		end

		-- Dismiss the popup menu and move on
		if menuReply ~= 0 then
			saveTask = 0
			menuReply = 0
			InitializeWindow()
		end

	else
		Draw()

		if skLocals.state <= skLocals.STATE_PAUSE then
			if event == EVT_ENTER_BREAK then
				-- Add 10 sec. to window timer, if a new task is started
				if skLocals.state == skLocals.STATE_IDLE and skLocals.winTimer > 0 then
					skLocals.winTimer = skLocals.winTimer + 10
					model.setTimer(1, { start=skLocals.winTimer, value=skLocals.winTimer })
				end

				-- Start task window
				skLocals.state = skLocals.STATE_WINDOW
				playTone(1760, 100, PLAY_NOW)
			end
		elseif skLocals.state == skLocals.STATE_WINDOW then
			if event == EVT_ENTER_BREAK then
				-- Pause task window
				skLocals.state = skLocals.STATE_PAUSE
				playTone(1760, 100, PLAY_NOW)
			end
		elseif skLocals.state == skLocals.STATE_COMMITTED then
			if event == EVT_MENU_LONG or event == EVT_SHIFT_LONG then
				-- Record a zero score!
				if skLocals.taskScoreTypes[skLocals.task] == 1 then
					RecordLast(skLocals.scores, 0)
				elseif skLocals.taskScoreTypes[skLocals.task] == 2 then
					RecordBest(skLocals.scores, 0)
				end
				
				-- Change state
				if skLocals.launches == skLocals.taskLaunches[skLocals.task] or skLocals.winTimer < 0 or
				   (skLocals.finalScores[skLocals.task] and #skLocals.scores == skLocals.taskScores[skLocals.task]) then
					skLocals.state = skLocals.STATE_FINISHED
				else
					skLocals.state = skLocals.STATE_WINDOW
				end

				playTone(440, 333, PLAY_NOW)
			end
		end
			
		if skLocals.state <= skLocals.STATE_FINISHED then
			local change = 0
			
			-- Change task
			if event == EVT_PLUS_BREAK or event == EVT_ROT_RIGHT or event == EVT_RIGHT_BREAK then
				change = 1
			end

			if event == EVT_MINUS_BREAK or event == EVT_ROT_LEFT or event == EVT_LEFT_BREAK then
				change = -1
			end
			
			if change ~= 0 then
				-- Show popup menu to save scores
				if skLocals.state > skLocals.STATE_IDLE then
					saveTask = skLocals.task
				end
				
				skLocals.task = skLocals.task + change
				
				if skLocals.task > #taskList then 
					skLocals.task = 1 
				elseif skLocals.task < 1 then 
					skLocals.task = #taskList
				end
				
				-- Do not show popup menu to save scores
				if skLocals.state == skLocals.STATE_IDLE then
					InitializeWindow()
				end
			end

		else
			-- Toggle quick relaunch QR
			if event == EVT_PLUS_BREAK or event == EVT_ROT_RIGHT or event == EVT_UP_BREAK then
				skLocals.quickRelaunch = not skLocals.quickRelaunch
				playTone(1760, 100, PLAY_NOW)
			end
			
			-- Toggle end of window timer stop EoW
			if event == EVT_MINUS_BREAK or event == EVT_ROT_LEFT or event == EVT_DOWN_BREAK then
				skLocals.eowTimerStop = not skLocals.eowTimerStop
				playTone(1760, 100, PLAY_NOW)
			end
		end
	end
end  --  run()

return {init = init, run = run}