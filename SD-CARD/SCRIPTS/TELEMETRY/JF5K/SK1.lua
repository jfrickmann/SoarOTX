-- Timing and score keeping, loadable plugin for 2020 F5K tasks
-- Timestamp: 2020-05-13
-- Created by Jesper Frickmann

local sk = ...  -- List of variables shared between fixed and loadable parts

-- If no task is selected, then return name and task list to the menu
if sk.task == 0 then
	local name = "F5K"

	local tasks = {
		"A. 1-2-3-4 in any order",
		"B. Last flight",
		"C. All up last down",
		"D. 3-3-4 in any order",
		"E. Poker 10 min."
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
			{ 600, -1, 4, false, 2, 1 }, -- A. 1234
			{ 420, -1, 1, false, 300, 2 }, -- B. Last flight
			{ 0, 7, 7, true, 240, 2 }, -- C. AULD
			{ 600, -1, 3, false, 3, 1 }, -- D. 334
			{ 600, -1, 3, true, 1, 3 } -- E. Poker 10 min.
		}
		
		sk.taskWindow = taskData[sk.task][1]
		sk.launches = taskData[sk.task][2] --  -1 for unlimited
		sk.taskScores = taskData[sk.task][3]
		sk.finalScores = taskData[sk.task][4]
		targetType = taskData[sk.task][5] -- 1.Poker, 2.1234, 3.334, Else const. time
		scoreType = taskData[sk.task][6] -- 1.Best, 2.Last, 3.Make time
	end

	-- MaxScore() is used for calculating the total score
	if targetType == 1 then -- Poker
		MaxScore = function(iFlight)
			return 9999
		end
		
	elseif targetType == 2 then -- 1234
		MaxScore = function(iFlight) 
			return 300 - 60 * iFlight
		end
		
	elseif targetType == 3 then -- 334
		MaxScore = function(iFlight)
			if iFlight == 1 then
				return 240
			else
				return 180
			end
		end
		
	else -- TargetTime = targetType
		MaxScore = function(iFlight) 
			return targetType
		end
	end

	-- UpdateTotal() updates the totalScore
	function sk.p.UpdateTotal()
		sk.p.totalScore = 0
		
		for i, score in ipairs(sk.scores) do
			local secs = math.min(MaxScore(i), score[1])
			local bonus = sk.GetStartHeight() - score[2]
			
			if math.abs(bonus) > 6 then
				bonus = 2 * bonus
			elseif math.abs(bonus) <= 2 then
				bonus = 0
			end
			
			sk.p.totalScore = math.max(0, sk.p.totalScore + secs + bonus)
		end
	end
	
	-- TargetTime is used by JF5Ksk.lua
	if targetType == 1 then -- Poker
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
		
	elseif targetType == 2 or targetType == 3 then -- 1234 or 334
		-- Find the best target time, given what has already been scored, as well as the remaining time of the window.
		-- Note: remaining ensures that recursive calls to this function only test shorter target times. That way, we start with
		-- the longest flight and work down the list. And we do not waste time testing the same target times in different orders.
		
		local targets = {}
		
		if targetType == 2 then
			targets = {60, 120, 180, 240}
		else
			targets = {180, 180, 240}
		end
		
		local function BestTarget(timeLeft, scores, remaining)
			local bestTotal = 0
			local bestTarget = 0

			-- Max target index to test
			local maxi = math.min(remaining, #targets)
			while maxi > 1 and targets[maxi] > 60 * math.ceil(timeLeft / 60) do
				maxi = maxi - 1
			end
			
			-- Iterate to find the best target time
			for i = 1, maxi do
				local tl
				local tot
				local dummy

				-- Copy scores to a new table
				local s = {}
				for j = 1, #scores do
					s[j] = scores[j]
				end

				-- Add new target time to s; only until the end of the window
				RecordBest(s, { math.min(timeLeft, targets[i]) })
				tl = timeLeft - targets[i]

				-- Add up total score, assuming that the new target time was made
				if tl <= 0 or i == 1 then
					-- No more flights are made; sum it all up
					tot = 0
					for j = 1, math.min(#targets, #s) do
						tot = tot + math.min(targets[1 + #targets - j], s[j][1])
					end
				else
					-- More flights can be made; add more flights recursively
					-- Subtract one second from tl for turnaround time
					dummy, tot = BestTarget(tl - 1, s, i - 1)
				end

				-- Do we have a new winner?
				if tot > bestTotal then
					bestTotal = tot
					bestTarget = targets[i]
				end
			end

			return bestTarget, bestTotal
		end  --  BestTarget()

		sk.TargetTime = function()
			return BestTarget(sk.winTimer, sk.scores, #targets)
		end
		
	else -- TargetTime = MaxScore
		sk.TargetTime = function() 
			return MaxScore(#sk.scores + 1)
		end
	end
	
	-- sk.Score() must be defined to record scores
	if scoreType == 1 then -- Best scores
		-- RecordBest() may also be used by BestTarget()
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
					if newScore[1] > scores[i][1] then j = i end
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
			RecordBest(sk.scores, {sk.flightTime, sk.startHeight})
			sk.p.UpdateTotal()
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
			
			sk.scores[n] = {sk.flightTime, sk.startHeight}
			sk.p.UpdateTotal()
		end

	else -- Must make time to get score
		sk.Score = function()
			local score = {sk.flightTime, sk.startHeight}

			-- Did we make time?
			if sk.flightTimer > 0 then
				return
			else
				-- In Poker, only score the call
				if sk.p.pokerCalled then
					score = {model.getTimer(0).start, sk.startHeight}
					sk.p.pokerCalled = false
				end
			end
			
			sk.scores[#sk.scores + 1] = score
			sk.p.UpdateTotal()
		end
	end
	
	if targetType == 1 then -- Poker
		sk.Background = function()
			if sk.state < sk.STATE_FLYING and sk.state ~= sk.STATE_FINISHED and sk.winTimer < sk.TargetTime() then
				playTone(880, 1000, 0)
				sk.state = sk.STATE_FINISHED
			elseif sk.state == sk.STATE_FLYING then
				sk.p.pokerCalled = true
			end
		end
	end

end -- Setup task definition.

-- Load the user interface
sk.run = "/SCRIPTS/TELEMETRY/JF5K/SK.lua"