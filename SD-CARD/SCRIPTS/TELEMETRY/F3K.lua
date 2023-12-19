---------------------------------------------------------------------------
-- Soar F3K score keeper script for BW 128x64 screen radios running      --
-- OpenTX or EdgeTX                                                      --
--                                                                       --
-- Author:  Jesper Frickmann                                             --
-- Date:    2023-12-18                                                   --
-- Version: 1.0.1                                                        --
--                                                                       --
-- Copyright (C) 2023 OpenTX and EdgeTX                                  --
--                                                                       --
-- License GPLv2: http://www.gnu.org/licenses/gpl-2.0.html               --
--                                                                       --
-- This program is free software; you can redistribute it and/or modify  --
-- it under the terms of the GNU General Public License version 2 as     --
-- published by the Free Software Foundation.                            --
--                                                                       --
-- This program is distributed in the hope that it will be useful        --
-- but WITHOUT ANY WARRANTY; without even the implied warranty of        --
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         --
-- GNU General Public License for more details.                          --
---------------------------------------------------------------------------

-- Constants
local SCORE_LOG =	"/LOGS/F3K scores.csv"
local SCORE_SIZE = 20				-- Max. no. of score records in file

-- Program states
local STATE_IDLE = 1				-- Task window not running
local STATE_PAUSE = 2		 		-- Task window paused, not flying
local STATE_FINISHED = 3		-- Task has been finished
local STATE_WINDOW = 4			-- Task window started, not flying
local STATE_READY = 5		 		-- Flight timer will be started when launch switch is released
local STATE_FLYING = 6			-- Flight timer started but flight not yet committed
local STATE_COMMITTED = 7 	-- Flight timer started, and flight committed
local STATE_FREEZE = 8			-- Still committed, but freeze	the flight timer
local state = STATE_IDLE		-- Current program state

-- Common variables
local activeScreen					-- Currently active screen
local launchSwitch					-- Launch switch, persistent data
local winSwitch							-- Switch for reporting remaining window time
local timeDial							-- For adjusting Poker calls, persistent data
local lang									-- Language translations
local labelInfo							-- Info label on screen
local labelTmr							-- Label before flight timer
local tasks									-- Table with task definitions
local labelTask							-- Task menu label
local taskWindow						-- Length of task window
local launches							-- Number of launches allowed, -1 for unlimited
local taskScores						-- Number of scores in task 
local finalScores						-- Task scores are final
local targetType						-- 1. Huge ladder, 2. Poker, 3. "1234", 4. Big ladder, Else: constant time
local scoreType							-- 1. Best, 2. Last, 3. Make time
local currentTask						-- Currently selected task on menu
local counts								-- Flight timer countdown
local winTimer							-- Window timer
local winDelay							-- Countdown for delayed window start
local flightTimer						-- Flight timer
local flightTime						-- Flight flown
local scores = { }					-- List of saved scores
local totalScore						-- Total score
local scoreLog = { }				-- List of previous scores
local prevLaunchSw					-- Used for detecting when Launch switch changes
local eow	= true						-- Automatically stop flight at end of window834
local qr = false						-- Quick relaunch

-- Variables used for time dial tasks like Poker
local pokerCalled						-- Lock in time
local lastInput = 0					-- For announcing changes in pokerCall
local lastChange = 0				-- Same
local timeDialSteps = { }		-- Steps for various time dial tasks

------------------------------------ Language -------------------------------------

lang =  {
	appName = "F3K score",
	infoTitle = "Soar F3K",
	infoText = {
		"Please add these INPUTs:",
		"Lau: Launch switch",
		"Win: Rem. win. time switch",
		"Pok: Poker time dial",
		"Implements its own timers",
		"(C) 2023 Jesper Frickmann"
	},
	qr = "QR",				-- Quick Relaunch
	eow = "EoW",			-- End of Window
	flight = "Flight:",
	target = "Target:",
	window = "Window:",
	total = "Total: %i sec.",
	done = "Done! %i sec.",
	nextCall = "Next call: %02i:%02i",
	launchLeft = "launch left",
	launchesLeft = "launches left",
	saveScores = "Save scores?",
	enterYes = "ENTER = SAVE",
	exitNo = "EXIT = DON'T",
	noScores = "No scores yet!",
	browse = "Browse saved scores",
	A = "A. Last flight",
	B1 = "B. Two last 3:00",
	B2 = "B. Two last 4:00",
	C = "C. All up last down",
	D = "D. Two flights only",
	E1 = "E. Poker 10 min.",
	E2 = "E. Poker 15 min.",
	F = "F. Three best of six",
	G = "G. Five best flights",
	H = "H. 1-2-3-4 any order",
	I = "I. Three best flights",
	J = "J. Three last flights",
	K = "K. Big Ladder",
	L = "L. One flight only",
	M = "M. Huge Ladder",
	N = "N. Best flight",
	Y = "Y. Quick Relaunch!",
	Z = "Z. Just Fly!"
}

