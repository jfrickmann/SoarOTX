-- JF F3K Timing and score keeping - simplified version
-- Timestamp: 2017-11-13
-- Created by Jesper Frickmann
-- Telemetry script for timing and keeping scores for the official F3K tasks.
-- This script is for use with my "simplified" F3K program, and for "third party" programs

local FM_LAUNCH = 1 -- Flight mode used for launch
local autoStart = true -- Start a window automatically when Launch trigger is pulled

local flightModeOld = getFlightMode() -- Used for detecting when FM changes
local	countIndex -- Index of timer count
local	targetTime -- Current flight target time
local winT0 = 0 -- Start point of window timer
local winStart = 0 -- Start seconds on window timer
local winTimer -- Current value of the window timer
local winTimerOld -- Previous value of the window timer
local flightT0 = 0 -- Start point of flight timer
local flightStart -- Start seconds on flight timer
local flightTimer -- Current value of flight timer (count down)
local	flightTimerOld -- Previous value of flight timer
local pokerMinId = getFieldInfo("s1").id -- Use dial 1 for setting minutes in Poker
local pokerSecId = getFieldInfo("s2").id -- Use dial 2 for setting seconds in Poker

-- Program states
local STATE_IDLE = 1 -- Task window not running
local STATE_PAUSE = 2 -- Task window paused, not flying
local STATE_FINISHED = 3 -- Task has been finished
local STATE_WINDOW = 4 -- Task window started, not flying
local STATE_READY = 5 -- Flight timer will be started when launch switch is released
local STATE_FLYING = 6 -- Flight timer started but flight not yet committed
local STATE_COMMITTED = 7 -- Flight timer started, and flight committed
local state = STATE_IDLE -- Current program state

-- Task index constants
local TASK_LASTFL = 1
local TASK_2LAST4 = 3
local TASK_AULD = 4
local TASK_LADDER = 5
local TASK_POKER = 6
local TASK_5X2 = 8
local TASK_1234 = 9
local TASK_3BEST = 10
local TASK_BIGLAD = 12
local TASK_TURN = 13
local TASK_JUSTFL = 14
local task = TASK_JUSTFL -- Selected task index

local eowTimerStop = true -- Freeze timer automatically at the end of the window
local quickRelaunch = false -- Restart timer immediately
local counts -- Flight timer countdown

local taskScores -- Number of scores to record
local finalScores -- Does task end when all scores are made?
local taskLaunches -- Number of launches allowed
local taskScoreTypes -- 1=last 2=best 3=must make time
local taskWindow -- Window times

local scores -- Scores recorded
local launches -- Number of launches
local launchesLeft -- Number of launches left in task window
local pokerCalled -- Freeze target time until it has been completed

local 	taskList -- List of task descriptions for title
local menuReply -- Holds reply from popup menu
local DrawMenu -- DrawMenu() function is defined for specific transmitter
local Draw -- Draw() function is defined for specific transmitter

-- Score browser variables
local browsing -- Activate score browser
local sbLogFile -- Log file handle
local sbScores -- Scores recorded
local sbTaskScores -- Number of scores for task
local sbTaskName -- Name of current task
local sbPlaneName -- Name of plane
local sbDateStr -- Date saved
local sbTimeStr -- Time saved
local sbTotalSecs -- Total seconds for the round
local sbIndices -- Vector of indices pointing to start of lines in the log file
local sbIndex -- Index to currently selected line in log file
local sbMaxScores = {} -- Maximum times that can be scored in various tasks
local sbTaskList -- List of task descriptions for title - shared with score browser script
local DrawBrowser -- DrawBrowser() function is defined for specific transmitter
local LOG_FILE = "/LOGS/JF F3K Scores.csv"

-- Transmitter specific
local TX_UNKNOWN = 0
local TX_X9D = 1 
local TX_QX7 = 2
local TX_LITE = 3
local tx
local GRAY
local ver, radio = getVersion()

if string.find(radio, "x7") then -- Qx7
	tx = TX_QX7
	GRAY = 0
elseif string.find(radio, "x9d") then -- X9D		
	tx = TX_X9D
	GRAY = GREY_DEFAULT
elseif string.find(radio, "lite") then -- X-lite
	tx = TX_LITE
	GRAY = 0
else
	tx = TX_UNKNOWN
