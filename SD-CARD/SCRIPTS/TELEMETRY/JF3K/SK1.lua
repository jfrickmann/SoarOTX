-- Timing and score keeping, loadable plugin for 2020 F3K tasks
-- Timestamp: 2020-05-10
-- Created by Jesper Frickmann

local sk = ...  -- List of variables shared between fixed and loadable parts

-- If no task is selected, then return name and task list to the menu
if sk.task == 0 then
	local name = "F3K"

	local tasks = {
		"A. Last flight",
		"B. Two last flights 3:00",
		"B. Two last flights 4:00",
		"C. All up last down",
		"D. Two flights only",
		"E. Poker 10 min.",
		"E. Poker 15 min.",
		"F. Three best out of six",
		"G. Five best flights",
		"H. 1-2-3-4 in any order",
		"I. Three best flights",
		"J. Three last flights",
		"K. Big Ladder",
		"L. One flight only",
		"M. Huge Ladder"
	}

	return name, tasks
end

-- Setup task definition. Only if we are still in STATE_IDLE
if sk.state == sk.STATE_IDLE then
	local targetType
	local scoreType
	local RecordBest
	local MaxScore
	
	--  Variables shared between task def. and UI must be added to own list
	sk.p = { }
	sk.p.totalScore = 0
	
	do -- Discard from memory after use
		local taskData = {
			{ 420, -1, 1, false, 300, 2, false }, -- A. Last flight
			{ 420, -1, 2, false, 180, 2, false }, -- B. Two last 3:00
			{ 600, -1, 2, false, 240, 2, false }, -- B. Two last 4:00
			{ 0, 8, 8, true, 180, 2, false }, -- C. AULD
			{ 600, 2, 2, true, 300, 2, true }, -- D. Two flights only
			{ 600, -1, 3, true, 2, 3, true }, -- E. Poker 10 min.
			{ 900, -1, 3, true, 2, 3, true }, -- E. Poker 15 min.
			{ 600, 6, 3, false, 180, 1, false }, -- F. 3 best of 6
			{ 600, -1, 5, false, 120, 1, true }, -- G. 5 x 2:00
			{ 600, -1, 4, false, 3, 1, true }, -- H. 1234
			{ 600, -1, 3, false, 200, 1, true }, -- I. 3 Best
			{ 600, -1, 3, false, 180, 2, false }, -- J. 3 last
			{ 600, 5, 5, true, 4, 2, true },  -- K. Big ladder
			{ 600, 1, 1, true, 599, 2, false },  -- L. One flight only
			{ 900, 3, 3, true, 1, 2, true }  -- M. Huge Ladder
		}
		
		sk.taskWindow = taskData[sk.task][1]
		sk.launches = taskData[sk.task][2] --  -1 for unlimited
		sk.taskScores = taskData[sk.task][3]
		sk.finalScores = taskData[sk.task][4]
		targetType = taskData[sk.task][5] -- 1.Huge ladder, 2.Poker, 3.1234, 4.Big ladder, Else const. time
		scoreType = taskData[sk.task][6] -- 1.Best, 2.Last, 3.Make time
		sk.quickRelaunch = taskData[sk.task][7]
	end

	-- MaxScore() is used for calculating the total score
	if targetType == 1 then -- Huge ladder
		MaxScore = function(iFlight) 
			return 60 + 120 * iFlight
		end
		
	elseif targetType == 2 then -- Poker
		MaxScore = function(iFlight)
			return 9999
		end
		
	elseif targetType == 3 then -- 1234
		MaxScore = function(iFlight) 
			return 300 - 60 * iFlight
		end
		
	elseif targetType == 4 then -- Big ladder
		MaxScore = function(iFlight)
			return 30 + 30 * iFlight
		end
		
	else -- TargetTime = targetType
		MaxScore = function(iFlight) 
			return targetType
		end
	end

	-- UpdateTotal() updates the totalScore
	local function UpdateTotal()
		sk.p.totalScore = 0
		
		for i = 1, #sk.scores do
			sk.p.totalScore = sk.p.totalScore + math.min(MaxScore(i), sk.scores[i])
		end
	end
	
	-- TargetTime is used by JF3Ksk.lua
	if targetType == 2 then -- Poker
		-- Remember these to announce changes
		local lastInput = getValue(sk.dial)
		local lastChange = 0
		
		-- Table with step sizes for input { Lwr time limit, step in sec. }
		local tblStep = {
			{30, 5},
			{60, 10},
			{120, 15},
			{210, 30},
			{420, 60},
			{sk.taskWindow + 60} -- t2 for the last interval
		}
		
		sk.PokerCall = function()
			local input = getValue(sk.dial)
			local i, x = math.modf(1 + (#tblStep - 1) * (math.min(1023, input) + 1024) / 2048)
			local t1 = tblStep[i][1]
			local t2 = tblStep[i + 1][1]
			local dt = tblStep[i][2]
			
			local result = math.min(sk.winTimer - 1, t1 + dt * math.floor(x * (t2 - t1) /dt))
			
			if math.abs(input - lastInput) >= 20 then
				lastInput = input
				lastChange = getTime()
			end
			
			if lastChange > 0 and getTime() - lastChange > 100 then
				playTone(3000, 100, PLAY_NOW)
				playDuration(result)
				lastChange = 0
			end
			
			return result
		end -- PokerCall()

		sk.TargetTime = function()
			if sk.p.pokerCalled then
				return model.getTimer(0).start
			else
				return sk.PokerCall()
			end
		end
		
	elseif targetType == 3 then -- 1234
		-- Find the best target time, given what has already been scored, as well as the remaining time of the window.
		-- Note: maxTarget ensures that recursive calls to this function only test shorter target times. That way, we start with
		-- the longest flight and work down the list. And we do not waste time testing the same target times in different orders.
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

		sk.TargetTime = function() 
			return Best1234Target(sk.winTimer, sk.scores, 4)
		end
		
		-- A few extra counts in 1234
		sk.counts = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 15, 20, 30, 45, 65, 70, 75, 125, 130, 135, 185, 190, 195}

	else -- TargetTime = MaxScore
		sk.TargetTime = function() 
			return MaxScore(#sk.scores + 1)
		end
	end
	
	-- sk.Score() must be defined to record scores
	if scoreType == 1 then -- Best scores
		-- RecordBest() may also be used by Best1234Target()
		RecordBest = function(scores, newScore)
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
			if n < sk.taskScores then n = n + 1 end

			-- Insert the new score and move the following scores down the list
			for i = j, n do
				newScore, scores[i] = scores[i], newScore
			end
		end  --  RecordBest (..)

		sk.Score = function()
			RecordBest(sk.scores, sk.flightTime)
			UpdateTotal()
		end
		
	elseif scoreType == 2 then -- Last scores
		sk.Score = function()
			local n = #sk.scores
			
			if n >= sk.taskScores then
				-- List is full; move other scores one up to make room for the latest at the end
				for j = 1, n - 1 do
					sk.scores[j] = sk.scores[j + 1]
				end
			else
				-- List can grow; add to the end of the list
				n = n + 1
			end
			
			sk.scores[n] = sk.flightTime
			UpdateTotal()
		end

	else -- Must make time to get score
		sk.Score = function()
			local score = sk.flightTime

			-- Did we make time?
			if sk.flightTimer > 0 then
				return
			else
				-- In Poker, only score the call
				if sk.p.pokerCalled then
					score = model.getTimer(0).start
					sk.p.pokerCalled = false
				end
			end
			
			sk.scores[#sk.scores + 1] = score
			UpdateTotal()
		end
	end
	
	if targetType == 2 then -- Poker
		sk.Background = function()
			if sk.state < sk.STATE_FLYING and sk.state ~= sk.STATE_FINISHED and sk.winTimer < sk.TargetTime() then
				playTone(880, 1000, 0)
				sk.state = sk.STATE_FINISHED
			elseif sk.state == sk.STATE_COMMITTED then
				sk.p.pokerCalled = true
			end
		end

	elseif scoreType == 3 then -- Other "must make time" tasks
		sk.Background = function()
			if sk.state < sk.STATE_FLYING and sk.state ~= sk.STATE_FINISHED and sk.winTimer < sk.TargetTime() then
				playTone(880, 1000, 0)
				sk.state = sk.STATE_FINISHED
			end
		end

	end

end -- Setup task definition.

-- Load the user interface
sk.run = "/SCRIPTS/TELEMETRY/JF3K/SK.lua"