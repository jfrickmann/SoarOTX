-- JF FXJ Configuration Menu
-- Timestamp: 2019-09-15
-- Created by Jesper Frickmann
-- Depends on library functions in FUNCTIONS/JFLib.lua
-- "adj" is a global var that is output to OpenTX with a custom script

local active = false
local lastRun = 0
local ui = {} -- List of  variables shared with loadable user interface
local selection = 1
local menu -- Screen size specific menu

-- Menu texts
local texts = {
	"1. Channel configuration",
	"2. Align flaps & ailerons",
	"3. Adjust airbrake curves",
	"4. Aileron and camber",
	"5. Adjust other mixes" }

-- Lua files to be loaded and unloaded
local files = {
	"/SCRIPTS/TELEMETRY/JF/CHANNELS.lua",
	"/SCRIPTS/TELEMETRY/JFXJ/ALIGN.lua",
	"/SCRIPTS/TELEMETRY/JFXJ/BRKCRV.lua",
	"/SCRIPTS/TELEMETRY/JFXJ/AILCMB.lua",
	"/SCRIPTS/TELEMETRY/JFXJ/ADJMIX.lua" }

local function init()
	menu = LoadWxH("MENU.lua")
	menu.items = texts
	menu.title = "Configuration"
end -- init

local function background()
	if active then
		-- Do not leave loaded configuration scripts in the background
		if getTime() - lastRun > 100 then
			Unload(files[selection])
			active = false
		end
	else
		adj = 0
	end
end -- background()

local function run(event)
	local att
	local x
	
	-- Trap key events
	if event == EVT_ENTER_BREAK then
		active = true
	end

	if active then
		-- Run the active function
		lastRun = getTime()
		if RunLoadable(files[selection], event) then
			Unload(files[selection])
			active = false
		end
	else
		-- Handle menu key events
		if event == EVT_MINUS_BREAK or event == EVT_ROT_RIGHT or event == EVT_DOWN_BREAK then
			selection = selection + 1
			if selection > #texts then 
				selection = 1
			end
		end
		
		if event == EVT_PLUS_BREAK or event == EVT_ROT_LEFT or event == EVT_UP_BREAK then
			selection = selection - 1
			if selection <= 0 then 
				selection = #texts
			end
		end
		
		menu.Draw(selection)
	end
end

return {init = init, background = background, run = run}