-- JF F3RES Configuration Menu
-- Timestamp: 2018-12-31
-- Created by Jesper Frickmann
-- Depends on library functions in FUNCTIONS/JFLib.lua
-- "adj" is a global var that is output to OpenTX with a custom script

local selection = 1
local active = false
local lastRun = 0

-- Menu texts
local texts = {
	"1. Channel configuration",
	"2. Adjust brake-elevator" }

	-- Lua files to be loaded and unloaded
local files = {
	"/SCRIPTS/TELEMETRY/JF/CHANNELS.lua",
	"/SCRIPTS/TELEMETRY/JF3R/ADJMIX.lua" }

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
		
		-- Show the menu
		if tx == TX_X9D then
			DrawMenu(" JF F3RES Configuration ")
			att = 0
			x = 10
			lcd.drawPixmap(159, 11, "/IMAGES/Lua-girl.bmp")
		else -- QX7 or X-lite
			DrawMenu("Configuration")
			att = SMLSIZE
			x = 5
		end
		
		for i = 1, #texts do
			local inv
			if i == selection then 
				inv = INVERS
			else
				inv = 0
			end
			
			lcd.drawText(x, 2 + 12 * i, texts[i], att + inv)
		end
	end
end

return {background = background, run = run}