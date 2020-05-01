-- Timing and score keeping, loadable plugin part for altimeter based tasks
-- Timestamp: 2020-04-27
-- Created by Jesper Frickmann

local sk = ...  -- List of variables shared between fixed and loadable parts

-- If no task is selected, then return name and task list to the menu
if sk.task == 0 then
	local name = "Altimeter"

	local tasks = {
		"W. Height gain",	
		"X. Under ceiling",
		"Y. Throw low 2:00",
		"Z. Height Poker"
	}

	return name, tasks
end

-- Setup task definition. Only if we are still in STATE_IDLE
if sk.state == sk.STATE_IDLE then
	local Ceiling -- Function returning height ceiling
	local RecordScore -- Function for recording scores
	
	local ceilingType -- Type of Ceiling function
	local targetTime -- Target time
	local scoreType -- Type of function recording score
	local flightData -- Time and height data for flight to be scored
	local winTimerOld = sk.winTimer
	local lastWarning = 0 -- Last time a warning that height is close to the ceiling was played
	
	--  Variables shared between task def. and UI must be added to own list
	sk.p = { }
	sk.p.yValues = { } -- Time series of recorded heights for graph
	sk.p.maxHeight = 0 -- Maximum recorded altitude during current flight
	sk.p.plotMax = 0 -- Maximum recorded altitude during window for plot
	sk.p.ceiling = 0 -- Ceiling where timer is stopped
	sk.p.launchHeight = 0 -- Launch height is recorded after 10 sec.
	sk.p.maxHeight = 0 -- Max. recorded height
	sk.p.maxTime = 0 -- Time of max. height
	sk.p.flightStart = 0 -- Time of flight start
	sk.p.targetGain = 0 -- Target for height gain

	-- Task index constants, shared between task definition and UI
	sk.p.TASK_HEIGHT_GAIN = 1
	sk.p.TASK_CEILING = 2
	sk.p.TASK_THROW_LOW = 3
	sk.p.TASK_HEIGHT_POKER = 4

	-- Unit of scores
	if sk.task == sk.p.TASK_CEILING then
		sk.p.unit = "s"
	elseif sk.task == sk.p.TASK_THROW_LOW then
		sk.p.unit = "p"
	else
		sk.p.unit = "m"
	end
	
	do
		local taskData = {
			{ 3, false, 1, 0, 1 }, -- Height gain
			{ 1, false, 2, 300, 3 }, -- Under ceiling
			{ 3, false, 3, 120, 4 }, -- Throw low 2:00
			{ 3, true,  4, 0, 5 } -- Height poker
		}
		
		sk.taskWindow = 420
		sk.taskScores = taskData[sk.task][1]
		sk.finalScores = taskData[sk.task][2]

		ceilingType = taskData[sk.task][3]
		targetTime = taskData[sk.task][4]
		scoreType = taskData[sk.task][5]

	end

	-- Ceiling function
	if ceilingType == 1 then -- Set ceiling to launch + 50
		Ceiling = function()
			sk.p.targetGain = 50
			
			if sk.p.launchHeight == 0 then
				return 0
			else
				return sk.p.launchHeight + sk.p.targetGain
			end
		end
	elseif ceilingType == 2 then -- Set ceiling with knob
		Ceiling = function()
			if sk.state == sk.STATE_IDLE then
				return 50 + 5 * math.floor(0.99 + getValue(sk.dial) / 204.8)
			else
				return sk.p.ceiling
			end

		end
	elseif ceilingType == 3 then -- No ceiling
		Ceiling = function() 
			return 0 
		end
	else -- Set ceiling to launch + adjustable
		Ceiling = function()
			if not sk.p.pokerCalled then
				sk.p.targetGain = 25 + math.floor(0.99 + getValue(sk.dial) / 41)
			end
			 
			if sk.p.launchHeight == 0 then
				return 0
			else
				return sk.p.launchHeight + sk.p.targetGain
			end
		end
	end

	-- TargetTime function
	sk.TargetTime = function()
		return targetTime
	end
	
	-- Score function
	if scoreType == 1 then -- Best height gains
		RecordScore = function(flightData)
			local n = #sk.scores
			local i = 1
			local j = 0

			-- Find the position where the new score is going to be inserted
			if n == 0 then
				j = 1
			else
				-- Find the first position where existing score is smaller than the new score
				while i <= n and j == 0 do
					if flightData.gain > sk.scores[i].gain then j = i end
					i = i + 1
				end
				
				if j == 0 then j = i end -- New score is smallest; end of the list
			end

			-- If the list is not yet full; let it grow
			if n < sk.taskScores then n = n + 1 end

			-- Insert the new score and move the following scores down the list
			for i = j, n do
				flightData, sk.scores[i] = sk.scores[i], flightData
			end
		end -- RecordScore()
		
	elseif scoreType == 2 then -- 1st to gain 50
		RecordScore = function(flightData)
			-- Record flight if gain improved over previous
			if #sk.scores == 0 or flightData.gain > sk.scores[1].gain then
				sk.scores[1] = flightData
			end
			
			-- If we made it to the target, then the task is finished
			if flightData.maxHeight >= sk.p.ceiling and sk.p.ceiling > 0 then
				sk.finalScores = true
			end
		end -- RecordScore()
		
	elseif scoreType == 3 then -- Ceiling; record last flight
		RecordScore = function(flightData)
			sk.scores[1] = flightData
		end -- RecordScore()
		
	elseif scoreType == 4 then -- Throw Low
		RecordScore = function(flightData)
			-- Did we get a launch height and make the time?
			if flightData.launch > 0 and flightData.time >= targetTime then
				-- Score is 100 - launch height
				flightData.gain = 100 - flightData.launch
				sk.scores[#sk.scores + 1] = flightData
			end
		end -- RecordScore()

	else -- Height Poker
		RecordScore = function(flightData)
			-- Did make the call?
			if flightData.gain >= sk.p.targetGain then
				flightData.gain = sk.p.targetGain
				sk.scores[#sk.scores + 1] = flightData
				sk.p.pokerCalled = false
			end
		end -- RecordScore()
		
	end

	sk.Score = function(zero)
		-- Record scores
		local flightData = {
			time = sk.flightTime,
			start = sk.p.flightStart,
			launch = sk.p.launchHeight,
			maxHeight = sk.p.maxHeight,
			maxTime = sk.p.maxTime,
			gain = math.min(sk.p.targetGain, sk.p.maxHeight - sk.p.launchHeight)
		}
		
		if zero or sk.p.launchHeight == 0 then
			flightData.time = 0
			flightData.gain = 0
		end

		RecordScore(flightData)
	end -- sk.Score()
	
	sk.Background = function()
		sk.p.ceiling = Ceiling()
	
		if sk.state >= sk.STATE_WINDOW then
			-- Save height timeseries
			if sk.winTimer >=0 and sk.winTimer <= model.getTimer(1).start and 
			math.floor(sk.winTimer / sk.p.heightInt) ~= math.floor(winTimerOld / sk.p.heightInt) then
				local h = soarUtil.alt
				sk.p.yValues[#sk.p.yValues + 1] = h
				if h > sk.p.plotMax then
					sk.p.plotMax = h
				end
			end

			if sk.state <= sk.STATE_READY and sk.task == sk.p.TASK_THROW_LOW and sk.winTimer < sk.TargetTime() then
				playTone(880, 1000, 0)
				sk.state = sk.STATE_FINISHED
			end
			
			if sk.state == sk.STATE_READY then
				sk.p.launchHeight = 0
				sk.p.maxHeight = 0
				sk.p.maxTime = 0
				sk.p.flightStart = 0
			end
			
			if sk.state >= sk.STATE_FLYING then
				if sk.p.flightStart == 0 then
					sk.p.flightStart = math.abs(model.getTimer(1).start - sk.winTimer)
				end
				
				if sk.state < sk.STATE_FREEZE then
					-- Update launch and max. height
					local mh = math.floor(soarUtil.altMax)
					local now = getTime()
					
					if sk.p.launchHeight == 0 and sk.flightTime > 10 then
						sk.p.launchHeight = mh
					end
					
					if mh > sk.p.maxHeight then
						sk.p.maxHeight = mh
						sk.p.maxTime = sk.flightTime + sk.p.flightStart
					end
					
					mh = soarUtil.alt
					if sk.p.ceiling > 0 and mh >= sk.p.ceiling - 3 and lastWarning < now then
						playNumber(mh, 9)
						lastWarning = now + 300
					end

					-- If height ceiling is broken, then freeze the flight timer
					if sk.p.ceiling > 0 and sk.p.maxHeight > sk.p.ceiling then
						sk.state = sk.STATE_FREEZE
						playTone(1760, 750, PLAY_NOW)
					end
				end
				
				if sk.state == sk.STATE_COMMITTED then
					-- Call Poker
					if sk.task == sk.p.TASK_HEIGHT_POKER then 
						sk.p.pokerCalled = true
					end				
				end
			end
		end

		winTimerOld = sk.winTimer
	end -- sk.Background()
end  -- Setup task definition.

-- Load the user interface
sk.run = "/SCRIPTS/TELEMETRY/JF3K/SKalti.lua"