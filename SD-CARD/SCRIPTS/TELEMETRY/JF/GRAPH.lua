-- Timestamp: 2021-01-03
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
		if event == EVT_VIRTUAL_EXIT then
			gr.viewMode = 2
			gr.run = gr.read
		end
		
		soarUtil.ShowHelp({enter = "CHANGE PAR.", lr = "MOVE", exit = "SHOW STATS" })
	elseif gr.viewMode == 2 then -- View stats
		-- Change view mode
		if event == EVT_VIRTUAL_EXIT then
			gr.viewMode = 3
			gr.lftMark = math.floor(0.1 * width)
			gr.rgtMark = math.ceil(0.9 * width)
			gr.selectedMark = 0
		end
		
		soarUtil.ShowHelp({enter = "CHANGE PAR.", lr = "MOVE", exit = "MARK TIME" })
	elseif gr.viewMode == 3 then -- Select details and view slope
		-- Draw markers
		gr.DrawLine(gr.lftTime, gr.yMin, gr.lftTime , gr.yMax)
		gr.DrawLine(gr.rgtTime, gr.yMin, gr.rgtTime , gr.yMax)
		
		-- Move markers
		if event == EVT_VIRTUAL_INC or event == EVT_VIRTUAL_INC_REPT then
			if gr.selectedMark == 0 then
				gr.lftMark = math.min(gr.rgtMark - 1, gr.lftMark + 1)
			else
				gr.rgtMark = math.min(width, gr.rgtMark + 1)
			end
		end
		
		if event == EVT_VIRTUAL_DEC or event == EVT_VIRTUAL_DEC_REPT then
			if gr.selectedMark == 0 then
				gr.lftMark = math.max(0, gr.lftMark - 1)
			else
				gr.rgtMark = math.max(gr.lftMark + 1, gr.rgtMark - 1)
			end
		end
		
		-- Toggle selected marker or zoom in
		if event == EVT_VIRTUAL_ENTER then
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
		if event == EVT_VIRTUAL_EXIT then
			gr.viewMode = 1
			gr.run = gr.read
		end

		if gr.selectedMark == 0 then
			soarUtil.ShowHelp({enter = "RIGHT MARKER", lr = "MOVE", exit = "FULL SIZE" })
		else
			soarUtil.ShowHelp({enter = "ZOOM IN", lr = "MOVE", exit = "FULL SIZE" })
		end
		
	else -- Zoomed in
		if event == EVT_VIRTUAL_ENTER then
			gr.viewMode = 3
			gr.run = gr.read
		end

		soarUtil.ShowHelp({ enter = "ZOOM OUT" })
	end
	
	if gr.viewMode < 3 then
		-- Read next flight
		if event == EVT_VIRTUAL_NEXT or event == EVT_VIRTUAL_NEXT_REPT then
			gr.flightIndex = gr.flightIndex + 1
			if gr.flightIndex > #gr.flightTable then
				gr.flightIndex = 1
			end
			gr.run = gr.read
		end

		-- Read previous flight
		if event == EVT_VIRTUAL_PREV or event == EVT_VIRTUAL_PREV_REPT then
			gr.flightIndex = gr.flightIndex - 1
			if gr.flightIndex < 1 then
				gr.flightIndex = #gr.flightTable
			end
			gr.run = gr.read
		end

		-- Change plot variable
		if event == EVT_VIRTUAL_ENTER then
			gr.plotIndex = gr.plotIndex + 1
			if gr.plotIndex > gr.plotIndexLast then
				gr.plotIndex = 3
			end
			gr.run = gr.read
		end
	end
end -- run()

return { run = run }