end

ver = nil
radio = nil

local function PokerTime()
	local m = math.floor((1024 + getValue(pokerMinId)) / 205)
	local s = math.floor((1024 + getValue(pokerSecId)) / 34.2)
	if task == TASK_POKER then
		return math.max(5, math.min(winTimer - 1, 60 * m + s))
	else
		return math.max(5, 60 * m + s)
	end
end -- PokerTime()

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
	taskLaunches = {99, 99, 99, 8, 99, 99, 6, 99, 99, 99, 99, 5, 99, 99}
	taskScores = {1, 2, 2, 8, 7, 5, 3, 5, 4, 3, 3, 5, 8, 8}

	-- Draw the basic menu with border and title
	function DrawMenu(title)
		local now = getDateTime()
		local infoStr = string.format("%02d:%02d", now.hour, now.min)

		lcd.clear()
		lcd.drawRectangle(2, 10, LCD_W - 4, LCD_H - 12)
		lcd.drawText(LCD_W, 0, infoStr, RIGHT)
		lcd.drawScreenTitle(title, 0, 0)
	end -- DrawMenu()

	function Draw()
		local x = 16
		local y = 17
		local split
		local n = taskScores[task]
		local blnk = getTime() % 100 < 50

		DrawMenu(" " .. taskList[task] .. " ")

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

			if i <= #scores then
				lcd.drawTimer(x + 6, y, scores[i])
			else
				lcd.drawText(x + 6, y, "- - -")
			end

			y = y + 10
		end
		
		lcd.drawText(58, 57, " JF F3K Score Keeper ", SMLSIZE)

		if quickRelaunch then
			lcd.drawText(100, 19, "QR", SMLSIZE + INVERS)
		end

		if eowTimerStop then
			lcd.drawText(97, 35, "EoW", SMLSIZE + INVERS)
		end

		lcd.drawTimer(172, 16, flightTimer, MIDSIZE)
		if state >= STATE_FLYING then
			lcd.drawText(125, 19, "Flight")
		else
			lcd.drawText(125, 19, "Target")
			if pokerCalled and blnk then
				lcd.drawFilledRectangle(124, 16, 80, 12)
			end
		end

		lcd.drawText(125, 35, "Window")
		lcd.drawTimer(172, 32, winTimer, MIDSIZE)

		if state >= STATE_WINDOW then
			if flightTimer < 0 and blnk then
				lcd.drawFilledRectangle(124, 16, 80, 12)
			end

			if winTimer < 0 and blnk then
				lcd.drawFilledRectangle(124, 32, 80, 12)
			end

			if launchesLeft <= 8 then
				lcd.drawNumber(130, 48, launchesLeft, SMLSIZE+RIGHT)
				if launchesLeft == 1 then
					lcd.drawText(130, 48, " launch left", SMLSIZE)
				else
					lcd.drawText(130, 48, " launches left", SMLSIZE)
				end
			end

			if state >= STATE_COMMITTED and pokerCalled then
				lcd.drawText(125, 48, "Next call", SMLSIZE)
				lcd.drawTimer(172, 48, PokerTime(), SMLSIZE)
			end

		else

			if state == STATE_FINISHED then
				lcd.drawText(125, 48, "GAME OVER!", SMLSIZE + BLINK)
			end
		end
	end  --  Draw()
	
	function DrawBrowser(scores, n)
		local x = 16
		local y = 17
		local split

		DrawMenu(" " .. sbTaskName .. " ")

		lcd.drawText(120, 17, sbPlaneName, MIDSIZE)
		lcd.drawText(120, 35, sbDateStr)
		lcd.drawText(175, 35, sbTimeStr)
		lcd.drawText(120, 47, "Total " .. sbTotalSecs .. " sec.")
		lcd.drawText(55, 58, " JF F3K Score Browser ", SMLSIZE)	

		-- Warn if the log file is growing too large
		if #sbIndices > 200 then
			lcd.drawText(55, 57, " Log getting too large ", SMLSIZE + BLINK + INVERS)
		end
		
		
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

			if i <= #scores then
				lcd.drawTimer(x + 6, y, scores[i])
			else
				lcd.drawText(x + 6, y, "- - -", SMLSIZE)
			end

			y = y + 10
		end
	end -- DrawBrowser()
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
	taskLaunches = {99, 99, 99, 7, 99, 99, 6, 99, 99, 99, 99, 5, 99, 99}
	taskScores = {1, 2, 2, 7, 7, 5, 3, 5, 4, 3, 3, 5, 7, 7}

	function DrawMenu(title)
		local now = getDateTime()
		local infoStr = string.format("%02d:%02d", now.hour, now.min)

		lcd.clear()
		lcd.drawRectangle(2, 10, LCD_W - 4, LCD_H - 12)
		lcd.drawScreenTitle(title, 0, 0)
		lcd.drawText(LCD_W, 0, infoStr, RIGHT)
	end -- DrawMenu()

	function Draw()
		local y = 12
		local n = taskScores[task]
		local blnk = getTime() % 100 < 50

		DrawMenu(taskList[task])
		
		-- Draw scores
		for i = 1, n do
			lcd.drawNumber(10, y, i, RIGHT + SMLSIZE)
			lcd.drawText(10 + 1, y, ". ", SMLSIZE)

			if i <= #scores then
				lcd.drawTimer(10 + 6, y, scores[i], SMLSIZE)
			else
				lcd.drawText(10 + 6, y, "- - -", SMLSIZE)
			end

			y = y + 7
		end	
		
		lcd.drawText(47, 58, " JF F3K ", SMLSIZE)
		lcd.drawTimer(92, 12, flightTimer, MIDSIZE)
		lcd.drawText(70, 33, "Win:")
		lcd.drawTimer(92, 30, winTimer, MIDSIZE)

		if quickRelaunch then
			lcd.drawText(53, 15, "QR", SMLSIZE + INVERS)
		end

		if eowTimerStop then
			lcd.drawText(50, 33, "EoW", SMLSIZE + INVERS)
		end

		if state >= STATE_FLYING then
			lcd.drawText(70, 15, "Flt:")
		else
			lcd.drawText(70, 15, "Tgt:")
			if pokerCalled and blnk then
				lcd.drawFilledRectangle(69, 10, 55, 14)
			end
		end

		if state >= STATE_WINDOW then
			if flightTimer < 0 and blnk then
				lcd.drawFilledRectangle(69, 10, 55, 12)
			end

			if winTimer < 0 and blnk then
				lcd.drawFilledRectangle(69, 30, 55, 12)
			end

			if launchesLeft <= 8 then
				lcd.drawNumber(50, 48, launchesLeft, SMLSIZE)
				if launchesLeft == 1 then
					lcd.drawText(55, 48, " launch left", SMLSIZE)
				else
					lcd.drawText(55, 48, " launches left", SMLSIZE)
				end
			end

			if state >= STATE_COMMITTED and pokerCalled then
				lcd.drawText(50, 48, "Next call", SMLSIZE)
				lcd.drawTimer(92, 48, PokerTime(), SMLSIZE)
			end

		else
			
			if state == STATE_FINISHED then
				lcd.drawText(50, 48, "GAME OVER!", SMLSIZE + BLINK)
			end
		end
	end -- Draw()
	
	function DrawBrowser(scores, n)
		local y = 12
		
		DrawMenu(sbTaskName)

		lcd.drawText(50, 12, sbPlaneName, MIDSIZE)
		lcd.drawText(50, 28, sbDateStr, SMLSIZE)
		lcd.drawText(50, 38, sbTimeStr, SMLSIZE)
		lcd.drawText(50, 48, "Total " .. sbTotalSecs .. " sec.", SMLSIZE)
		lcd.drawText(47, 58, " JF F3K ", SMLSIZE)	

		-- Warn if the log file is growing too large
		if #sbIndices > 200 then
			lcd.drawText(12, 57, " Log getting too large ", SMLSIZE + BLINK + INVERS)
		end
		
		for i = 1, n do
			lcd.drawNumber(10, y, i, RIGHT + SMLSIZE)
			lcd.drawText(10 + 1, y, ". ", SMLSIZE)

			if i <= #scores then
				lcd.drawTimer(10 + 6, y, scores[i], SMLSIZE)
			else
				lcd.drawText(10 + 6, y, "- - -", SMLSIZE)
			end

			y = y + 7
		end	
	end -- DrawBrowser()
