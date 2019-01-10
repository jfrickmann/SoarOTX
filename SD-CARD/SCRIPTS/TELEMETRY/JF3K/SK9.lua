-- Timing and score keeping, loadable plugin for browsing saved scores
-- Timestamp: 2019-01-09
-- Created by Jesper Frickmann

-- If no task is selected, then return name and task list to the menu
if sk.task == 0 then
	local name = "Saved scores"

	local tasks = {
		"Score browser"
	}

	return name, tasks
end

local LOG_FILE = "/LOGS/JF F3K Scores.csv"
local logFile -- Log file handle
local task -- Task of the current record
local scores -- Scores recorded
local taskMaxes = { } -- Number of scores for task
local taskName -- Name of current task
local planeName -- Name of plane
local dateStr -- Date saved
local timeStr -- Time saved
local unitStr -- Unit of score(s)
local lastTime = 0 -- Last time that run() was called, used for refreshing
local indices = {0} -- Vector of indices pointing to start of lines in the log file
local index = 1 -- Index to currently selected line in log file
local Draw -- Draw() function is defined for specific transmitter

 -- List of patterns for matching task names
local taskList = {
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

-- Maximum times that can be scored in various tasks
local maxScores = {
	{300},
	{180, 180},
	{240, 240},
	{180, 180, 180, 180, 180, 180, 180, 180},
	{30, 45, 60, 75, 90, 105, 120},
	{599, 599, 599, 599, 599},
	{180, 180, 180},
	{120, 120, 120, 120, 120},
	{240, 180, 120, 60},
	{200, 200, 200},
	{180, 180, 180},
	{60, 90, 120, 150, 180},
	{9999, 9999, 9999, 9999, 9999, 9999, 9999, 9999} -- Last one is the default
}

-- Convert time to minutes and seconds
local function MinSec(t)
	local m = math.floor(t / 60)
	return m, t - 60 * m
end -- MinSec()

-- Transmitter specific
if tx == TX_X9D then
	function Draw()
		local n
		local x = 0
		local y = 9
		local split
		local totalScore = 0

		DrawMenu(taskName)

		if task == #maxScores then
			n = #scores
		else
			n = #taskMaxes
		end
		
		if n == 5 or n == 6 then
			split = 4
		else
			split = 5
		end

		for i = 1, n do
			if i == split then
				x = 50
				y = 9
			end

			local nbr = tonumber(scores[i])

			if nbr then
				if unitStr == "s" then
					lcd.drawText(x, y, string.format("%i. %02i:%02i", i, MinSec(nbr)), MIDSIZE)
				else
					lcd.drawText(x, y, string.format("%i. %3i%s", i, nbr, unitStr), MIDSIZE)
				end

				totalScore = totalScore + math.min(nbr, taskMaxes[i])
			else
				lcd.drawText(x, y, string.format("%i. - - -", i), MIDSIZE)
			end
			
			y = y + 14
		end

		lcd.drawText(105, 10, planeName, DBLSIZE)
		lcd.drawText(105, 32, string.format("%s %s", dateStr, timeStr), MIDSIZE)
		
		if totalScore > 0 then
			lcd.drawText(105, 48, string.format("Total %i %s", totalScore, unitStr), MIDSIZE)
		end
	
		-- Warn if the log file is growing too large
		if #indices > 200 then
			lcd.drawText(40, 57, " Log is getting too large ", BLINK + INVERS)
		end
		
	end -- Draw()
else -- QX7 or X-lite
	function Draw()
		local n
		local y = 8
		local totalScore = 0
		
		DrawMenu(taskName)
		
		if task == #maxScores then
			n = #scores
		else
			-- Only 7 scores on small screens
			n = math.min(7, #taskMaxes)
		end
		
		for i = 1, n do
			local nbr = tonumber(scores[i])

			if not nbr then
				lcd.drawText(0, y, string.format("%i. - - -", i))
			else
				if unitStr == "s" then
					lcd.drawText(0, y, string.format("%i. %02i:%02i", i, MinSec(nbr)))
				else
					lcd.drawText(0, y, string.format("%i. %3i%s", i, nbr, unitStr))
				end

				totalScore = totalScore + math.min(nbr, taskMaxes[i])
			end

			y = y + 8
		end	

		lcd.drawText(50, 10, planeName, MIDSIZE)
		lcd.drawText(50, 28, string.format("%s %s", dateStr, timeStr))
		
		if totalScore > 0 then
			lcd.drawText(50, 42, string.format("Total %i %s", totalScore, unitStr))
		end
		
		-- Warn if the log file is growing too large
		if #indices > 200 then
			lcd.drawText(5, 57, " Log getting too large ", BLINK + INVERS)
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
	scores = { }

	charPos, lineStr = ReadLine(logFile, charPos)
	
	for field in string.gmatch(lineStr, "[^,]+") do
		i = i + 1
		
		if i == 1 then
			planeName = field
		elseif i == 2 then
			taskName = field
			task = #maxScores -- Default to last record in maxScores
			
			-- Find the right task and max. score times
			for j = 1, #taskList do
				if string.find(field, taskList[j]) then
					task = j
				end
			end
			
			taskMaxes = maxScores[task]
			
		elseif i == 3 then
			dateStr = field
		elseif i == 4 then
			timeStr = field
		elseif i == 5 then
			unitStr = field
		else
			scores[i - 5] = field
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

	if event == EVT_EXIT_BREAK then
		sk.run = sk.menu
	end
	
	-- Time to draw the screen
	if #taskMaxes < 1 then
		DrawMenu(" No scores recorded ")
	else
		Draw()
	end
end

return { init = init, run = run }