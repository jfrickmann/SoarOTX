-- Timing and score keeping, loadable plugin part for altimeter based tasks
-- Timestamp: 2019-01-01
-- Created by Jesper Frickmann

-- If no task is selected, then return name and task list to the menu
if sk.task == 0 then
	local name = "Altimeter"

	local tasks = {
		"V. Height gain",	
		"W. First to +50",
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
	local altMaxId -- Input ID for the max. Alt sensor
	local flightData -- Time and height data for flight to be scored
	local winTimerOld = sk.winTimer
	local lastWarning = 0 -- Last time a warning that height is close to the ceiling was played
	
	--  Variables shared between task def. and UI must be added to own list
	plugin = { }
	plugin.heights = { } -- Time series of recorded heights for graph
	plugin.ceiling = 0 -- Ceiling where timer is stopped
	plugin.launchHeight = 0 -- Launch height is recorded after 10 sec.
	plugin.maxHeight = 0 -- Max. recorded height
	plugin.maxTime = 0 -- Time of max. height
	plugin.flightStart = 0 -- Time of flight start
	plugin.targetGain = 0 -- Target for height gain

	-- Task index constants, shared between task definition and UI
	plugin.TASK_HEIGHT_GAIN = 1
	plugin.TASK_1ST2GAIN50 = 2
	plugin.TASK_CEILING = 3
	plugin.TASK_THROW_LOW = 4
	plugin.TASK_HEIGHT_POKER = 5

	if tx == TX_X9D then
		plugin.heightInt = 4 -- Interval for recording heights
	else -- TX_QX7 or X-lite
		plugin.heightInt = 7
	end
	
	do
		-- Find input IDs if Alt sensor is configured
		local alt = getFieldInfo("Alti")
		if alt then
			plugin.altId = alt.id
			altMaxId = getFieldInfo("Alti+").id
		else	
			alt = getFieldInfo("Alt")
			if alt then
				plugin.altId = alt.id
				altMaxId = getFieldInfo("Alt+").id
			end
		end

		local taskData = {
			{ 3, false, 1, 0, 1 }, -- Height gain
			{ 1, false, 1, 0, 2 }, -- First to gain 50
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
			plugin.targetGain = 50
			
			if plugin.launchHeight == 0 then
				return 0
			else
				return plugin.launchHeight + plugin.targetGain
			end
		end
	elseif ceilingType == 2 then -- Set ceiling with knob
		Ceiling = function()
			if sk.state == sk.STATE_IDLE then
				return 50 + 5 * math.floor(0.99 + getValue(sk.set1id) / 204.8)
			else
				return plugin.ceiling
			end

		end
	elseif ceilingType == 3 then -- No ceiling
		Ceiling = function() 
			return 0 
		end
	else -- Set ceiling to launch + adjustable
		Ceiling = function()
			if not plugin.pokerCalled then
				plugin.targetGain = 25 + math.floor(0.99 + getValue(sk.set1id) / 41)
			end
			 
			if plugin.launchHeight == 0 then
				return 0
			else
				return plugin.launchHeight + plugin.targetGain
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
			if flightData.maxHeight >= plugin.ceiling and plugin.ceiling > 0 then
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
			if flightData.gain >= plugin.targetGain then
				flightData.gain = plugin.targetGain
				sk.scores[#sk.scores + 1] = flightData
				plugin.pokerCalled = false
			end
		end -- RecordScore()
		
	end

	sk.Score = function(zero)
		-- Record scores
		local flightData = {
			time = sk.flightTime,
			start = plugin.flightStart,
			launch = plugin.launchHeight,
			maxHeight = plugin.maxHeight,
			maxTime = plugin.maxTime,
			gain = plugin.maxHeight - plugin.launchHeight
		}
		
		if zero or plugin.launchHeight == 0 then
			flightData.time = 0
			flightData.gain = 0
		end

		RecordScore(flightData)
	end -- sk.Score()
	
	sk.Background = function()
		plugin.ceiling = Ceiling()
	
		if sk.state >= sk.STATE_WINDOW then
			-- Save height timeseries
			if sk.winTimer >=0 and sk.winTimer <= model.getTimer(1).start and 
			math.floor(sk.winTimer / plugin.heightInt) ~= math.floor(winTimerOld / plugin.heightInt) then
				plugin.heights[#plugin.heights + 1] = getValue(plugin.altId)			
			end

			if sk.state == sk.STATE_READY then
				plugin.launchHeight = 0
				plugin.maxHeight = 0
				plugin.maxTime = 0
				plugin.flightStart = 0
			end
			
			if sk.state >= sk.STATE_FLYING then
				if plugin.flightStart == 0 then
					plugin.flightStart = math.abs(model.getTimer(1).start - sk.winTimer)
				end
				
				if sk.state < sk.STATE_FREEZE then
					-- Update launch and max. height
					local mh = getValue(altMaxId)
					local now = getTime()
					
					if plugin.launchHeight == 0 and sk.flightTime > 10 then
						plugin.launchHeight = mh
					end
					
					if mh > plugin.maxHeight then
						plugin.maxHeight = mh
						plugin.maxTime = sk.flightTime + plugin.flightStart
					end
					
					mh = getValue(plugin.altId)
					if plugin.ceiling > 0 and mh >= plugin.ceiling - 3 and lastWarning < now then
						playNumber(mh, 9)
						lastWarning = now + 300
					end

					-- If height ceiling is broken, then freeze the flight timer
					if plugin.ceiling > 0 and plugin.maxHeight > plugin.ceiling then
						sk.state = sk.STATE_FREEZE
						playTone(1760, 750, PLAY_NOW)
					end
				end
				
				if sk.state == sk.STATE_COMMITTED then
					-- Call Poker
					if sk.task == plugin.TASK_HEIGHT_POKER then 
						plugin.pokerCalled = true
					end				
				end
			end
		end

		winTimerOld = sk.winTimer
	end -- sk.Background()
end  -- Setup task definition.

-- Load the user interface
sk.run = "/SCRIPTS/TELEMETRY/JF3K/SKalti.lua"