end

-- Add new score to existing scores, keeping only the last scores
local function RecordLast(scores, newScore)
	local n = #scores
	if n >= taskScores[task] then
		-- List is full; move other scores one up to make room for the latest at the end
		for j = 1, n - 1 do
			scores[j] = scores[j + 1]
		end
	else
		-- List can grow; add to the end of the list
		n = n + 1
	end
	scores[n] = newScore, targetTime
end  --  RecordLast(..)

-- Add new score to existing scores, keeping only the best scores
local function RecordBest(scores, newScore)
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
	if n < taskScores[task] then n = n + 1 end

	-- Insert the new score and move the following scores down the list
	for i = j, n do
		newScore, scores[i] = scores[i], newScore
	end
end  --  RecordBest (..)

-- Find the best target time, given what has already been scored, as well as the
-- remaining time of the window.
-- Note: maxTarget ensures that recursive calls to this function only test shorter
-- target times. That way, we start with the longest flight and work down the list.
-- And we do not waste time testing the same target times in different orders.
local function Best1234Target(timeLeft, scores, maxTarget)
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
		RecordBest(s, math.min(timeLeft, target))
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
			dummy, tot = Best1234Target(tl - 1, s, i - 1)
		end

		-- Do we have a new winner?
		if tot > bestTotal then
			bestTotal = tot
			bestTarget = target
		end
	end

	return bestTarget, bestTotal
