-- JF F3K Score Browser
-- Timestamp: 2018-06-01
-- Created by Jesper Frickmann
-- Telemetry script for browsing scores recorded in the log file.

local logFile -- Log file handle
local scores -- Scores recorded
local taskScores -- Number of scores for task
local taskName -- Name of current task
local planeName -- Name of plane
local dateStr -- Date saved
local timeStr -- Time saved
local totalSecs -- Total seconds for the round
local lastTime -- Last time that run() was called, used for refreshing
local indices -- Vector of indices pointing to start of lines in the log file
local index -- Index to currently selected line in log file
local maxScores = {} -- Maximum times that can be scored in various tasks
local taskList -- List of task descriptions for title - shared with score browser script
local TASK_JUSTFLY = 13 -- Index of the Just Fly! task
local LOG_FILE = "/LOGS/JF F3K Scores.csv"

local Draw -- Draw() function is defined for specific transmitter

-- Transmitter specific
if tx == TX_X9D then
	maxScores[4] = {180, 180, 180, 180, 180, 180, 180, 180}
	maxScores[TASK_JUSTFLY] = {9999, 9999, 9999, 9999, 9999, 9999, 9999, 9999}
	
	function Draw(scores, n)
		local x = 16
		local y = 17
		local split

		DrawMenu(" " .. taskName .. " ")

		lcd.drawText(120, 17, planeName, MIDSIZE)
		lcd.drawText(120, 35, dateStr)
		lcd.drawText(175, 35, timeStr)
		lcd.drawText(120, 47, "Total " .. totalSecs .. " sec.")
		lcd.drawText(55, 58, " JF F3K Score Browser ", SMLSIZE)	

		-- Warn if the log file is growing too large
		if #indices > 200 then
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
	end -- Draw()
else -- QX7 or X-lite
	maxScores[4] = {180, 180, 180, 180, 180, 180, 180}
	maxScores[TASK_JUSTFLY] = {9999, 9999, 9999, 9999, 9999, 9999, 9999}
	
	function Draw(scores, n)
		local y = 12
		
		DrawMenu(taskName)

		lcd.drawText(50, 12, planeName, MIDSIZE)
		lcd.drawText(50, 28, dateStr, SMLSIZE)
		lcd.drawText(50, 38, timeStr, SMLSIZE)
		lcd.drawText(50, 48, "Total " .. totalSecs .. " sec.", SMLSIZE)
		lcd.drawText(47, 58, " JF F3K ", SMLSIZE)	

		-- Warn if the log file is growing too large
		if #indices > 200 then
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
	end -- Draw()
end
	
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
	taskScores = 0
	
	scores = {}
	totalSecs = 0

	charPos, lineStr = ReadLine(logFile, charPos)
	
	for field in string.gmatch(lineStr, "[^,]+") do
		local nbr = tonumber(field)
		i = i + 1
		
		if i == 1 then
			planeName = field
		elseif i == 2 then
			taskName = field
			
			-- Find the right task and max. score times
			for j = 1, #taskList do
				if string.find(field, taskList[j]) then
					task = j
					taskScores = #maxScores[task]
				end
			end
			
			-- Default to Just Fly!
			if not task then
				task = TASK_JUSTFLY
				taskScores = #maxScores[task]
			end
		elseif i == 3 then
			dateStr = field
		elseif i == 4 then
			timeStr = field
		elseif nbr then
			scores[i - 4] = nbr
			if i - 4 <= #maxScores[task] then
				totalSecs = totalSecs + math.min(field, maxScores[task][i - 4])
			end
		end
	end
end  --  ReadLineData()

local function Scan()
	local i = #indices
	local charPos = indices[#indices]
	local done = false

	logFile = io.open(LOG_FILE, "r")

	-- Read lines of the log file and store indices
	repeat
		charPos = ReadLine(logFile, charPos)
		if charPos == 0 then
			done = true
		else
			indices[#indices + 1] = charPos
		end
	until done

	-- If new data then read last full line of the log file as current record
	if #indices > i then
		index = #indices - 1
		ReadLineData(indices[index])
	end
	
	if logFile then io.close(logFile) end
end -- Scan()

local function init()
	lastTime = 0
	
	-- Patterns for matching task names
	taskList = {
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

	maxScores[1] = {300}
	maxScores[2] = {180, 180}
	maxScores[3] = {240, 240}
	maxScores[5] = {30, 45, 60, 75, 90, 105, 120}
	maxScores[6] = {599, 599, 599, 599, 599}
	maxScores[7] = {180, 180, 180}
	maxScores[8] = {120, 120, 120, 120, 120}
	maxScores[9] = {240, 180, 120, 60}
	maxScores[10] = {200, 200, 200}
	maxScores[11] = {180, 180, 180}
	maxScores[12] = {60, 90, 120, 150, 180}
	
	indices = {0}
	index = 1
	ReadLineData(indices[index])
	Scan()
end  --  init()

local function run(event)
	-- Look for new data if inactive for over 1 second
	local thisTime = getTime()
	if thisTime - lastTime > 100 then
		Scan()
	end

	lastTime = thisTime
	
	-- Go to previous record
	if event == EVT_MINUS_BREAK or event == EVT_ROT_LEFT or event == EVT_LEFT_BREAK then
		index = index - 1
		if index <= 0 then
			index = #indices - 1
			playTone(3000, 100, 0, PLAY_NOW)
		end

		logFile = io.open(LOG_FILE, "r")
		ReadLineData(indices[index])
		if logFile then io.close(logFile) end
		killEvents(event)
	end

	 -- Go to next record
	if event == EVT_PLUS_BREAK or event == EVT_ROT_RIGHT or event == EVT_RIGHT_BREAK then
		index = index + 1
		if index >= #indices then
			index = 1
			playTone(3000, 100, 0, PLAY_NOW)
		end

		logFile = io.open(LOG_FILE, "r")
		ReadLineData(indices[index])
		if logFile then io.close(logFile) end
		killEvents(event)
	end

	-- Time to draw the screen
	if taskScores < 1 then
		DrawMenu(" No scores recorded ")
	else
		Draw(scores, taskScores)
	end
end

return {init = init, run = run}