-- JF FXJ Configuration Menu
-- Timestamp: 2018-05-20
-- Created by Jesper Frickmann
-- Depends on library functions in FUNCTIONS/JFLib.lua
-- "adj" is a global var that is output to OpenTX with a custom script

local selection = 1
local active = false
local lastRun = 0

-- Menu texts
local texts = {
	"1. Channel configuration",
	"2. Align flaps & ailerons",
	"3. Adjust airbrake curves",
	"4. Aileron and camber",
	"5. Adjust other mixes" }

	-- Lua files to be loaded and unloaded
local files = {
	"/SCRIPTS/TELEMETRY/JFchannels.lua",
	"/SCRIPTS/TELEMETRY/JFXJalign.lua",
	"/SCRIPTS/TELEMETRY/JFXJbrkcrv.lua",
	"/SCRIPTS/TELEMETRY/JFXJailcmb.lua",
	"/SCRIPTS/TELEMETRY/JFXJadjmix.lua" }

local function background()
	if active then
		-- Do not leave loaded configuration scripts in the background
		if getTime() - lastRun > 100 then
			LdUnload(files[selection])
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
		if LdRun(files[selection], event) then
			LdUnload(files[selection])
			active = false
		end
	else
		-- Handle menu key events
		if event == EVT_MINUS_BREAK or event == EVT_ROT_RIGHT then
			selection = selection + 1
			if selection > #texts then 
				selection = 1
			end
		end
		
		if event == EVT_PLUS_BREAK or event == EVT_ROT_LEFT then
			selection = selection - 1
			if selection <= 0 then 
				selection = #texts
			end
		end
		
		-- Show the menu
		if tx == TX_X9D then
			DrawMenu(" JF F5J Configuration ")
			att = 0
			x = 10
			lcd.drawPixmap(159, 11, "/IMAGES/Lua-girl.bmp")
		else
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
			
			lcd.drawText(x, 3 + 10 * i, texts[i], att + inv)
		end
	end
end

return {background = background, run = run}