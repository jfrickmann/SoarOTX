-- JF F3K Timing and score keeping, fixed part
-- Timestamp: 2017-02-23
-- Created by Jesper Frickmann
-- Telemetry script for timing and keeping scores for the official F3K tasks.
-- Depends on library functions in FUNCTIONS/JFLib.lua

local myFile = "/SCRIPTS/TELEMETRY/JF3KskLd.lua" -- Lua file to be loaded and unloaded
local FM_LAUNCH = 1 -- Flight mode used for launch
local flightMode = getFlightMode() -- Used for detecting when FM changes
local	flightTimeOld = 0 -- Current flight time since launch
local	flightTimerOld -- Previous value of flight timer
local	countIndex -- Index of timer count
local	targetTime -- Current flight target time

-- Globals
skLocals = {} -- List of local variables shared with the loadable part
fTmr = 0 -- Controls flight timer with MIXES script
windowRunning = true -- Task window is running, controls window timer with MIXES script

-- Some skLocals.task index constants
skLocals.TASK_LASTFL = 1
skLocals.TASK_2LAST4 = 3
skLocals.TASK_AULD = 4
skLocals.TASK_LADDER = 5
skLocals.TASK_POKER = 6
skLocals.TASK_5X2 = 8
skLocals.TASK_1234 = 9
skLocals.TASK_3BEST = 10
skLocals.TASK_BIGLAD = 12
skLocals.TASK_TURN = 13
skLocals.TASK_JUSTFL = 14

skLocals.eowTimerStop = true -- Freeze timer automatically at the end of the window
skLocals.quickRelaunch = false -- Restart timer immediately
skLocals.task = skLocals.TASK_JUSTFL -- Selected task index
local autoStart = true -- Task was automatically started - stop when score keeper screen is activated

-- 	Other variables stored in skLocals list:
--[[	winTimer -- Current value of the window timer
	winTimerOld -- Previous value of the window timer
	flightTimer -- Current value of flight timer (count down)
	flying -- Flight is ongoing
	
	counts -- Flight timer countdown
	pokerMinId -- Input Id for setting minutes in Poker
	pokerSecId -- Input Id for setting seconds in Poker

	taskScores -- Number of scores to record
	finalScores -- Does skLocals.task end when all scores are made?
	taskLaunches -- Number of launches allowed
	taskScoreTypes -- 1=last 2=best 3=must make time
	taskWindow -- Window times

	scores -- Scores recorded
	launches -- Number of launches
	comitted -- After 5 seconds, flights are comitted i.e. cannot be canceled
	pokerCalled -- Freeze target time until it has been completed
	launchesLeft -- Number of launches left in task window ]]--

-- Add new score to existing scores, keeping only the last scores
function RecordLast(scores, newScore)
	local n = #scores
	if n >= skLocals.taskScores[skLocals.task] then
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
	if n < skLocals.taskScores[skLocals.task] then n = n + 1 end

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

function PokerTime()
	local m = math.floor((1024 + getValue(skLocals.pokerMinId)) / 205)
	local s = math.floor((1024 + getValue(skLocals.pokerSecId)) / 34.2)
	if skLocals.task == skLocals.TASK_POKER then
		return math.max(5, math.min(skLocals.winTimer - 1, 60 * m + s))
	else
		return math.max(5, 60 * m + s)
	end
end -- PokerTime()

function SetFlightTimer()
	if skLocals.task == skLocals.TASK_LASTFL then
		targetTime = 300
	elseif skLocals.task == skLocals.TASK_2LAST4 then
		targetTime = 240
	elseif skLocals.task == skLocals.TASK_LADDER then
		targetTime = 30 + 15 * #skLocals.scores
	elseif skLocals.task == skLocals.TASK_POKER then
		if not skLocals.pokerCalled then
			targetTime = PokerTime()
		end
	elseif skLocals.task == skLocals.TASK_5X2 then
		targetTime = 120
	elseif skLocals.task == skLocals.TASK_1234 then
		targetTime = Best1234Target(skLocals.winTimer, skLocals.scores, 4)
	elseif skLocals.task == skLocals.TASK_3BEST then
		targetTime = 200
	elseif skLocals.task == skLocals.TASK_BIGLAD then
		targetTime = 60 + 30 * #skLocals.scores
	elseif skLocals.task == skLocals.TASK_TURN then
		targetTime = PokerTime()
	elseif skLocals.task == skLocals.TASK_JUSTFL then
		targetTime = 0
	else
		targetTime = 180
	end

	-- Set flight timer
	local timerParms = {
		start = targetTime,
		value = targetTime + 0.5
	}

	model.setTimer(0, timerParms)
	skLocals.flightTimer = targetTime
	flightTimerOld = skLocals.flightTimer
end  --  SetFlightTimer()

