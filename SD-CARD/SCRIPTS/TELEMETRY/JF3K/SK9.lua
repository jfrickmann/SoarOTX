-- Timing and score keeping, loadable plugin for browsing saved scores
-- Timestamp: 2021-01-02
-- Created by Jesper Frickmann

local sk = ...  -- List of variables shared between fixed and loadable parts

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
local lastTime = 0 -- Last time that run() was called, used for refreshing
local index = 1 -- Index to currently selected line in log file
local ui = soarUtil.LoadWxH("JF3K/SK9.lua", sk) -- Screen size specific user interface

ui.indices = {0} -- Vector of indices pointing to start of lines in the log file +

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
	ui.scores = { }

	charPos, lineStr = ReadLine(logFile, charPos)
	
	for field in string.gmatch(lineStr, "[^,]+") do
		i = i + 1
		
		if i == 1 then
			ui.planeName = field
		elseif i == 2 then
			ui.taskName = field
		elseif i == 3 then
			ui.dateStr = field
		elseif i == 4 then
			ui.timeStr = field
		elseif i == 5 then
			ui.unitStr = field
		elseif i == 6 then
			ui.taskScores = tonumber(field)
		elseif i == 7 then
			ui.totalScore = tonumber(field)
		else
			ui.scores[#ui.scores + 1] = tonumber(field)
		end
	end
end  --  ReadLineData()

local function Scan()
	local i = #ui.indices
	local charPos = ui.indices[#ui.indices]
	local done = false

	logFile = io.open(LOG_FILE, "r")

	-- Read lines of the log file and store indices
	repeat
		charPos = ReadLine(logFile, charPos)
		if charPos == 0 then
			done = true
		else
			ui.indices[#ui.indices + 1] = charPos
		end
	until done

	-- If new data then read last full line of the log file as current record
	if #ui.indices > i then
		index = #ui.indices - 1
		ReadLineData(ui.indices[index])
	end
	
	if logFile then io.close(logFile) end
end -- Scan()

local function init()
	ReadLineData(ui.indices[index])
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
	if event == EVT_VIRTUAL_PREV or event == EVT_VIRTUAL_PREV_REPT then
		index = index - 1
		if index <= 0 then
			index = #ui.indices - 1
			playTone(3000, 100, 0, PLAY_NOW)
		end

		logFile = io.open(LOG_FILE, "r")
		ReadLineData(ui.indices[index])
		if logFile then io.close(logFile) end
		killEvents(event)
	end

	 -- Go to next record
	if event == EVT_VIRTUAL_NEXT or event == EVT_VIRTUAL_NEXT_REPT then
		index = index + 1
		if index >= #ui.indices then
			index = 1
			playTone(3000, 100, 0, PLAY_NOW)
		end

		logFile = io.open(LOG_FILE, "r")
		ReadLineData(ui.indices[index])
		if logFile then io.close(logFile) end
		killEvents(event)
	end

	if event == EVT_VIRTUAL_EXIT then
		sk.run = sk.menu
	end
	
	-- Time to draw the screen
	ui.Draw()
	
	-- Show onscreen help
	soarUtil.ShowHelp({ exit = "GO BACK", ud = "PREV/NEXT RND" })
end

return { init = init, run = run }