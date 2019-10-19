-- Timestamp: 2019-10-18
-- Created by Jesper Frickmann
-- Telemetry script for plotting telemetry parameters recorded in the log file.

local gr = ... -- List of shared variables
local Draw = soarUtil.LoadWxH("JF/GRAPH.lua", gr) -- Screen size specific function

-- First time, set some shared variables and hand over to read
if not gr.yValues then
	gr.run = gr.read
	return true
end

local function run(event)
	local width = gr.right - gr.left
	gr.yMin2 = gr.yMin -- For reporting actual min and max values
	gr.yMax2=gr.yMax
	gr.tSpan = gr.tMax - gr.tMin

	-- Sometimes, a min. scale of zero looks better...
	if gr.yMin < 0 then
		if -gr.yMin < 0.08 * gr.yMax then
			gr.yMin = 0
		end
	else
		if gr.yMin < 0.5 *  gr.yMax then
			gr.yMin = 0
		end
	end
	
	-- Make sure that we have some range to work with...
	if gr.yMax - gr.yMin <= 1E-8 then
		gr.yMax = gr.yMax + 0.1
	end
	
	-- Share some variables with the screen size specific parts
	if gr.viewMode == 3 then
		gr.lftTime = gr.tMin + gr.lftMark * gr.tSpan / width
		gr.rgtTime = gr.tMin + gr.rgtMark * gr.tSpan / width
	end
	
	Draw(event)
	
	if gr.viewMode == 1 then -- Normal graph view
		-- Change view mode
		if soarUtil.EvtExit(event) then
			gr.viewMode = 2
			gr.run = gr.read
		end
	elseif gr.viewMode == 2 then -- View stats
		-- Change view mode
		if soarUtil.EvtExit(event) then
			gr.viewMode = 3
			gr.lftMark = math.floor(0.1 * width)
			gr.rgtMark = math.ceil(0.9 * width)
			gr.selectedMark = 0
		end

	elseif gr.viewMode == 3 then -- Select details and view slope
		-- Draw markers
		gr.DrawLine(gr.lftTime, gr.yMin, gr.lftTime , gr.yMax)
		gr.DrawLine(gr.rgtTime, gr.yMin, gr.rgtTime , gr.yMax)
		
		-- Move markers
		if soarUtil.EvtRight(event) then
			if gr.selectedMark == 0 then
				gr.lftMark = math.min(gr.rgtMark - 1, gr.lftMark + 1)
			else
				gr.rgtMark = math.min(width, gr.rgtMark + 1)
			end
		end
		
		if soarUtil.EvtLeft(event) then
			if gr.selectedMark == 0 then
				gr.lftMark = math.max(0, gr.lftMark - 1)
			else
				gr.rgtMark = math.max(gr.lftMark + 1, gr.rgtMark - 1)
			end
		end
		
		-- Toggle selected marker or zoom in
		if soarUtil.EvtEnter(event) then
			if gr.selectedMark == 0 then
				gr.selectedMark = 1
			else
				gr.viewMode = 4
				gr.tMin = gr.lftTime
				gr.tMax = gr.rgtTime
				gr.selectedMark = 0
				gr.run = gr.read
			end
		end
		
		-- Back to full graph view
		if soarUtil.EvtExit(event) then
			gr.viewMode = 1
			gr.run = gr.read
		end
	else -- Zoomed in
		if soarUtil.EvtExit(event) then
			gr.viewMode = 3
			gr.run = gr.read
		end
	end
	
	if gr.viewMode < 3 then
		-- Read next flight
		if soarUtil.EvtRight(event) then
			gr.flightIndex = gr.flightIndex + 1
			if gr.flightIndex > #gr.flightTable then
				gr.flightIndex = 1
			end
			gr.run = gr.read
		end

		-- Read previous flight
		if soarUtil.EvtLeft(event) then
			gr.flightIndex = gr.flightIndex - 1
			if gr.flightIndex < 1 then
				gr.flightIndex = #gr.flightTable
			end
			gr.run = gr.read
		end

		-- Change plot variable
		if soarUtil.EvtEnter(event) then
			gr.plotIndex = gr.plotIndex + 1
			if gr.plotIndex > gr.plotIndexLast then
				gr.plotIndex = 3
			end
			gr.run = gr.read
		end
	end
end -- run()

return { run = run }