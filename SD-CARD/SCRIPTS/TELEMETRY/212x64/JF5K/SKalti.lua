-- 212x64/JF3Kalti/SK.lua
-- Timestamp: 2020-04-10
-- Created by Jesper Frickmann

local sk = ...  -- List of variables shared between fixed and loadable parts
local ui = { } -- Graphics functions
local Plot = soarUtil.LoadWxH("PLOT.lua", ui) -- Screen size specific function
sk.p.heightInt = 4 -- Interval for recording heights

-- Initialize plot variables
ui.left = 0
ui.right = sk.taskWindow / sk.p.heightInt + 1
ui.tMin = 0
ui.tMax = sk.taskWindow
ui.yMin = 0
ui.yValues = sk.p.yValues

function ui.Draw()
	local att

	soarUtil.InfoBar(sk.taskName)
	
	-- Rescale if necessary
	ui.yMax = math.ceil(math.max(25, sk.p.plotMax, sk.p.ceiling) / 25) * 25

	Plot()
	ui.DrawLines()
	
	-- In height poker, show call
	if sk.task == sk.p.TASK_HEIGHT_POKER and sk.state <= sk.STATE_WINDOW then
		local att = 0
		
		if sk.p.pokerCalled then att = att + BLINK + INVERS end
		lcd.drawText(2, 55, string.format("Call: %im", sk.p.targetGain), att)
	end

	-- Show ceiling
	if sk.task == sk.p.TASK_CEILING and sk.state == sk.STATE_IDLE then
		lcd.drawText(2, 55, string.format("Ceiling: %im", sk.p.ceiling))
	end

	-- Timers
	lcd.drawText(LCD_W - 46, 15, "F")
	
	if sk.flightTimer < 0 then
		att = BLINK + INVERS
	else
		att = 0
	end
	
	lcd.drawTimer(LCD_W, 12, sk.flightTimer, MIDSIZE + RIGHT + att)

	lcd.drawText(LCD_W - 46, 33, "W")
	
	if sk.state == sk.STATE_FINISHED then
		att = BLINK + INVERS
	else
		att = 0
	end
	
	lcd.drawTimer(LCD_W, 30, sk.winTimer,  MIDSIZE  + RIGHT + att)

	-- QR and EoW
	if sk.eowTimerStop then
		lcd.drawText(LCD_W - 18, 48, "EoW", SMLSIZE + INVERS)
	end
	
	if sk.quickRelaunch then
		lcd.drawText(LCD_W - 33, 48, "QR", SMLSIZE + INVERS)
	end

	if sk.p.launchHeight > 0 then
		lcd.drawText(126, 56, string.format("Launch %i m", sk.p.launchHeight))
	end
	
	-- Scores
	for i = 1, sk.taskScores do
		local dy = 14
		
		if i > #sk.scores then
			lcd.drawText(126, dy * i, string.format("%i. - - -", i))
		elseif sk.p.unit == "s" then
			lcd.drawText(126, dy * i, string.format("%i. %s", i, soarUtil.TmrStr(sk.scores[i].time)))
		else
			lcd.drawText(126, dy * i, string.format("%i. %4i%s", i, sk.scores[i].gain, sk.p.unit))
		end
	end
end  --  Draw()
	
function ui.PromptScores()
	soarUtil.InfoBar(sk.taskName)
	lcd.drawText(38, 15, "Save scores?", DBLSIZE)
	lcd.drawText(4, LCD_H - 16, "EXIT", MIDSIZE + BLINK)
	lcd.drawText(LCD_W - 3, LCD_H - 16, "SAVE", MIDSIZE + BLINK + RIGHT)
end -- PromptScores()

function ui.NotifyStopWindow()
	soarUtil.InfoBar(sk.taskName)
	lcd.drawText(38, 18, "Stop window timer", MIDSIZE)
	lcd.drawText(38, 40, "before leaving task.", MIDSIZE)
end -- NotifyStopWindow()

function ui.NotifyStopFlight()
	soarUtil.InfoBar(sk.taskName)
	lcd.drawText(30, 18, "Stop the flight timer", MIDSIZE)
	lcd.drawText(30, 40, "before pausing window.", MIDSIZE)
end -- NotifyStopFlight()

return ui