-- JF Log Data Graph, loadable part for reading data
-- Timestamp: 2020-12-13
-- Created by Jesper Frickmann

local gr = ... -- List of shared variables

-- First excluded is rudder
local FIRST_EXCLUDED = "Rud"
 -- in the right language!
 do
	local lang = getGeneralSettings().language
	
	if lang == "CZ" then
		FIRST_EXCLUDED = "Smer"
	elseif lang == "DE" then
		FIRST_EXCLUDED = "Sei"
	elseif lang == "FR" or lang == "IT" then
		FIRST_EXCLUDED = "Dir"
	elseif lang == "PL" then
		FIRST_EXCLUDED = "SK"
	elseif lang == "PT" then
		FIRST_EXCLUDED = "Lem"
	elseif lang == "SE" then
		FIRST_EXCLUDED = "Rod"
	end
end

-- Constants
local ALTI_PLOT ="Alt" -- Default plot variable
local TIME_GAP = 20 -- Time gap that triggers a new flight
local MIN_TIME = 20 -- Minimum time of flight that will be plotted
local READ_MAX = 4 -- Max. no. of record to read in one go

-- Construct the file name for today's log file for the current model
local logFileName = string.gsub (model.getInfo().name, " ", "_") -- Log file name
do
	local date = getDateTime()
	local dateStr = string.format("-%04d-%02d-%02d", date.year, date.mon, date.day)
	logFileName = "/LOGS/" .. logFileName .. dateStr .. ".csv"
end

-- Global variables for keeping track of the log file
local logFile -- Log file handle
local logFilePos -- current position in log file
local lineData -- Holds the data fields of a line

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
	local pos, lineStr = ReadLine(logFile, logFilePos, 300)
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

