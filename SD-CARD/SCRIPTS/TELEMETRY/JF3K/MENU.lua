-- Timing and score keeping, loadable menu for selecting task
-- Timestamp: 2019-10-20
-- Created by Jesper Frickmann

local sk = ...  -- List of variables shared between fixed and loadable parts
local pluginFile = "/SCRIPTS/TELEMETRY/JF3K/SK%i.lua"
local plugins = { } -- List of plugins
plugins[1] = { } -- File
plugins[2] = { } -- Name
plugins[3] = { } -- Task lists

local scanPlugin = 1 -- Index of plugin to scan
local menu = soarUtil.LoadWxH("MENU.lua") -- Screen size specific menu

-- Reset shared variables
sk.scores = { } -- List of saved scores
sk.counts = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 15, 20, 30, 45} -- Flight timer countdown
sk.state = sk.STATE_IDLE

-- Set up a task that does not record scores
sk.p = nil -- Plugin specific variable list
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
			local name, tasks = chunk(sk)
			plugins[1][#plugins[1] + 1] = file
			plugins[2][#plugins[2] + 1] = name
			plugins[3][#plugins[3] + 1] = tasks
		end
		
		scanPlugin = scanPlugin + 1
		return collectgarbage()
	end
	
	if sk.selectedTask == 0 then -- Show plugin menu
		menu.title = "Plugins"
		menu.items = plugins[2]
		menu.Draw(sk.selectedPlugin)
		soarUtil.ShowHelp({ enter = "SELECT", ud = "MOVE" })

		if soarUtil.EvtEnter(event) then
			sk.selectedTask = 1
		elseif soarUtil.EvtUp(event) then
			if sk.selectedPlugin == 1 then
				sk.selectedPlugin = #plugins[1]
			else
				sk.selectedPlugin = sk.selectedPlugin - 1
			end
		elseif soarUtil.EvtDown(event) then
			if sk.selectedPlugin == #plugins[1] then
				sk.selectedPlugin = 1
			else
				sk.selectedPlugin = sk.selectedPlugin + 1
			end
		end
	else -- Show task menu
		menu.title = plugins[2][sk.selectedPlugin]
		menu.items = plugins[3][sk.selectedPlugin]
		menu.Draw(sk.selectedTask)
		soarUtil.ShowHelp({ enter = "SELECT", ud = "MOVE", exit = "GO BACK" })
			
		-- If there is only one task, then start it!
		if #menu.items == 1 then event = EVT_ENTER_BREAK end

		if soarUtil.EvtEnter(event) then
			sk.task = sk.selectedTask
			sk.state = sk.STATE_IDLE
			sk.run = plugins[1][sk.selectedPlugin]
			sk.taskName = plugins[3][sk.selectedPlugin][sk.selectedTask]

			-- If there is only one task, go back to the Plugin menu after returning!
			if #menu.items == 1 then sk.selectedTask = 0 end
		elseif soarUtil.EvtExit(event) then
			sk.selectedTask = 0
			menu.firstItem = 1
		elseif soarUtil.EvtUp(event) then
			if sk.selectedTask == 1 then
				sk.selectedTask = #menu.items
			else
				sk.selectedTask = sk.selectedTask - 1
			end
		elseif soarUtil.EvtDown(event) then
			if sk.selectedTask == #menu.items then
				sk.selectedTask = 1
			else
				sk.selectedTask = sk.selectedTask + 1
			end
		end
	end
end -- run()

return { init = init, run = run }