-- Timing and score keeping, loadable plugin for F3K tasks
-- Timestamp: 2018-12-27
-- Created by Jesper Frickmann

-- If no task is selected, then return name and task list to the menu
if sk.task == 0 then
	local name = "F3K"

	local tasks = {
		"A. Last flight",
		"B. Two last flights 3:00",
		"B. Two last flights 4:00",
		"C. All up last down",
		"D. Ladder",
		"E. Poker",
		"F. Three best out of six",
		"G. Five best flights",
		"H. 1-2-3-4 in any order",
		"I. Three best flights",
		"J. Three last flights",
		"K. Big Ladder"
	}

	return name, tasks
end

-- Setup task definition. Only if we are still in STATE_IDLE
if sk.state == sk.STATE_IDLE then
	local targetType
	local scoreType
	local RecordBest
	
	--  Variables shared between task def. and UI must be added to own list
	plugin = { }

	do -- Discard from memory after use
		local taskData = {
			{ 420, -1, 1, false, 300, 2, false }, -- A. Last flight
			{ 420, -1, 2, false, 180, 2, false }, -- B. Two last 3:00
			{ 600, -1, 2, false, 240, 2, false }, -- B. Two last 4:00
			{ 0, 7, 7, true, 180, 2, false }, -- C. AULD
			{ 600, -1, 7, true, 1, 3, false }, -- D. Ladder
			{ 600, -1, 5, true, 2, 3, true }, -- E. Poker
			{ 600, 6, 3, false, 180, 1, false }, -- F. 3 best of 6
			{ 600, -1, 5, false, 120, 1, true }, -- G. 5 x 2:00
			{ 600, -1, 4, false, 3, 1, true }, -- H. 1234
			{ 600, -1, 3, false, 200, 1, true }, -- I. 3 Best
			{ 600, -1, 3, false, 180, 2, false }, -- J. 3 last
			{ 600, 5, 5, true, 4, 2, true }  -- K. Big ladder
		}
		
		sk.taskWindow = taskData[sk.task][1]
		sk.launches = taskData[sk.task][2]
		sk.taskScores = taskData[sk.task][3]
		sk.finalScores = taskData[sk.task][4]
		targetType = taskData[sk.task][5]
		scoreType = taskData[sk.task][6]
		sk.quickRelaunch = taskData[sk.task][7]
	end

	if targetType == 1 then -- Ladder
		sk.TargetTime = function() 
			return 30 + 15 * #sk.scores
		end
		
	elseif targetType == 2 then -- Poker
		sk.TargetTime = function()
			if plugin.pokerCalled then
				return model.getTimer(0).start
			else
				local m = math.floor((1024 + getValue(sk.set1id)) / 205)
				local s = math.floor((1024 + getValue(sk.set2id)) / 34.2)

				return math.max(5, math.min(sk.winTimer - 1, 60 * m + s))
			end
		end
		
		sk.Background = function()
			if sk.state == sk.STATE_COMMITTED then
				plugin.pokerCalled = true
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
		
	elseif targetType == 4 then -- Big ladder
		sk.TargetTime = function() 
			return 60 + 30 * #sk.scores
		end
		
	else -- TargetTime = targetType
		sk.TargetTime = function() 
			return targetType
		end
	end
	
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
		end

	else -- Must make time to get score
		sk.Score = function()
			local score = sk.flightTime

			-- Did we make time?
			if sk.flightTimer > 0 then
				return
			else
				-- In Poker, only score the call
				if plugin.pokerCalled then
					score = model.getTimer(0).start
					plugin.pokerCalled = false
				end
			end
			
			sk.scores[#sk.scores + 1] = score
		end
	end

end -- Setup task definition.

-- Load the user interface
sk.run = "/SCRIPTS/TELEMETRY/JF3K/SK.lua"