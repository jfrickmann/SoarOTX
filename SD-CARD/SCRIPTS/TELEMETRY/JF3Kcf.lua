-- JF F3K Configuration Menu
-- Timestamp: 2019-07-07
-- Created by Jesper Frickmann
-- Depends on library functions in FUNCTIONS/JFutil.lua
-- "adj" is a global var that is output to OpenTX with a custom script

local active = false
local lastRun = 0
local ui = {} -- List of  variables shared with loadable user interface
ui.selection = 1

local Draw = LoadWxH("JF3Kcf.lua", ui) -- Screen size specific function

-- Menu texts
ui.texts = {
	"1. Channel configuration",
	"2. Align flaperons",
	"3. Center flaperons",
	"4. Adjust other mixes" }

-- Lua files to be loaded and unloaded
local files = {
	"/SCRIPTS/TELEMETRY/JF/CHANNELS.lua",
	"/SCRIPTS/TELEMETRY/JF3K/ALIGN.lua",
	"/SCRIPTS/TELEMETRY/JF3K/CENTER.lua",
	"/SCRIPTS/TELEMETRY/JF3K/ADJMIX.lua" }

local function background()
	if active then
		-- Do not leave loaded configuration scripts in the background
		if getTime() - lastRun > 100 then
			Unload(files[ui.selection])
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
		if RunLoadable(files[ui.selection], event) then
			Unload(files[ui.selection])
			active = false
		end
	else
		-- Handle menu key events
		if event == EVT_MINUS_BREAK or event == EVT_ROT_RIGHT or event == EVT_DOWN_BREAK then
			ui.selection = ui.selection + 1
			if ui.selection > #ui.texts then 
				ui.selection = 1
			end
		end
		
		if event == EVT_PLUS_BREAK or event == EVT_ROT_LEFT or event == EVT_UP_BREAK then
			ui.selection = ui.selection - 1
			if ui.selection <= 0 then 
				ui.selection = #ui.texts
			end
		end
		
		Draw()		
	end
end

return {background = background, run = run}