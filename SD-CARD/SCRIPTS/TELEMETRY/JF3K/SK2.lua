-- Timing and score keeping, loadable plugin for practice tasks
-- Timestamp: 2019-09-20
-- Created by Jesper Frickmann

local sk = ...  -- List of variables shared between fixed and loadable parts
local TASK_DEUCES = 3

-- If no task is selected, then return name and task list to the menu
if sk.task == 0 then
	local name = "Practice"

	local tasks = {
		"Just Fly!",
		"Quick Relaunch!",
		"Deuces"
	}

	return name, tasks
end

-- Setup task definition. Only if we are still in STATE_IDLE
if sk.state == sk.STATE_IDLE then
	local targetType
	
	--  Variables shared between task def. and UI must be added to own list
	sk.p = { }
	sk.p.totalScore = 0

	do -- Discard from memory after use
		local taskData = {
			{ 0, -1, 8, false, 0, false }, -- Just fly
			{ 0, -1, 8, false, 1, true }, -- QR
			{ 600, 2, 2, true, 2, false } -- Deuces
		}
		
		sk.taskWindow = taskData[sk.task][1]
		sk.launches = taskData[sk.task][2]
		sk.taskScores = taskData[sk.task][3]
		sk.finalScores = taskData[sk.task][4]
		targetType = taskData[sk.task][5]
		sk.quickRelaunch = taskData[sk.task][6]
	end

	if targetType == 1 then -- Adjustable
		sk.TargetTime = function()
			local t1, t2, dt, tOut
			local tIn = getValue(sk.dial)
			
			if tIn <= -512 then
				t1 = 0
				t2 = 60
				dt = 5
				tIn = tIn + 1024
			elseif tIn <= 0 then
				t1 = 60
				t2 = 180
				dt = 10
				tIn = tIn + 512
			elseif tIn <= 512 then
				t1 = 180
				t2 = 360
				dt = 15
			else
				t1 = 360
				t2 = 900
				dt = 30
				tIn = tIn - 512
			end
			
			tOut = t1 + dt * math.floor((t2 - t1) / 512 * tIn / dt)
			
			return math.max(5, tOut)
		end
		
	elseif targetType == 2 then -- Deuces
		sk.TargetTime = function()
			if #sk.scores == 0 then
				return math.max(0, math.floor(sk.winTimer / 2))
			elseif #sk.scores == 1 then
				return math.max(0, math.min(sk.winTimer, sk.scores[1]))
			else
				return 0
			end
		end
		
	else -- TargetTime = targetType
		sk.TargetTime = function() 
			return targetType
		end
	end
	
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
		
		sk.p.totalScore = 0
		
		if sk.task == TASK_DEUCES then
			if #sk.scores < 2 then
				sk.p.totalScore = 0
			else
				sk.p.totalScore = math.min(sk.scores[1], sk.scores[2])
			end
		else
			for i = 1, #sk.scores do
				sk.p.totalScore = sk.p.totalScore + sk.scores[i]
			end
		end
	end

end -- Setup task definition.

-- Load the user interface
sk.run = "/SCRIPTS/TELEMETRY/JF3K/SK.lua"