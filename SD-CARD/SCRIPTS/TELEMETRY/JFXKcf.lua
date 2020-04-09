-- JF FxK Configuration Menu
-- Timestamp: 2020-04-xx
-- Created by Jesper Frickmann
-- Depends on library functions in FUNCTIONS/JFutil.lua

local active = false
local lastRun = 0
local ui = {} -- List of  variables shared with loadable user interface
local selection = 1

-- Menu texts
local texts = {
	"1. Channel configuration",
	"2. Align flaperons",
	"3. Center flaperons",
	"4. Adjust other mixes" }

local menu = soarUtil.LoadWxH("MENU.lua") -- Screen size specific menu
menu.items = texts
menu.title = "Configuration"
	
-- Lua files to be loaded and unloaded
local files = {
	"/SCRIPTS/TELEMETRY/JF/CHANNELS.lua",
	"/SCRIPTS/TELEMETRY/JFXK/ALIGN.lua",
	"/SCRIPTS/TELEMETRY/JFXK/CENTER.lua",
	"/SCRIPTS/TELEMETRY/JFXK/ADJMIX.lua" }

local function background()
	if active then
		-- Do not leave loaded configuration scripts in the background
		if getTime() - lastRun > 100 then
			soarUtil.Unload(files[selection])
			active = false
		end
	else
		model.setGlobalVariable(7, 0, 0)
	end
end -- background()

local function run(event)
	local att
	local x
	
	soarUtil.ToggleHelp(event)

	-- Trap key events
	if soarUtil.EvtEnter(event) then
		active = true
	end

	if active then
		-- Run the active function
		lastRun = getTime()
		if soarUtil.RunLoadable(files[selection], event) then
			soarUtil.Unload(files[selection])
			active = false
		end
	else
		-- Handle menu key events
		if soarUtil.EvtDown(event) then
			selection = selection + 1
			if selection > #texts then 
				selection = 1
			end
		end
		
		if soarUtil.EvtUp(event) then
			selection = selection - 1
			if selection <= 0 then 
				selection = #texts
			end
		end
		
		menu.Draw(selection)
		soarUtil.ShowHelp({ enter = "SELECT", ud = "MOVE" })
	end
end

return {background = background, run = run}