end  --  Best1234Target(..)

local function SetFlightTimer()
	if task == TASK_LASTFL then
		targetTime = 300
	elseif task == TASK_2LAST4 then
		targetTime = 240
	elseif task == TASK_LADDER then
		targetTime = 30 + 15 * #scores
	elseif task == TASK_POKER then
		if not pokerCalled then
			targetTime = PokerTime()
		end
	elseif task == TASK_5X2 then
		targetTime = 120
	elseif task == TASK_1234 then
		targetTime = Best1234Target(winTimer, scores, 4)
	elseif task == TASK_3BEST then
		targetTime = 200
	elseif task == TASK_BIGLAD then
		targetTime = 60 + 30 * #scores
	elseif task == TASK_TURN then
		targetTime = PokerTime()
	elseif task == TASK_JUSTFL then
		targetTime = 0
	else
		targetTime = 180
	end

	-- Get ready to count down
	countIndex = #counts
	while countIndex > 1 and counts[countIndex] >= targetTime do
		countIndex = countIndex - 1
	end
	
	flightTimer = targetTime
	flightTimerOld = flightTimer
	flightStart = flightTimer
end  --  SetFlightTimer()

local function InitializeWindow()
	launches = 0
	scores = {}
	flying = false
	comitted = false
	pokerCalled = false
	
	if task == TASK_TURN then
		quickRelaunch = true
	else
		quickRelaunch = false
	end
	
	-- Give a few extra counts in 1-2-3-4
	if task == TASK_1234 then
		counts = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 15, 20, 30, 45, 60, 65, 70, 75, 120,
			125, 130, 135, 180, 185, 190, 195, 240}
	else
		counts = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 15, 20, 30, 45, 60, 120, 180, 240}
	end

	-- Set window timer
	if task == TASK_AULD or task == TASK_TURN or task == TASK_JUSTFL then
		winTimer = taskWindow[task]
	else
		winTimer = taskWindow[task]
	end
	winTimerOld = winTimer
	winStart = winTimer
	SetFlightTimer()
	state = STATE_IDLE
end  --  InitializeWindow()

-- Read a line of a log file
local function ReadLine(logFile, pos, bts)
	if not bts then bts = 100 end
	if logFile and pos then
		io.seek(logFile, pos)
		local str = io.read(logFile, bts)
		local endPos = string.find(str, "\n")

		if endPos then
			pos = pos + endPos
			str = string.sub(str, 1, endPos - 1)
			return pos, str
		end
	end
	
	-- No "\n" was found; return nothing
	return 0, ""
end  --  ReadLine()