local function background()
	-- Keep calling the loadable part until initialization is complete
	if not skLocals.initialized then
		return LdRun(myFile, event)
	end
	
	skLocals.launchesLeft = skLocals.taskLaunches[skLocals.task] - skLocals.launches

	if windowRunning then
		local timerData = model.getTimer(0)
		local flightModeNew = getFlightMode()
		local flightTime = math.abs(timerData.start - timerData.value)

		skLocals.winTimer = model.getTimer(1).value
		skLocals.flightTimer = timerData.value

		-- Beep at beginning and end of window
		if skLocals.task ~= skLocals.TASK_AULD and skLocals.task ~= skLocals.TASK_TURN and skLocals.task ~= skLocals.TASK_JUSTFL and
				((skLocals.winTimerOld >= skLocals.taskWindow[skLocals.task] + 1 and skLocals.winTimer < skLocals.taskWindow[skLocals.task] + 1) or
				(skLocals.winTimerOld >= 0 and skLocals.winTimer < 0)) then
			playTone(880, 1000, PLAY_NOW)
		end

		-- Launch mode entered
		if (flightModeNew == FM_LAUNCH and flightMode ~= FM_LAUNCH) then
			-- Stop timer and record score if flying
			if skLocals.flying then
				skLocals.flying = false
				
				if not skLocals.quickRelaunch or not skLocals.comitted then
					-- Do not restart timer
					fTmr = 0
				end

				-- Only record skLocals.comitted flights (over 5 seconds)
				if skLocals.comitted then
					skLocals.comitted = false

					if skLocals.taskScoreTypes[skLocals.task] == 1 then
						RecordLast(skLocals.scores, flightTime)
						
						-- In skLocals.task Just Fly!, report the time after flight is done
						if skLocals.task == skLocals.TASK_JUSTFL then
							playDuration(flightTime, 0)
						end
					
					elseif skLocals.taskScoreTypes[skLocals.task] == 2 then
						RecordBest(skLocals.scores, flightTime)
					else
						-- Only record if target time was made i.e. timer negative
						if timerData.value <= 0 then
							if skLocals.task == skLocals.TASK_POKER then
								RecordLast(skLocals.scores, timerData.start) -- only target time!
								skLocals.pokerCalled = false
							else
								RecordLast(skLocals.scores, flightTime)
							end
						end
					end
				end
			else
				-- If not flying, get ready to start timer
				fTmr = 1
			end

			-- If allowed number of launches have been reached, or window is over, then do not start timer again
			if skLocals.launches == skLocals.taskLaunches[skLocals.task] or skLocals.winTimer < 0 or
					(skLocals.finalScores[skLocals.task] and #skLocals.scores == skLocals.taskScores[skLocals.task]) then
				fTmr = 0
			end
		end

		-- Launch mode left.
		if flightModeNew ~= FM_LAUNCH and flightMode == FM_LAUNCH then
			if fTmr == 1 then
				skLocals.flying = true

				-- Report the target time (target is always zero in skLocals.task Just Fly!)
				if skLocals.task ~= skLocals.TASK_JUSTFL then
					playDuration(targetTime, 0)
				end

			else
				-- Play tone to warn that timer is NOT running
				playTone(1760, 333, 0, PLAY_NOW)
			end
		end

		if skLocals.flying then
			-- If EoW is on and window expired, then freeze the flight timer
			if skLocals.winTimer < 0 and skLocals.eowTimerStop then
				fTmr = 0
			end

			-- After 5 seconds, commit flight
			if flightTimeOld <= 5 and flightTime > 5 then
				skLocals.comitted = true
				skLocals.launches = skLocals.launches + 1

				-- Call Poker
				if skLocals.task == skLocals.TASK_POKER then skLocals.pokerCalled = true end
			end

			-- Is it time to count down?
			if skLocals.flightTimer <= skLocals.counts[countIndex] and flightTimerOld > skLocals.counts[countIndex]  then
				if skLocals.flightTimer > 15 then
					playDuration(skLocals.flightTimer, 0)
				else
					playNumber(skLocals.flightTimer, 0)
				end
				if countIndex > 1 then countIndex = countIndex - 1 end
			end

		else
			SetFlightTimer()

			-- Get ready to count down
			countIndex = #skLocals.counts
			while countIndex > 1 and skLocals.counts[countIndex] >= targetTime do
				countIndex = countIndex - 1
			end

			-- If all launches or scores have been made or window has expired; stop window
			if skLocals.launchesLeft <= 0 or (skLocals.finalScores[skLocals.task] and #skLocals.scores >= skLocals.taskScores[skLocals.task]) or skLocals.winTimer < 0 then
				windowRunning = false
				playTone(1760, 100, PLAY_NOW)
			end
		end

		flightMode = flightModeNew
		skLocals.winTimerOld = skLocals.winTimer
		flightTimerOld = skLocals.flightTimer
		flightTimeOld = flightTime

	else -- Window is not running

		-- In Poker, update flight timer with values set by knobs
		if skLocals.task == skLocals.TASK_POKER or skLocals.task == skLocals.TASK_TURN then SetFlightTimer() end
	end
end  --  background()

-- Forward run() call to the loadable part
local function run(event)
	if autoStart then
		autoStart = false
		if not skLocals.flying then
			windowRunning = false
		end
	end
	return LdRun(myFile, event)
end

return {background = background, run = run}