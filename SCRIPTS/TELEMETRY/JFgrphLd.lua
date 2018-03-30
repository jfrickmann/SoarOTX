-- JF Log Data Graph
-- Timestamp: 2018-02-12
-- Created by Jesper Frickmann
-- Telemetry script for plotting telemetry parameters recorded in the log file.
-- The graph design was inspired by Nigel Sheffield's script

-- Constants
local FM_LAUNCH = 1 -- Launch flight mode

local FIRST_EXCLUDED = "Rud" -- First variable not to be included in plot
local ALTI_PLOT ="Alti(m)" -- Altitude is default plot variable

local TIME_GAP = 20 -- Time gap that triggers a new flight
local MIN_TIME = 20 -- Minimum time of flight that will be plotted
local READ_MAX = 15 -- Max. no. of record to read in one go

-- We cannot read the entire file in one go. Therefore, we use "state" to keep track of the 
-- current state across repeated calls, where a limited number of lines can be read per call.
local STATE_SCAN = 1 -- Scanning log file for new records and indexing flights
local STATE_READ = 2 -- Reading data from a flight into array for plotting
local STATE_PLOT = 3 -- Plot graph on the screen

-- Global variables for keeping track of the log file
local logFileName -- Log file name
local logFile -- Log file handle
local logFilePos -- current position in log file
local logFileHeaders -- Header line fields in log file
local lineData -- Holds the data fields of a line

local flightTable -- Table for finding position in file and start and end times of flights
local flightIndex -- Index of current flight in the above table

local state -- Keeps track of what state is active across calls to run() and background()
local scanPos -- Last position in log file that was scanned
local fmIndex -- Index of the field holding the flight mode variable
local fmLaunchCount -- Count consecutive records with flight mode Launch, and set start of flight to second record
local lastTimeStamp -- Look for gaps in timestamps as well
local lastTime -- Last time that run() was called, used for refreshing

local plotIndex -- Index of the field holding the variable to be plotted
local plotIndexLast -- Index of last field that can be plotted
local timeSerialStart -- Serial start time of flight
local timeSerialEnd -- Serial end time of flight

local viewStats -- View statistics instead of graph
local findLaunchAlt -- Do we want to find launch altitude?
local timerStart -- Time of starting flight timer
local launchAlt -- launch altitude
local xScaleMax -- Max. X-scale
local yMin -- Min. Y
local yMax -- Max. Y
local yScaleMax -- Max. Y-scale
local yScaleMin -- Min. Y-scale
local indexRead -- Index of X, Y point currently being read
local yValues -- Y values to be plotted

-- X and Y values used for interpolation of flight graph
local x1
local x2
local y1
local y2

local function TimeSerial(str)
	local hr = string.sub(str, 1, 2)
	local mn = string.sub(str, 4, 5)
	local sc = string.sub(str, 7, 12)
	
	return 3600 * hr + 60 * mn + sc