-- Read a line a split comma separated fields
local function ReadLineData(charPos)
	local lineStr
	local i = 0
	local task
	
	sbTaskScores = 0
	sbScores = {}
	sbTotalSecs = 0

	charPos, lineStr = ReadLine(sbLogFile, charPos)
	
	for field in string.gmatch(lineStr, "[^,]+") do
		local nbr = tonumber(field)
		i = i + 1
		
		if i == 1 then
			sbPlaneName = field
		elseif i == 2 then
			sbTaskName = field
			
			-- Find the right task and max. score times
			for j = 1, #sbTaskList do
				if string.find(field, sbTaskList[j]) then
					task = j
					sbTaskScores = #sbMaxScores[task]
				end
			end
			
			-- Default to Just Fly!
			if not task then
				task = TASK_JUSTFL
				sbTaskScores = #sbMaxScores[task]
			end
		elseif i == 3 then
			sbDateStr = field
		elseif i == 4 then
			sbTimeStr = field
		elseif nbr then
			sbScores[i - 4] = nbr
			if i - 4 <= #sbMaxScores[task] then
				sbTotalSecs = sbTotalSecs + math.min(field, sbMaxScores[task][i - 4])
			end
		end
	end
end  --  ReadLineData()

local function Scan()
	local i = #sbIndices
	local charPos = sbIndices[#sbIndices]
	local done = false

	sbLogFile = io.open(LOG_FILE, "r")

	-- Read lines of the log file and store indices
	repeat
		charPos = ReadLine(sbLogFile, charPos)
		if charPos == 0 then
			done = true
		else
			sbIndices[#sbIndices + 1] = charPos
		end
	until done

	-- If new data then read last full line of the log file as current record
	if #sbIndices > i then
		sbIndex = #sbIndices - 1
		ReadLineData(sbIndices[sbIndex])
	end
	
	if sbLogFile then io.close(sbLogFile) end
end -- Scan()

local function InitializeBrowser()
	-- Patterns for matching task names
	sbTaskList = {
		"A%.",
		"B%..+3",
		"B%..+4",
		"C%.",
		"D%.",
		"E%.",
		"F%.",
		"G%.",
		"H%.",
		"I%.",
		"J%.",
		"K%."
	}

	sbMaxScores[1] = {300}
	sbMaxScores[2] = {180, 180}
	sbMaxScores[3] = {240, 240}
	sbMaxScores[5] = {30, 45, 60, 75, 90, 105, 120}
	sbMaxScores[6] = {599, 599, 599, 599, 599}
	sbMaxScores[7] = {180, 180, 180}
	sbMaxScores[8] = {120, 120, 120, 120, 120}
	sbMaxScores[9] = {240, 180, 120, 60}
	sbMaxScores[10] = {200, 200, 200}
	sbMaxScores[11] = {180, 180, 180}
	sbMaxScores[12] = {60, 90, 120, 150, 180}
	
	if tx == TX_X9D then
		sbMaxScores[4] = {180, 180, 180, 180, 180, 180, 180, 180}
		sbMaxScores[TASK_TURN] = {9999, 9999, 9999, 9999, 9999, 9999, 9999, 9999}
		sbMaxScores[TASK_JUSTFL] = {9999, 9999, 9999, 9999, 9999, 9999, 9999, 9999}
	else -- TX_QX7 or X-lite
		sbMaxScores[4] = {180, 180, 180, 180, 180, 180, 180}
		sbMaxScores[TASK_TURN] = {9999, 9999, 9999, 9999, 9999, 9999, 9999}
		sbMaxScores[TASK_JUSTFL] = {9999, 9999, 9999, 9999, 9999, 9999, 9999}
	end

	sbIndices = {0}
	sbIndex = 1
	ReadLineData(sbIndices[sbIndex])
	Scan()
end  --  InitializeBrowser()

local function init()
	saveTask = 0
	menuReply = 0

	finalScores = {false, false, false, true, true, true, false, false, false, false, false, true, false, false}
	taskScoreTypes = {1, 1, 1, 1, 3, 3, 2, 2, 2, 2, 1, 1, 1, 1}
	taskWindow = {420, 420, 600, 0, 600, 600, 600, 600, 600, 600, 600, 600, 0, 0}
	
	InitializeWindow()
end  --  init()
	
local function background()	
	local flightMode = getFlightMode()
	local launchPulled, launchReleased
	local now = getTime()
	
	if flightMode == FM_LAUNCH and flightModeOld ~= FM_LAUNCH then
		launchPulled = true
	elseif flightMode ~= FM_LAUNCH and flightModeOld == FM_LAUNCH then
		launchReleased = true
	end
	
	launchesLeft = taskLaunches[task] - launches

	-- Update internal timers
	if state >= STATE_WINDOW then
		-- To emulate radio timer, count down for postive start value and count of for zero start value
		if winStart > 0 then
			winTimer = winStart - math.floor((now - winT0) / 100)
		else
			winTimer = math.floor((now - winT0) / 100)
		end
	end
	
	if state >= STATE_FLYING and (winTimer >= 0 or not eowTimerStop) then
		-- To emulate radio timer, count down for postive start value and count of for zero start value
		if flightStart > 0 then
			flightTimer = flightStart - math.floor((now - flightT0) / 100)
		else
			flightTimer = math.floor((now - flightT0) / 100)
		end
	end
	
	-- Override radio timers, only if this program is active
	if state > STATE_IDLE then		
		model.setTimer(0, { value = flightTimer })
		model.setTimer(1, { value = winTimer })
	end
	
	if state < STATE_WINDOW then
		-- In Poker and Quick Relaunch, update flight timer with values set by knobs
		if task == TASK_POKER or task == TASK_TURN then 
			SetFlightTimer()
		end

		-- Automatically start window and flight if launch switch is released
		if autoStart and launchPulled and state == STATE_IDLE then
			winT0 = now
			SetFlightTimer()
			state = STATE_READY
		end

	else
		local flightTime = math.abs(flightStart - flightTimer)

		-- Beep at beginning and end of the task window
		if taskWindow[task] > 0 and ((winTimerOld >= taskWindow[task] + 1 and 
				winTimer < taskWindow[task] + 1) or
				(winTimerOld >= 0 and winTimer < 0)) then
			playTone(880, 1000, PLAY_NOW)
		end

		if state == STATE_WINDOW then
			SetFlightTimer()

			-- If all launches or scores have been made or window has expired; stop window
			if launchesLeft <= 0 or (finalScores[task] and #scores >= taskScores[task]) or winTimer < 0 then
				playTone(1760, 100, PLAY_NOW)
				state = STATE_FINISHED
			end

			if launchPulled then
				state = STATE_READY
			elseif launchReleased then
				-- Play tone to warn that timer is NOT running
				playTone(1760, 333, 0, PLAY_NOW)
			end
			
		elseif state == STATE_READY then
			SetFlightTimer()

			if launchReleased then
				state = STATE_FLYING
				flightT0 = now

				-- Report the target time
				if targetTime > 0 then
					playDuration(targetTime, 0)
				end
			end

		elseif state == STATE_FLYING then
			if launchPulled then
				state = STATE_WINDOW
			end

			-- After 5 seconds, commit flight
			if flightTime > 5 then
				launches = launches + 1
				
				-- Call Poker
				if task == TASK_POKER then 
					pokerCalled = true
				end
				
				state = STATE_COMMITTED
			end
			
		elseif state == STATE_COMMITTED then
			-- Is it time to count down?
			if flightTimer <= counts[countIndex] and flightTimerOld > counts[countIndex]  then
				if flightTimer > 15 then
					playDuration(flightTimer, 0)
				else
					playNumber(flightTimer, 0)
				end
				if countIndex > 1 then countIndex = countIndex - 1 end
			end

			if launchPulled then
				-- Record scores
				if taskScoreTypes[task] == 1 then
					RecordLast(scores, flightTime)
					
					-- In task Just Fly!, report the time after flight is done
					if task == TASK_JUSTFL then
						playDuration(flightTime, 0)
					end
				
				elseif taskScoreTypes[task] == 2 then
					RecordBest(scores, flightTime)
				else
					-- Only record if target time was made
					if flightTime >= targetTime then
						if task == TASK_POKER then
							RecordLast(scores, flightStart) -- only target time!
							pokerCalled = false
						else
							RecordLast(scores, flightTime)
						end
					end
				end
				
				-- Change state
				if launches == taskLaunches[task] or winTimer < 0 or
				   (finalScores[task] and #scores == taskScores[task]) then
					state = STATE_FINISHED
				elseif quickRelaunch then
					state = STATE_READY
				else
					state = STATE_WINDOW
				end
			end
		end
		
		winTimerOld = winTimer
		flightTimerOld = flightTimer
	end

	flightModeOld = flightMode
end  --  background()

local function run(event)
	local now = getTime()

	if saveTask ~= 0 then -- Save scores popup menu active
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
				for i = 1, #scores do
					io.write(logFile, string.format(",%d", scores[i]))
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

	elseif browsing then  --  Score browser active
		if event == EVT_MINUS_BREAK or event == EVT_ROT_LEFT or event == EVT_LEFT_BREAK then
			-- Go to previous record
			sbIndex = sbIndex - 1
			if sbIndex <= 0 then
				sbIndex = #sbIndices - 1
				playTone(3000, 100, 0, PLAY_NOW)
			end

			sbLogFile = io.open(LOG_FILE, "r")
			ReadLineData(sbIndices[sbIndex])
			if sbLogFile then io.close(sbLogFile) end
			killEvents(event)

		elseif event == EVT_PLUS_BREAK or event == EVT_ROT_RIGHT or event == EVT_RIGHT_BREAK then
			-- Go to next record
			sbIndex = sbIndex + 1
			if sbIndex >= #sbIndices then
				sbIndex = 1
				playTone(3000, 100, 0, PLAY_NOW)
			end

			sbLogFile = io.open(LOG_FILE, "r")
			ReadLineData(sbIndices[sbIndex])
			if sbLogFile then io.close(sbLogFile) end
			killEvents(event)
		elseif event == EVT_MENU_BREAK then
			-- Deactivate browser and clean up memory
			browsing = false
			sbLogFile = nil
			sbScores = nil
			sbTaskScores = nil
			sbTaskName = nil
			sbPlaneName = nil
			sbDateStr = nil
			sbTimeStr = nil
			sbTotalSecs = nil
			sbIndices = nil
			sbIndex = nil
			sbMaxScores = {}
			sbTaskList = nil
			return collectgarbage()
		end

		-- Time to draw the screen
		if sbTaskScores < 1 then
			DrawMenu(" No scores recorded ")
		else
			DrawBrowser(sbScores, sbTaskScores)
		end
	
	else  --  Timing and score keeping
		Draw()

		if state <= STATE_PAUSE then
			if event == EVT_ENTER_BREAK then
				-- Add 10 sec. to window timer, if a new task is started
				if state == STATE_IDLE and winTimer > 0 then
					winTimer = winTimer + 10
					winStart = winTimer
				end

				-- Start task window
				state = STATE_WINDOW
				playTone(1760, 100, PLAY_NOW)
				winT0 = now - 100 * math.abs(winStart - winTimer)
			elseif event == EVT_MENU_BREAK then
				browsing = true
				InitializeBrowser()
			end
		elseif state == STATE_WINDOW then
			if event == EVT_ENTER_BREAK then
				-- Pause task window
				state = STATE_PAUSE
				playTone(1760, 100, PLAY_NOW)
			end
		elseif state == STATE_COMMITTED then
			if event == EVT_MENU_LONG or event == EVT_SHIFT_LONG then
				-- Record a zero score!
				if taskScoreTypes[task] == 1 then
					RecordLast(scores, 0)
				elseif taskScoreTypes[task] == 2 then
					RecordBest(scores, 0)
				end
				
				-- Change state
				if launches == taskLaunches[task] or winTimer < 0 or
				   (finalScores[task] and #scores == taskScores[task]) then
					state = STATE_FINISHED
				else
					state = STATE_WINDOW
				end

				playTone(440, 333, PLAY_NOW)
			end
		end
			
		if state <= STATE_FINISHED then
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
				if state > STATE_IDLE then
					saveTask = task
				end
				
				task = task + change
				
				if task > #taskList then 
					task = 1 
				elseif task < 1 then 
					task = #taskList
				end
				
				-- Do not show popup menu to save scores
				if state == STATE_IDLE then
					InitializeWindow()
				end
			end

		else
			-- Toggle quick relaunch QR
			if event == EVT_PLUS_BREAK or event == EVT_ROT_RIGHT or event == EVT_UP_BREAK then
				quickRelaunch = not quickRelaunch
				playTone(1760, 100, PLAY_NOW)
			end
			
			-- Toggle end of window timer stop EoW
			if event == EVT_MINUS_BREAK or event == EVT_ROT_LEFT or event == EVT_DOWN_BREAK then
				eowTimerStop = not eowTimerStop
				playTone(1760, 100, PLAY_NOW)
			end
		end
	end
end  --  run()

return {init = init, background = background, run = run}
