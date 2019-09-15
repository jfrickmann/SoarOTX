-- 128x64/JF3K/SKalti.lua
-- Timestamp: 2019-09-14
-- Created by Jesper Frickmann

plugin.heightInt = 7 -- Interval for recording heights

local DrawGraph = ...

-- Convert time to minutes and seconds
local function MinSec(t)
	local m = math.floor(t / 60)
	return m, t - 60 * m
end -- MinSec()

local function Draw()
	local att
	
	DrawMenu(sk.taskName)
	DrawGraph(SOLID)
	
	-- Timers
	if sk.flightTimer < 0 then
		att = BLINK + INVERS
	else
		att = 0
	end
	
	lcd.drawTimer(LCD_W, 12, sk.flightTimer, MIDSIZE + RIGHT + att)

	if sk.state == sk.STATE_FINISHED then
		att = BLINK + INVERS
	else
		att = 0
	end
	
	lcd.drawTimer(LCD_W, 30, sk.winTimer,  MIDSIZE + RIGHT + att)

	-- QR and EoW
	if sk.eowTimerStop then
		lcd.drawText(LCD_W - 18, 48, "EoW", SMLSIZE + INVERS)
	end
	
	if sk.quickRelaunch then
		lcd.drawText(LCD_W - 33, 48, "QR", SMLSIZE + INVERS)
	end

	if plugin.launchHeight > 0 then
		lcd.drawText(73, 58, string.format("Launch %i m", plugin.launchHeight), SMLSIZE)
	end
	
	-- Scores
	for i = 1, sk.taskScores do
		local dy = 14
		
		if i > #sk.scores then
			lcd.drawText(73, dy * i, "- - -", SMLSIZE)
		elseif plugin.unit == "s" then
			lcd.drawText(73, dy * i, string.format("%02i:%02i", MinSec(sk.scores[i].time)), SMLSIZE)
		else
			lcd.drawText(73, dy * i, string.format("%4i%s", sk.scores[i].gain, plugin.unit), SMLSIZE)
		end
	end
end  --  Draw()

local function PromptScores()
	DrawMenu(sk.taskName)
	lcd.drawText(8, 15, "Save scores?", MIDSIZE)
	lcd.drawText(8, 35, "ENTER = SAVE")
	lcd.drawText(8, 45, "EXIT = DON'T")
end -- PromptScores()

local function NotifyStopWindow()
	DrawMenu(sk.taskName)
	lcd.drawText(8, 15, "Stop window", MIDSIZE)
	lcd.drawText(8, 30, "timer before", MIDSIZE)
	lcd.drawText(8, 45, "leaving task.", MIDSIZE)
end -- NotifyStopWindow()

local function NotifyStopFlight()
	DrawMenu(sk.taskName)
	lcd.drawText(8, 15, "Stop the flight", MIDSIZE)
	lcd.drawText(8, 30, "timer before", MIDSIZE)
	lcd.drawText(8, 45, "pausing window.", MIDSIZE)
end -- NotifyStopFlight()

return Draw, PromptScores, NotifyStopWindow, NotifyStopFlight