------------------------------------ Task data -------------------------------------

local function defineTasks()
	-- { label, window, launches, scores, final, tgtType, scoreType }
	tasks = {
		{ lang.A, 420, -1, 1, false, 300, 2	},
		{ lang.B1, 420, -1, 2, false, 180, 2	},
		{ lang.B2, 600, -1, 2, false, 240, 2	},
		{ lang.C, 0, 7, 7, true, 180, 2	},
		{ lang.D, 600, 2, 2, true, 300, 2	},
		{ lang.E1, 600, -1, 3, true, 2, 3	},
		{ lang.E2, 900, -1, 3, true, 2, 3	},
		{ lang.F, 600, 6, 3, false, 180, 1	},
		{ lang.G, 600, -1, 5, false, 120, 1	},
		{ lang.H, 600, -1, 4, false, 3, 1	},
		{ lang.I, 600, -1, 3, false, 200, 1	},
		{ lang.J, 600, -1, 3, false, 180, 2	},
		{ lang.K, 600, 5, 5, true, 4, 2	},
		{ lang.L, 600, 1, 1, true, 599, 2	},
		{ lang.M, 900, 3, 3, true, 1, 2	},
		{ lang.N, 600, -1, 1, false, 599, 1	},
		{ lang.Y, 0, -1, 7, false, 2, 2	},
		{ lang.Z, 0, -1, 7, false, 0, 2	},
		{ lang.browse } -- Not a task - menu item for browsing scores
	}

	-- Time steps for dialing time targets in Poker etc.
	for i, task in ipairs(tasks) do
		if task[1] == lang.E1 then -- Poker 10 min.
			timeDialSteps[i]	= { {30,	5}, {60, 10}, {120, 15}, {210, 30}, {420, 60}, {660, 1} }
		elseif task[1] == lang.E2 then -- Poker 15 min.
			timeDialSteps[i]	= { {30, 10}, {90, 15}, {270, 30}, {480, 60}, {960, 1} }
		elseif task[1] == lang.Y then -- Quick Relaunch
			timeDialSteps[i] = { {15,	5}, {30, 10}, { 60, 15}, {120, 30}, {270, 1} }
		end
	end
end

-------------------------------- Utility functions ---------------------------------

local function void()
end

-- Inverse if true
local function invers(x)
	if x then return INVERS end
	return 0
end

-- Blink if true
local function blink(x)
	if x then return INVERS + BLINK end
	return 0
end

-- Find input matching a name
local function findInput(name)
	for input = 0, 31 do
		local tbl = model.getInput(input, 0)
		
		if tbl and tbl.inputName == name then
			return tbl.source
		end
	end
end

-- Find the required inputs
local function findInputs()
	launchSwitch = findInput("Lau")
	winSwitch = findInput("Win")
	timeDial = findInput("Pok")
end

-- Safely read switch as boolean
local function getSwitch(sw)
	 if not sw then return false end
	 local val = getValue(sw)
	 if not val then return false end
	 return (val > 512)
end

-- Return true if the first arg matches any of the following args
local function match(x, ...)
	for i, y in ipairs({...}) do
		if x == y then
			return true
		end
	end
	return false
end

--------------------------------- Timer functions ----------------------------------

