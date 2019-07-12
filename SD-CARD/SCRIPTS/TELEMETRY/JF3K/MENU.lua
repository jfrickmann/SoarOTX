-- Timing and score keeping, loadable menu for selecting task
-- Timestamp: 2019-07-07
-- Created by Jesper Frickmann

local pluginFile = "/SCRIPTS/TELEMETRY/JF3K/SK%i.lua"
local plugins = { } -- List of plugins
local scanPlugin = 1 -- Index of plugin to scan

-- Reset shared variables
sk.scores = { } -- List of saved scores
sk.counts = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 15, 20, 30, 45, 60, 120, 180, 240} -- Flight timer countdown
sk.state = sk.STATE_IDLE

-- Set up a task that does not record scores
plugin = nil
sk.task = 0
sk.taskWindow = 0
sk.launches = -1
sk.taskScores = 0
sk.finalScores = false

sk.PokerCall = function() return 0 end
sk.TargetTime = function() return 0 end
sk.Score = function() return end
sk.Background = nil

local function run(event)
	-- Scan for plugins and build lists
	if scanPlugin < 10 then
		-- Load the program
		local file = string.format(pluginFile, scanPlugin)
		local chunk = loadScript(file)

		if chunk then
			local name, tasks = chunk()
			plugins[#plugins + 1] = { file, name, tasks }
		end
		
		scanPlugin = scanPlugin + 1		
		return collectgarbage()
	end

	if sk.selectedTask == 0 then -- Show plugin menu
		DrawMenu("Plugins")
		lcd.drawPixmap(156, 8, "/IMAGES/Lua-girl.bmp")

		for line = 1, math.min(6, #plugins - sk.firstPlugin + 1) do
			local plugin = line + sk.firstPlugin - 1
			local y0 = 1 + 9 * line
			local att = 0
			
			if plugin == sk.selectedPlugin then att = INVERS end
			lcd.drawText(0, y0, string.format("%i. %s", plugin, plugins[plugin][2]), att)
		end

		if event == EVT_ENTER_BREAK then
			sk.firstTask = 1
			sk.selectedTask = 1
		elseif event == EVT_PLUS_BREAK or event == EVT_ROT_LEFT or event == EVT_PLUS_REPT or event == EVT_UP_BREAK then
			if sk.selectedPlugin == 1 then
				sk.selectedPlugin = #plugins
			else
				sk.selectedPlugin = sk.selectedPlugin - 1
			end
		elseif event == EVT_MINUS_BREAK or event == EVT_ROT_RIGHT or event == EVT_MINUS_REPT or event == EVT_DOWN_BREAK then
			if sk.selectedPlugin == #plugins then
				sk.selectedPlugin = 1
			else
				sk.selectedPlugin = sk.selectedPlugin + 1
			end
		end

		-- Scroll if necessary
		if sk.selectedPlugin < sk.firstPlugin then
			sk.firstPlugin = sk.selectedPlugin
		elseif sk.selectedPlugin - sk.firstPlugin > 5 then
			sk.firstPlugin = sk.selectedPlugin - 5
		end

	else -- Show task menu
		local name = plugins[sk.selectedPlugin][2]
		local tasks = plugins[sk.selectedPlugin][3]

		-- If there is only one task, then start it!
		if #tasks == 1 then event = EVT_ENTER_BREAK end

		DrawMenu(name)
		lcd.drawPixmap(156, 8, "/IMAGES/Lua-girl.bmp")
		
		for line = 1, math.min(6, #tasks - sk.firstTask + 1) do
			local task = line + sk.firstTask - 1
			local y0 = 1 + 9 * line
			local att = 0
			
			if task == sk.selectedTask then att = INVERS end
			lcd.drawText(0, y0, tasks[task], att)
		end

		if event == EVT_ENTER_BREAK then
			sk.task = sk.selectedTask
			sk.state = sk.STATE_IDLE
			sk.run = plugins[sk.selectedPlugin][1]
			sk.taskName = plugins[sk.selectedPlugin][3][sk.selectedTask]

			-- If there is only one task, go back to the Plugin menu after returning!
			if #tasks == 1 then sk.selectedTask = 0 end
		elseif event == EVT_EXIT_BREAK then
			sk.selectedTask = 0
		elseif event == EVT_PLUS_BREAK or event == EVT_ROT_LEFT or event == EVT_PLUS_REPT or event == EVT_UP_BREAK then
			if sk.selectedTask == 1 then
				sk.selectedTask = #tasks
			else
				sk.selectedTask = sk.selectedTask - 1
			end
		elseif event == EVT_MINUS_BREAK or event == EVT_ROT_RIGHT or event == EVT_MINUS_REPT or event == EVT_DOWN_BREAK then
			if sk.selectedTask == #tasks then
				sk.selectedTask = 1
			else
				sk.selectedTask = sk.selectedTask + 1
			end
		end

		-- Scroll if necessary
		if sk.selectedTask < sk.firstTask then
			sk.firstTask = sk.selectedTask
		elseif sk.selectedTask - sk.firstTask > 5 then
			sk.firstTask = sk.selectedTask - 5
		end
	
	end
end -- run()

return { run = run }