end  --  TimeSerial

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
local function ReadLineData()
	local pos, lineStr = ReadLine(logFile, logFilePos, 200)
	lineData = {}

	if pos > 0 then
		logFilePos = pos
		
		-- Make array of comma separated values in line string
		for field in string.gmatch(lineStr, "[^,]+") do
			lineData[#lineData + 1] = field
		end
	end
	
	-- Saves ~17KB memory:
	return collectgarbage()
end  --  ReadLineData()

local function ReadX2Y2()
	ReadLineData()
	
	if #lineData < plotIndex then
		x2 = 0
		y2 = 0
	else
		x2 = TimeSerial(lineData[2])
		y2 = lineData[plotIndex] * 1
	end
end  --  ReadXY()

local function StartReading()
	logFile = io.open(logFileName, "r")

	logFilePos = flightTable[flightIndex][1]
	timeSerialStart = TimeSerial(flightTable[flightIndex][2])
	timeSerialEnd = TimeSerial(flightTable[flightIndex][3])
	xScaleMax = timeSerialEnd - timeSerialStart		
	
	-- Read first two lines of data to set x1 x2 y1 y2
	ReadX2Y2()
	x1 = x2
	y1 = y2
	
	if fmIndex > 0 then
		if logFileHeaders[plotIndex] == ALTI_PLOT then
			findLaunchAlt = 1
		else
			findLaunchAlt = 0
		end
	end
	
	ReadX2Y2()
	yMax = y2
	yMin = y2
	launchAlt = 0
	indexRead = 1
	state = STATE_READ	
end  --  StartReading()

local function Read()
	local i = 0
	local climb

	repeat
		-- X value that we are looking for
		local x0 = timeSerialStart + (indexRead - 1) * xScaleMax / (LCD_W - 28)

		if x0 < timeSerialEnd then
			-- Start searching for bracketing X values
			while x2 < x0 do
				x1 = x2
				y1 = y2
				ReadX2Y2()
				
				yMax = math.max(y2, yMax)
				yMin = math.min(y2, yMin)

				if findLaunchAlt == 1 then
					-- Set timerStart when Launch is ended
					if 1 * lineData[fmIndex] ~= FM_LAUNCH then
						timerStart = x2
						findLaunchAlt = 2
					end
				elseif findLaunchAlt == 2 then
					-- Set launch alt after 10 sec.
					if x2 >= timerStart + 10.0 then
						launchAlt = yMax
						findLaunchAlt = 0
					end				
				end

				-- If max. records have been read; take a break
				i = i + 1
				if i > READ_MAX then
					return
				end
			end			
			yValues[indexRead] = y1 + (x0 - x1) / (x2 - x1) * (y2 - y1)
		end

		indexRead = indexRead + 1
	until x0 >= timeSerialEnd

	-- All values have been read; time to plot
	io.close(logFile)
	yScaleMin = yMin
	yScaleMax = yMax
	state = STATE_PLOT
end  --  Read()

local function StartScan()
	logFile = io.open(logFileName, "r")

	if logFile == nil then
		lastTime = 0
		return
	end

	logFilePos = scanPos	

	-- If at the start of the file, then read header line first
	if logFilePos == 0 then
		-- Read headers
		ReadLineData()
		
		if #lineData == 0 then
			lastTime = 0
			return
		end

		for i = 1, #lineData do
			logFileHeaders[i] = lineData[i]
		end

		-- Look for trigger field and default plot variable field
		for i = 1, #lineData do
			if logFileHeaders[i] == "FM" then
				fmIndex = i
			end
			
			if logFileHeaders[i] == ALTI_PLOT then
				plotIndex = i
			end

			if logFileHeaders[i] == FIRST_EXCLUDED then
				plotIndexLast = i - 1
			end
		end
		
		if not plotIndex then plotIndex = 3 end
		if not plotIndexLast then plotIndexLast = #logFileHeaders end
	end

	state = STATE_SCAN	
end  --  StartScan()

local function Scan()
	local j
	local timeStamp
	local startPos
	
	for i = 1, READ_MAX do
		-- Remember start position of record to be read
		startPos = logFilePos
		ReadLineData()

		if #lineData < 2 then
			-- End of file
			scanPos = startPos

			-- Is it first time scanning to the end? Then set flightIndex to last flight
			if flightIndex == 0 then
				flightIndex = #flightTable
			end

			io.close(logFile)
			return StartReading()
		else
			timeStamp = TimeSerial(lineData[2])
			
			-- Count consecutive records with flight trigger activated
			if fmIndex > 0 then
				if 1 * lineData[fmIndex] == FM_LAUNCH then
					fmLaunchCount = fmLaunchCount + 1
				else
					fmLaunchCount = 0
				end
			end
			
			-- First record with flight trigger activated is start of a new flight
			-- Time gap is start of a new flight, go back in time is start of new flight
			if fmLaunchCount == 1 or timeStamp - lastTimeStamp > TIME_GAP  or timeStamp <= lastTimeStamp then
				-- Overwrite records with zero time span
				j = #flightTable
				
				if j > 0 then
					if TimeSerial(flightTable[j][3]) - TimeSerial(flightTable[j][2]) < MIN_TIME then
						j = j - 1
					end
				end
				
				j = j + 1
				flightTable[j] = {startPos, lineData[2], lineData[2]}
			else
				if fmLaunchCount == 0 and #flightTable > 0 then
					-- Record end of flight 
					flightTable[#flightTable][3] = lineData[2]
				end
			end
			
			lastTimeStamp = timeStamp
		end
	end
end  --  Scan()

local function DrawGraph()
	local x0
	local mag
	local flags
	local precFac
	
	local yRange
	local yy1
	local yy2
	local xTick
	local yTick
	local m
	local b
	local b2

	-- Sometimes, a min. scale of zero looks better...
	if yScaleMin < 0 then
		if -yScaleMin < 0.08 * yScaleMax then
			yScaleMin = 0
		end
	else
		if yScaleMin < 0.5 *  yScaleMax then
			yScaleMin = 0
		end
	end
	yRange = yScaleMax - yScaleMin
	
	if yRange <= 1E-8 then
		yRange = 0.04
		yScaleMin = yScaleMin - 0.02
		yScaleMax = yScaleMin + 0.04
	end
	
	-- Find horizontal tick line distance
	mag = math.floor(math.log(yRange, 10))
	if mag < -2 then mag = -2 end -- Don't go crazy with the scale

	if yRange / 10^mag > 6 then
		yTick = 2 * 10^mag
	elseif yRange / 10^mag > 3 then
		yTick = 1 * 10^mag
	elseif yRange / 10^mag > 2.4 then
		yTick = 0.5 * 10^mag
	elseif yRange / 10^mag > 1.2 then
		yTick = 0.4 * 10^mag
	else
		yTick = 0.2 * 10^mag
	end
	
	-- Flags for number precision
	if yTick < 0.1 then
		flags = PREC2
		precFac = 100
	elseif yTick < 1 then
		flags = PREC1
		precFac = 10
	else
		flags = 0
		precFac = 1
	end

	-- Find linear transformation from Y to screen pixel
	if yScaleMin == 0 then
		m = (18 - LCD_H) / yRange
		b = LCD_H - m * yScaleMin - 3
	else
		m = (22 - LCD_H) / yRange
		b = LCD_H - m * yScaleMin - 7
	end

	-- Pixel coordinate of X axis
	if yScaleMin > 0 then
		b2 = LCD_H - 3
	else
		b2 = b
	end
	
	-- Draw horizontal grid lines
	for i = math.ceil(yScaleMin / yTick) * yTick, math.floor(yScaleMax / yTick) * yTick, yTick do
		yy1 = m * i + b
		if math.abs(i) > 1E-8 then
			lcd.drawLine(3, yy1, LCD_W - 15, yy1, DOTTED, GRAY)
			lcd.drawNumber(LCD_W - 3, yy1 - 3, math.floor(precFac * i + 0.5), SMLSIZE + RIGHT + flags)
		end
	end
	
	-- Find vertical grid line distance
	if xScaleMax > 6000 then
		xTick = 600
	elseif xScaleMax > 3000 then
		xTick = 300
	elseif xScaleMax > 1200 then
		xTick = 120
	else
		xTick = 60
	end
	
	-- Draw vertical grid lines
	for i = xTick, math.floor(xScaleMax / xTick) * xTick, xTick do
		xx1 = 1 + (LCD_W - 27) * i / xScaleMax
		lcd.drawLine(xx1, LCD_H - 3, xx1, 11, DOTTED, GRAY)
	end

	-- Plot the graph
	for i = 2, LCD_W - 27 do
		x0 = timeSerialStart + (i - 1) * xScaleMax / (LCD_W - 28)
		if x0 <= timeSerialEnd then
			yy1 = m * yValues[i - 1] +b
			yy2 = m * yValues[i] + b
			
			lcd.drawLine(i + 1, yy2, i + 1, b2, SOLID, GRAY)
			lcd.drawLine(i, yy1, i + 1, yy2, SOLID, FORCE)
		end
	end

	-- Draw line through zero
	lcd.drawLine(2, b2, LCD_W - 11, b2, SOLID, FORCE)
	if yScaleMin < 0 then
		lcd.drawNumber(LCD_W - 3, b2 - 3, 0, SMLSIZE + RIGHT)
	end
end  --  DrawGraph()

local function init()
	local dte
	
	-- Construct the file name for today's log file for the current model
	dte = getDateTime()
	logFileName = model.getInfo().name
	logFileName = string.gsub (logFileName, " ", "_")
	logFileName = "/LOGS/" .. logFileName .. string.format("-%04d-%02d-%02d", dte.year, dte.mon, dte.day) .. ".csv"
	
	logFileHeaders = {}
	flightTable = {}
	flightIndex = 0
	
	scanPos = 0
	fmLaunchCount = 0
	fmIndex = 0
	lastTimeStamp = 0
	yValues = {}
	
	for i = 1, LCD_W - 27 do
		yValues[i] = 0
	end
	
	viewStats = false
	lastTime = 0
end  --  init()

local function run(event)
	-- Look for new data if inactive for over 1 second
	local thisTime = getTime()
	local passedTime = thisTime - lastTime
	lastTime = thisTime
	
	if passedTime > 100 then
		DrawMenu(" No data. ")
		return StartScan()
	elseif state == STATE_SCAN then
		DrawMenu(" Scanning... ")
		return Scan()
	elseif state == STATE_READ then
		DrawMenu(" Reading... ")
		return Read()
	elseif state == STATE_PLOT then
		local title = " " .. string.sub(flightTable[flightIndex][2], 1, 8) .. "\t" .. logFileHeaders[plotIndex]
		DrawMenu(title)

		-- Plus button was pressed; read next flight
		if event == EVT_PLUS_BREAK or event == EVT_ROT_RIGHT then
			flightIndex = flightIndex + 1
			if flightIndex > #flightTable then
				flightIndex = 1
			end
			return StartReading()
		end

		-- Minus button was pressed; read previous flight
		if event == EVT_MINUS_BREAK or event == EVT_ROT_LEFT then
			flightIndex = flightIndex - 1
			if flightIndex < 1 then
				flightIndex = #flightTable
			end
			return StartReading()
		end

		-- Enter button was pressed; change plot variable
		if event == EVT_ENTER_BREAK then
			plotIndex = plotIndex + 1
			if plotIndex > plotIndexLast then
				plotIndex = 3
			end
			return StartReading()
		end
		
		-- Menu button was  pressed; toggle viewStats
		if event == EVT_MENU_BREAK then
			viewStats = not viewStats
		end
		
		if viewStats then
			-- Print statistics
			lcd.drawText(10, 16, "Duration")
			lcd.drawTimer(88, 16, xScaleMax, RIGHT)

			lcd.drawText(10, 26, "Minimum")
			lcd.drawNumber(85, 26, 100 * yMin, PREC2 + RIGHT)

			lcd.drawText(10, 36, "Maximum")
			lcd.drawNumber(85, 36, 100 * yMax, PREC2 + RIGHT)
			
			if launchAlt > 0 then
				lcd.drawText(10, 46, "Launch")
				lcd.drawNumber(85, 46, 100 * launchAlt, PREC2 + RIGHT)
			end
			
			lcd.drawText(LCD_W / 2 - 25, 58, " JF Graph ", SMLSIZE)
		else
			-- Draw graph
			return DrawGraph()
		end
	end	
end  --  run()

return {init = init, run = run}