-- Create a new timer
local function newTimer(interval)
	local timer = {
		start = 0,
		value = 0,
		prev = 0
	}
	
	local d, t0, nextIntCall

	function timer.set(s)
		timer.start = s
		timer.value = s
		timer.prev = s
	end

	function timer.update()
		if t0 then
			local ms = getTime() - t0
			timer.prev = timer.value
			timer.value = 0.1 * math.floor(0.1 * d * ms + 0.5)
			
			if interval and getSwitch(interval) and ms >= nextIntCall then
				local s = math.floor(timer.value + 0.5)
				if s > 15 then
					playDuration(s)
				else
					playNumber(s, 0)
				end
				nextIntCall = 1000 * math.floor(0.001 * ms + 1.5)
			end
		end
	end
	
	function timer.run()
		if t0 then return end
		
		if timer.start > 0 then
			d = -1
		else
			d = 1
		end
		
		t0 = getTime() - d * 100 * timer.value
		nextIntCall = -2E9
	end
	
	function timer.stop()
		if t0 then
			timer.update()
			t0 = nil
		end
	end
	
	return timer
end

-- Convert seconds to "mm:ss.s"
local function s2str(s)
	if not s then
		return " - - -"
	end
	
	local sign = ""
	if s < 0 then
		s = -s
		sign = "-"
	end

	local m = math.floor(s / 60)
	s = s - 60 * m
	
	return sign .. string.format("%02i:%04.1f", m, s)
end

------------------------------------ Business --------------------------------------

-- Keep the best scores
local function recordBest(scores, newScore)
	local n = #scores
	local i = 1
	local j = 0

	-- Find the position where the new score is going to be inserted
	if n == 0 then
		j = 1
	else
		-- Find the first position where existing score is smaller than the new score
		while i <= n and j == 0 do
			if newScore > scores[i] then j = i end
			i = i + 1
		end
		
		if j == 0 then j = i end -- New score is smallest; end of the list
	end

	-- If the list is not yet full; let it grow
	if n < taskScores then n = n + 1 end

	-- Insert the new score and move the following scores down the list
	for i = j, n do
		newScore, scores[i] = scores[i], newScore
	end
end	--	recordBest (...)

-- Used for calculating the total score and sometimes target time
local function maxScore(iFlight, targetType)
	if targetType == 1 then -- Huge ladder
		return 60 + 120 * iFlight
	elseif targetType == 2 then -- Poker
		return 9999
	elseif targetType == 3 then -- 1234
		return 300 - 60 * iFlight
	elseif targetType == 4 then -- Big ladder
		return 30 + 30 * iFlight
	else -- maxScore = targetType
		return targetType
	end
end

-- Calculate total score for task
local function calcTotalScore(scores, targetType)
	local total = 0	
	for i = 1, #scores do
		total = total + math.min(maxScore(i, targetType), scores[i])
	end
	return total
end