if not gr.yValues then
	-- Initialize shared variables
	gr.yValues = { } -- Y values to be plotted
	gr.flightTable = { } -- Table for finding position in file and start and end times of flights
	gr.flightIndex = 0 -- Index of current flight in the above table
	gr.logFileHeaders = { } -- Header line fields in log file
	gr.viewMode = 1 -- View mode; 1=normal, 2=stats, 3=details/slope

	local scanPos = 0 -- Last position in log file that was scanned
	local fmLaunchCount = 0 -- Count consecutive records with flight mode Launch, and set start of flight to second record
	local lastTimeStamp = 0 -- Look for gaps in timestamps as well

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
				gr.logFileHeaders[i] = lineData[i]
			end

			-- Look for trigger field and default plot variable field
			gr.plotIndex = 3
			gr.altIndex = -1
			gr.plotIndexLast = #gr.logFileHeaders

			for i = 1, #lineData do
				if gr.logFileHeaders[i] == "FM" then
					gr.fmIndex = i
				end
				
				if string.sub(gr.logFileHeaders[i], 1, string.len(ALTI_PLOT)) == ALTI_PLOT then
					gr.plotIndex = i
					gr.altIndex = i
				end

				if gr.logFileHeaders[i] == FIRST_EXCLUDED then
					gr.plotIndexLast = i - 1
				end
			end
		end
	end  --  StartScan()

	local function Scan()
		local startPos -- Start position in log file of current record
		local timeStamp -- Time stamp of latest record
		
		for i = 1, READ_MAX do
			-- Remember start position of record to be read
			startPos = logFilePos
			ReadLineData()

			if #lineData < 2 then
				-- End of file
				scanPos = startPos

				-- Did we get a full flight for the last record?
				local j = #gr.flightTable
				
				if j > 0 then
					if TimeSerial(gr.flightTable[j][3]) - TimeSerial(gr.flightTable[j][2]) < MIN_TIME then
						gr.flightTable[j] = nil
					end
				end
				
				-- Is it first time scanning to the end? Then set flightIndex to last flight
				if gr.flightIndex == 0 then
					gr.flightIndex = #gr.flightTable
				end

				io.close(logFile)
				return true
			else
				timeStamp = TimeSerial(lineData[2])
				
				-- Count consecutive records with flight trigger activated
				if gr.fmIndex then
					if 1 * lineData[gr.fmIndex] == soarUtil.FM_LAUNCH then
						fmLaunchCount = fmLaunchCount + 1
					else
						fmLaunchCount = 0
					end
				end
				
				-- First record with flight trigger activated is start of a new flight
				-- Time gap is start of a new flight, go back in time is start of new flight
				if fmLaunchCount == 1 or timeStamp - lastTimeStamp > TIME_GAP  or timeStamp <= lastTimeStamp then
					-- Overwrite records with zero time span
					local j = #gr.flightTable
					
					if j > 0 then
						if TimeSerial(gr.flightTable[j][3]) - TimeSerial(gr.flightTable[j][2]) < MIN_TIME then
							j = j - 1
						end
					end
					
					j = j + 1
					gr.flightTable[j] = {startPos, lineData[2], lineData[2]}
				else
					if fmLaunchCount == 0 and #gr.flightTable > 0 then
						-- Record end of flight 
						gr.flightTable[#gr.flightTable][3] = lineData[2]
					end
				end
				
				lastTimeStamp = timeStamp
			end
		end
	end  --  Scan()

	local function run()
		soarUtil.InfoBar(" Scanning... ")

		if not logFile then 
			lcd.drawText(2, 12, "No data", DBLSIZE)
			return StartScan()
		else
			return Scan()
		end
	end -- run()
	
	return { run = run }

else -- yValues

	local findLaunchAlt -- Do we want to find launch altitude?
	local timerStart -- Time of starting flight timer
	local indexRead -- Index of X, Y point currently being read
	local timeStart, timeEnd -- Start and end of current flight
	
	-- X and Y values used for interpolation of flight graph
	local x1
	local x2
	local y1
	local y2

	local function ReadX2Y2()
		ReadLineData()
		
		if #lineData < gr.plotIndex then
			x2 = 0
			y2 = 0
		else
			x2 = TimeSerial(lineData[2])
			y2 = lineData[gr.plotIndex]
		end
	end  --  ReadXY()

	local function StartReading()
		-- Do we have any flights yet?
		if #gr.flightTable == 0 then
			gr.yValues = nil
			return
		end
		
		logFile = io.open(logFileName, "r")
		logFilePos = gr.flightTable[gr.flightIndex][1]
		if gr.viewMode == 4 then
			timeStart = TimeSerial(gr.flightTable[gr.flightIndex][2]) + gr.tMin
			timeEnd = TimeSerial(gr.flightTable[gr.flightIndex][2]) + gr.tMax		
		else
			timeStart = TimeSerial(gr.flightTable[gr.flightIndex][2])
			timeEnd = TimeSerial(gr.flightTable[gr.flightIndex][3])
			gr.tMin = 0
			gr.tMax = timeEnd - timeStart
		end
		
		for i = 0, gr.right - gr.left do
			gr.yValues[i] = 0
		end

		-- Read first two lines of data
		ReadX2Y2()
		x1 = x2
		y1 = y2		
		ReadX2Y2()

		if gr.plotIndex == gr.altIndex then
			if gr.fmIndex then
				findLaunchAlt = 1
			end
		else
			findLaunchAlt = 0
		end
		
		gr.launchAlt = 0
		indexRead = 0
	end  --  StartReading()

	local function Read()
		local i = 0
		local y

		repeat
			-- X value that we are looking for
			local x0 =  timeStart + indexRead * (timeEnd - timeStart) / (gr.right - gr.left)

			if x0 < timeEnd + 1E-8 then
				-- Start searching for bracketing X values
				while x2 < x0 - 1E-8 do
					x1 = x2
					y1 = y2
					ReadX2Y2()
					
					if findLaunchAlt == 1 then
						-- Set timerStart when Launch is ended
						if 1 * lineData[gr.fmIndex] ~= soarUtil.FM_LAUNCH then
							timerStart = x2
							findLaunchAlt = 2
						end
					elseif findLaunchAlt == 2 then
						-- Set launch alt after 10 sec.
						if x2 >= timerStart + 10.0 then
							gr.launchAlt = gr.yMax
							findLaunchAlt = 0
						end				
					end

					-- If max. records have been read; take a break
					i = i + 1
					if i > READ_MAX then
						return collectgarbage()
					end
				end
				
				-- Interpolate to find y-value
				y = y1 + (x0 - x1) / (x2 - x1) * (y2 - y1)
				
				if indexRead == 0 then
					gr.yMax = y
					gr.yMin = y
				else
					gr.yMax = math.max(y, gr.yMax)
					gr.yMin = math.min(y, gr.yMin)
				end
				
				gr.yValues[indexRead] = y
			end

			indexRead = indexRead + 1
		until indexRead > gr.right - gr.left

		-- All values have been read; time to plot
		io.close(logFile)
		
		-- Load Lua file for interactive plotting
		gr.run = gr.graph
	end  --  Read()

	local function run()
		soarUtil.InfoBar(" Reading... ")

		if not logFile then
			return StartReading()
		else
			return Read()
		end
	end -- run()
	
	return { run = run }

end
