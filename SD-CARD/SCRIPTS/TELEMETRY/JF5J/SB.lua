-- JF F5J Score Browser
-- Timestamp: 2018-06-01
-- Created by Jesper Frickmann
-- Telemetry script for browsing scores recorded in the log file.

local LOG_FILE = "/LOGS/JF F5J Scores.csv"

local logFile -- Log file handle
local lastTime -- Last time that run() was called, used for refreshing
local indices -- Vector of indices pointing to start of lines in the log file
local index -- Index to currently selected line in log file
local lineData = {} -- Array of data fields from a line

local Draw -- Draw() function is defined for specific transmitter

-- Transmitter specific
if tx == TX_X9D then
	function Draw()
		lcd.drawText(10, 20, "Landing", MIDSIZE)
		lcd.drawNumber(93, 16, lineData[4], DBLSIZE + RIGHT)

		lcd.drawText(10, 42, "Start", MIDSIZE)
		lcd.drawNumber(93, 38, lineData[5] * 10, PREC1 + DBLSIZE + RIGHT)

		lcd.drawText(110, 20, "Target", MIDSIZE)
		lcd.drawTimer(162, 16, lineData[6], DBLSIZE)

		lcd.drawText(110, 42, "Flight", MIDSIZE)
		lcd.drawTimer(162, 38, lineData[7], DBLSIZE)

		lcd.drawText(55, 58, " JF F5J Score Browser ", SMLSIZE)	
		-- Warn if the log file is growing too large
		if #indices > 200 then
			lcd.drawText(55, 57, " Log getting too large ", SMLSIZE + BLINK + INVERS)
		end
	end -- Draw()
else -- QX7 or X-lite
	function Draw()
		lcd.drawText(7, 20, "Landing", SMLSIZE)
		lcd.drawNumber(64, 16, lineData[4], MIDSIZE + RIGHT)

		lcd.drawText(7, 42, "Start", SMLSIZE)
		lcd.drawNumber(64, 38, lineData[5] * 10, PREC1 + MIDSIZE + RIGHT)

		lcd.drawText(68, 20, "Tgt", SMLSIZE)
		lcd.drawTimer(90, 16, lineData[6], MIDSIZE)

		lcd.drawText(68, 42, "Flt", SMLSIZE)
		lcd.drawTimer(90, 38, lineData[7], MIDSIZE)

		lcd.drawText(47, 58, " JF F5J ", SMLSIZE)	
		-- Warn if the log file is growing too large
		if #indices > 200 then
			lcd.drawText(12, 57, " Log getting too large ", SMLSIZE + BLINK + INVERS)
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

-- Read a line of comma separated fields into lineData
local function ReadLineData(pos)
	local pos, lineStr = ReadLine(logFile, pos, 100)
	lineData = {}

	if pos > 0 then
		-- Make array of comma separated values in line string
		for field in string.gmatch(lineStr, "[^,]+") do
			lineData[#lineData + 1] = field
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
	if #lineData < 7 then
		DrawMenu(" No scores recorded ")
	else
		DrawMenu(lineData[2] .. " " .. lineData[3])
		Draw()
	end
end

return {init = init, run = run}