-- Record scores
local function score()
	if scoreType == 1 then -- Best scores
		recordBest(scores, flightTime)

	elseif scoreType == 2 then -- Last scores
		local n = #scores
		if n >= taskScores then
			-- List is full; move other scores one up to make room for the latest at the end
			for j = 1, n - 1 do
				scores[j] = scores[j + 1]
			end
		else
			-- List can grow; add to the end of the list
			n = n + 1
		end
		scores[n] = flightTime

	else -- Must make time to get score
		local score = flightTime
		-- Did we make time?
		if flightTimer.value > 0 then
			return
		else
			-- In Poker, only score the call
			if pokerCalled then
				score = flightTimer.start
				pokerCalled = false
			end
		end
		scores[#scores + 1] = score

	end
	totalScore = calcTotalScore(scores, targetType)
end -- score()

-- Find the best target time, given what has already been scored, as well as the remaining time of the window.
-- Note: maxTarget ensures that recursive calls to this function only test shorter target times. That way, we start with
-- the longest flight and work down the list. And we do not waste time testing the same target times in different orders.
local function best1234Target(timeLeft, scores, maxTarget)
	local bestTotal = 0
	local bestTarget = 0

	-- Max. minutes there is time left to fly
	local maxMinutes = math.min(maxTarget, 4, math.ceil(timeLeft / 60))

	-- Iterate from 1 to n minutes to find the best target time
	for i = 1, maxMinutes do
		local target
		local tl
		local tot
		local dummy

		-- Target in seconds
		target = 60 * i

		-- Copy scores to a new table
		local s = {}
		for j = 1, #scores do
			s[j] = scores[j]
		end

		-- Add new target time to s; only until the end of the window
		recordBest(s, math.min(timeLeft, target))
		tl = timeLeft - target

		-- Add up total score, assuming that the new target time was made
		if tl <= 0 or i == 1 then
			-- No more flights are made; sum it all up
			tot = 0
			for j = 1, math.min(4, #s) do
				tot = tot + math.min(300 - 60 * j, s[j])
			end
		else
			-- More flights can be made; add more flights recursively
			-- Subtract one second from tl for turnaround time
			dummy, tot = best1234Target(tl - 1, s, i - 1)
		end

		-- Do we have a new winner?
		if tot > bestTotal then
			bestTotal = tot
			bestTarget = target
		end
	end

	return bestTarget, bestTotal
end	--	best1234Target(..)

-- Get called time from user in Poker
local function pokerCall()
	if not timeDial then return 60 end
	local input = getValue(timeDial)
	if not input then return 60 end
	local tblStep = timeDialSteps[currentTask]

	local i, x = math.modf(1 + (#tblStep - 1) * (math.min(1023, input) + 1024) / 2048)
	local t1 = tblStep[i][1]
	local dt = tblStep[i][2]
	local t2 = tblStep[i + 1][1]	
	local result = t1 + dt * math.floor(x * (t2 - t1) / dt)
	
	if scoreType == 3 then
		result = math.min(winTimer.value - 1, result)
	end
	
	if math.abs(input - lastInput) >= 0.02 then
		lastInput = input
		lastChange = getTime()
	end
	
	if state == STATE_COMMITTED and lastChange > 0 and getTime() - lastChange > 100 then
		playTone(1760, 100, PLAY_NOW)
		playDuration(result)
		lastChange = 0
	end
	
	return result
end -- pokerCall()

local function targetTime()
	if targetType == 2 then -- Poker
		if pokerCalled then
			return flightTimer.start
		else
			return pokerCall()
		end
	elseif targetType == 3 then -- 1234
		return best1234Target(winTimer.value, scores, 4)
	else -- All other tasks
		return maxScore(#scores + 1, targetType)
	end
end -- targetTime()

-- Handle transitions between program states
local function gotoState(newState)
	state = newState
 
	if state < STATE_WINDOW or state == STATE_FREEZE then
		winTimer.stop()
		flightTimer.stop()
		labelTmr = lang.target

		if state == STATE_FINISHED then
			playTone(880, 1000, PLAY_NOW)
		end
	
	elseif state <= STATE_READY then
		winTimer.run()
		flightTimer.stop()
		labelTmr = lang.target
		
	elseif state == STATE_FLYING then
		flightTimer.run()
		labelTmr = lang.flight
		
		-- Get ready to count down
		local tgtTime = targetTime()
		
		-- A few extra counts in 1234
		if targetType == 3 then
			counts = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 15, 20, 30, 45, 65, 70, 75, 125, 130, 135, 185, 190, 195}
		else
			counts = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 15, 20, 30, 45}
		end

		while #counts > 1 and counts[#counts] >= tgtTime do
			counts[#counts] = nil
		end

		if flightTimer.start > 0 then
			playDuration(flightTimer.start)
		else
			playTone(1760, 100, PLAY_NOW)
		end
	
	elseif state == STATE_COMMITTED then
		if launches > 0 then
			launches = launches - 1
		end
		lastChange = 0
	end
 
	if activeSubForm == 3 then
		setTaskKeys()
	end

	-- Configure info text label
	if state == STATE_PAUSE then
		labelInfo = string.format(lang.total, totalScore)
	elseif state == STATE_FINISHED then
		labelInfo = string.format(lang.done, totalScore)
	else
		if launches >= 0 then
			local s
			if launches == 1 then
				s = lang.launchLeft
			else
				s = lang.launchesLeft
			end
			labelInfo = string.format("%i %s", launches, s)
		else
			labelInfo = ""
		end
	end
end -- gotoState()

-- Function for setting up a task
local function setupTask(taskData)
	labelTask = taskData[1]
	taskWindow = taskData[2]
	launches = taskData[3]
	taskScores = taskData[4]
	finalScores = taskData[5]
	targetType = taskData[6]
	scoreType = taskData[7]
	scores = { }
	totalScore = 0
	pokerCalled = false
	
	gotoState(STATE_IDLE)
end -- setupTask(...)

-- Main loop running all the time
local function background()
	local launchSw = getSwitch(launchSwitch)
	local launchPulled = (launchSw and not prevLaunchSw)
	local launchReleased = (not launchSw and prevLaunchSw)
	prevLaunchSw = launchSw
	
	flightTimer.update()
	winTimer.update()
	flightTime = math.abs(flightTimer.start - flightTimer.value)
	
	if state <= STATE_READY and state ~= STATE_FINISHED then
		flightTimer.set(targetTime())
	end
	
	if state < STATE_WINDOW then
		if state == STATE_IDLE then
			winTimer.set(taskWindow)

			-- Did we start the window delay timer?
			if winDelay then
				winDelay.update()
				if winDelay.value <= 0 then
					winDelay = nil
					playTone(880, 500, PLAY_NOW)
					if launchSw then
						gotoState(STATE_READY)
					else
						gotoState(STATE_WINDOW)
					end
				elseif math.ceil(winDelay.value) ~= math.ceil(winDelay.prev) then
					playNumber(winDelay.value, 0)
				end
			elseif launchPulled then
				-- Automatically start window and flight if launch switch is released
				gotoState(STATE_READY)
			end
		end

	else
		-- Did the window expire?
		if winTimer.prev > 0 and winTimer.value <= 0 then
			playTone(880, 1000, PLAY_NOW)

			if state < STATE_FLYING then
				gotoState(STATE_FINISHED)
			elseif eow then
				gotoState(STATE_FREEZE)
			end
		end

		if state == STATE_WINDOW then
			if launchPulled then
				gotoState(STATE_READY)
			elseif launchReleased then
				-- Play tone to warn that timer is NOT running
				playTone(1760, 200, PLAY_NOW)
			end
			
		elseif state == STATE_READY then
			if launchReleased then
				gotoState(STATE_FLYING)
			end

		elseif state >= STATE_FLYING then
			-- Time counts
			if flightTimer.value <= counts[#counts] and flightTimer.prev > counts[#counts]	then
				if flightTimer.value > 15.1 then
					playDuration(flightTimer.value)
				else
					playNumber(flightTimer.value, 0)
				end
				if #counts > 1 then 
					counts[#counts] = nil
				end
			elseif math.ceil(flightTimer.value / 60) ~= math.ceil(flightTimer.prev / 60) and flightTimer.prev > 0 then
				playDuration(flightTimer.value)
			end
			
			if state == STATE_FLYING then
				-- Within 10 sec. "grace period", cancel the flight
				if launchPulled then
					gotoState(STATE_WINDOW)
				end

				-- After 10 seconds, commit flight
				if flightTime >= 10 then
					gotoState(STATE_COMMITTED)
				end
				
			elseif launchPulled then
				-- Report the time after flight is done
				if flightTimer.start == 0 then
					playDuration(flightTime)
				end

				score()
				
				-- Change state
				if (finalScores and #scores == taskScores) or launches == 0 or (taskWindow > 0 and winTimer.value <= 0) then
					gotoState(STATE_FINISHED)
				elseif qr then
					gotoState(STATE_READY)
				else
					gotoState(STATE_WINDOW)
				end
			end
		end
	end

	-- Update info for user dial targets
	if state == STATE_COMMITTED and targetType == 2 and (scoreType ~= 3 or taskScores - #scores > 1) then
		local call = pokerCall()
		local min = math.floor(call / 60)
		local sec = call - 60 * min
		labelInfo = string.format(lang.nextCall, min, sec)
	end

	-- "Must make time" tasks
	if scoreType == 3 then
		if state == STATE_COMMITTED then
			pokerCalled = true
		elseif state < STATE_FLYING and state ~= STATE_FINISHED and winTimer.value < targetTime() then
			gotoState(STATE_FINISHED)
		end
	end
end -- background)

----------------------------------- Menu screen --------------------------------------

local firstMenuItem = 1
local taskScreen
local browseScreen

local function menuScreen(event)
	lcd.clear()
	lcd.drawScreenTitle(lang.appName, 0, 0)
	
	if event == EVT_VIRTUAL_ENTER then
		if currentTask == #tasks then
			activeScreen = browseScreen()
		else
			setupTask(tasks[currentTask])
			activeScreen = taskScreen
		end
	elseif match(event, EVT_VIRTUAL_PREV, EVT_VIRTUAL_PREV_REPT) then
		currentTask = (currentTask - 2) % #tasks + 1
	elseif match(event, EVT_VIRTUAL_NEXT, EVT_VIRTUAL_NEXT_REPT) then
		currentTask = currentTask % #tasks + 1
	end

	-- Scroll if necessary
	if currentTask < firstMenuItem then
		firstMenuItem = currentTask
	elseif currentTask - firstMenuItem > 5 then
		firstMenuItem = currentTask - 5
	end
		
	for line = 1, math.min(6, #tasks - firstMenuItem + 1) do
		local item = line + firstMenuItem - 1
		local y0 = 1 + 9 * line
		lcd.drawText(2, y0, tasks[item][1], invers(item == currentTask))
	end
end

------------------------------ Prompt to save scores ----------------------------------

local function saveScreen(event)
	lcd.clear()
	lcd.drawScreenTitle(labelTask, 0, 0)

	lcd.drawText(8, 15, lang.saveScores, MIDSIZE)
	lcd.drawText(8, 35, lang.enterYes)
	lcd.drawText(8, 45, lang.exitNo)

	if match(event, EVT_VIRTUAL_ENTER, EVT_VIRTUAL_EXIT) then
		if event == EVT_VIRTUAL_ENTER then
			-- Build new score record
			local record = {
				labelTask,
				model.getInfo().name,
			}
			
			local t = getDateTime()
			record[#record + 1] = string.format("%04i-%02i-%02i %02i:%02i", t.year, t.mon, t.day, t.hour, t.min)
			record[#record + 1] = totalScore
			
			for i, s in ipairs(scores) do
				record[#record + 1] = s
			end

			-- Insert record in scoreLog with max. entries
			scoreLog[#scoreLog + 1] = record
			while #scoreLog > SCORE_SIZE do
				for i = 1, #scoreLog do
					scoreLog[i] = scoreLog[i + 1]
				end
			end

			local file = io.open(SCORE_LOG, "w")
			
			for i, record in ipairs(scoreLog) do
				for j, field in ipairs(record) do
					io.write(file, tostring(field))
					if j == #record then
						io.write(file, "\n")
					else
						io.write(file, ",")
					end
				end
			end
			
			io.close(file)
		end

		activeScreen = menuScreen
		setupTask({ "", 0, -1, 7, false, 0, 2	})
		qr = false
	end
end

----------------------------------- Task screen ---------------------------------------

function taskScreen(event)
	lcd.clear()
	lcd.drawScreenTitle(labelTask, 0, 0)

	if event == EVT_VIRTUAL_MENU then
		qr = not qr
		playTone(1760, 100, PLAY_NOW)
	elseif event == EVT_VIRTUAL_MENU_LONG then
		eow = not eow
		playTone(1760, 100, PLAY_NOW)
		killEvents(EVT_VIRTUAL_MENU)
	elseif event == EVT_VIRTUAL_ENTER then
		if state == STATE_IDLE then
			if winDelay then
				winDelay = nil
			else
				winDelay = newTimer()
				winDelay.set(10.1)
				winDelay.run()
			end
		elseif state == STATE_PAUSE then
			gotoState(STATE_WINDOW)
			playTone(1760, 100, PLAY_NOW)
		elseif state == STATE_WINDOW then
			gotoState(STATE_PAUSE)
			playTone(1760, 100, PLAY_NOW)
		end
	elseif event == EVT_VIRTUAL_EXIT then
		if state == STATE_COMMITTED or state == STATE_FREEZE then
			-- Record a zero score!
			flightTime = 0
			score()
			
			if winTimer.value <= 0 or (finalScores and #scores == taskScores) or launches == 0 then
				gotoState(STATE_FINISHED)
			else
				gotoState(STATE_WINDOW)
			end

			playTone(440, 333, PLAY_NOW)
		elseif state == STATE_IDLE then
			-- Quit task
			activeScreen = menuScreen
			setupTask({ "", 0, -1, 7, false, 0, 2	})
			qr = false
		elseif state == STATE_PAUSE or state == STATE_FINISHED then
			activeScreen = saveScreen
		end
	end

	-- Draw scores
	local y = 9
	for i = 1, taskScores do
		lcd.drawNumber(8, y, i, RIGHT)
		lcd.drawText(9, y, ".")

		if i <= #scores then
			lcd.drawText(2, y, string.format("%i. %s", i, s2str(scores[i])))
		else
			lcd.drawText(2, y, string.format("%i. - - -", i))
		end

		y = y + 8
	end	
	
	if qr then
		lcd.drawText(51, 17, lang.qr, INVERS)
	end

	if eow then
		lcd.drawText(48, 34, lang.eow, INVERS)
	end

	if state >= STATE_FLYING then
		lcd.drawText(76, 9, lang.flight, SMLSIZE)
	else
		lcd.drawText(76, 9, lang.target, SMLSIZE)
	end
	
	lcd.drawText(LCD_W, 16, s2str(flightTimer.value), DBLSIZE + RIGHT + blink(flightTimer.value < 0))
	lcd.drawText(76, 33, lang.window, SMLSIZE)
	lcd.drawText(LCD_W, 40, s2str(winTimer.value), DBLSIZE + RIGHT + blink(state ~= STATE_FINISHED and winTimer.value < 0))
	lcd.drawText(48, 57, labelInfo)
end

----------------------------------- Info screen --------------------------------------

local function infoScreen(event)
	if launchSwitch and winSwitch and timeDial then
		activeScreen = menuScreen
		return
	end
	
	findInputs()
	
	lcd.clear()
	lcd.drawScreenTitle(lang.infoTitle, 0, 0)
	
	for i, txt in ipairs(lang.infoText) do
		lcd.drawText(1, 1 + 9 * i, txt, SMLSIZE)
	end
end

-------------------------------- Browse scores screen ---------------------------------

function browseScreen()
	local record
	local scores
	local taskScores
	local targetType
	local labelTask
	local browseRecord = #scoreLog

	-- Update form when record changes
	local function updateRecord()
		record = scoreLog[browseRecord]
		labelTask = record[1]
		
		-- Find task type, number of scores, and target type
		taskScores = 7
		targetType = 9999
		for i, task in ipairs(tasks) do
			if labelTask == task[1] then
				taskScores = task[4]
				targetType = task[6]
				break
			end
		end

		-- Copy scores from record
		scores = { }
		for i = 1, #record - 4 do
			scores[i] = tonumber(record[i + 4])
		end
	end

	if browseRecord > 0 then
		updateRecord()
	end

	return function(event)
		lcd.clear()

		if event == EVT_VIRTUAL_EXIT then
			activeScreen = menuScreen
		end

		if browseRecord == 0 then
			lcd.drawScreenTitle(lang.browse, 0, 0)
			lcd.drawText(12, 24, lang.noScores, MIDSIZE)
			return
		end

		lcd.drawScreenTitle(labelTask, browseRecord, #scoreLog)

		if match(event, EVT_VIRTUAL_NEXT, EVT_VIRTUAL_NEXT_REPT) then
			browseRecord = browseRecord % #scoreLog + 1
			updateRecord()
		elseif match(event, EVT_VIRTUAL_PREV, EVT_VIRTUAL_PREV_REPT) then
			browseRecord = (browseRecord - 2) % #scoreLog + 1
			updateRecord()
		end
	
		local x = 1
		local y = 10

		for i = 1, taskScores do
			lcd.drawText(x, y, string.format("%i. %s", i, s2str(scores[i])), SMLSIZE)
			x = x + 44
			if x > 100 then
				x = 1
				y = y + 10
			end
		end
			
		y = 40
		lcd.drawText(2, y, string.format(lang.total, tonumber(record[4])), SMLSIZE)	
		y = y + 9
		lcd.drawText(2, y, tostring(record[2]), SMLSIZE)
		y = y + 9
		lcd.drawText(2, y, tostring(record[3]), SMLSIZE)
	end
end

---------------------------------- Initialization ------------------------------------

-- Initialization
local function init()
	activeScreen = infoScreen
	defineTasks()
	findInputs()
	prevLaunchSw = getSwitch(launchSwitch)
	winTimer = newTimer(winSwitch)
	flightTimer = newTimer()
	currentTask = 1
	
	-- Start dummy task
	setupTask({ "", 0, -1, 8, false, 0, 2	})
	
	-- Read score file
	local file = io.open(SCORE_LOG, "r")
	
	if not file then
		return
	end
	
	local buffer = io.read(file, 9999)
	io.close(file)
	if buffer == nil then return end

	for line in string.gmatch(buffer, "[^\r\n]+") do
		local fields = { }
		for field in string.gmatch(line, "[^,]+") do
			fields[#fields + 1] = field
		end
		scoreLog[#scoreLog + 1] = fields
	end
end -- init()

-------------------------------------- Screen ---------------------------------------

local function run(event)
	activeScreen(event)
end

return {init = init, run = run, background = background}
