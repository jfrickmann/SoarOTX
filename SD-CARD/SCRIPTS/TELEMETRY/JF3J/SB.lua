-- JF F3J Score Browser
-- Timestamp: 2021-01-03
-- Created by Jesper Frickmann
-- Telemetry script for browsing scores recorded in the log file.

local LOG_FILE = "/LOGS/JF F3J Scores.csv" -- Log file
local skFile = "/SCRIPTS/TELEMETRY/JF3J/SK.lua" -- Score keeper user interface file
local sk = ...  -- List of variables shared between fixed and loadable parts
local logFile -- Log file handle
local lastTime = 0 -- Last time that run() was called, used for refreshing
local index = 1 -- Index to currently selected line in log file
local ui = soarUtil.LoadWxH("JF3J/SB.lua") -- List of  variables shared with loadable user interface
ui.indices = {0} -- Vector of indices pointing to start of lines in the log file
ui.lineData = {} -- Array of data fields from a line

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

-- Read a line of comma separated fields into lineData
local function ReadLineData(pos)
	local pos, lineStr = ReadLine(logFile, pos, 100)
	ui.lineData = {}

	if pos > 0 then
		-- Make array of comma separated values in line string
		for field in string.gmatch(lineStr, "[^,]+") do
			ui.lineData[#ui.lineData + 1] = field
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
	
	-- Show score keeper
	if event == EVT_VIRTUAL_EXIT then
		sk.myFile = skFile
	end
	
	-- Go to previous record
	if event == EVT_VIRTUAL_PREV or event == EVT_VIRTUAL_PREV_REPT then
		index = index - 1
		if index <= 0 then
			index = #ui.indices - 1
			playTone(1760, 100, 0, PLAY_NOW)
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

	-- Time to draw the screen
	ui.Draw()
	soarUtil.ShowHelp({ exit = "BACK", lr = "PREV/NEXT" })
end

return {init = init, run = run}