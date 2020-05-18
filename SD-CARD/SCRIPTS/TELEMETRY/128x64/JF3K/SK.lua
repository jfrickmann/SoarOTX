-- 128x64/JF3K/SK.lua
-- Timestamp: 2020-04-10
-- Created by Jesper Frickmann

local sk = ...  -- List of variables shared between fixed and loadable parts
local ui = { } -- User interface functions

-- The smaller screens can only fit 7 flights
sk.launches = math.min(7, sk.launches)
sk.taskScores = math.min(7, sk.taskScores)

function ui.Draw()
	local y = 8
	local att -- Screen drawing attribues
	
	soarUtil.InfoBar(sk.taskName)
	
	-- Draw scores
	for i = 1, sk.taskScores do
		lcd.drawNumber(6, y, i, RIGHT)
		lcd.drawText(7, y, ".")

		if i <= #sk.scores then
			lcd.drawText(0, y, string.format("%i. %s", i, soarUtil.TmrStr(sk.scores[i])))
		else
			lcd.drawText(0, y, string.format("%i. - - -", i))
		end

		y = y + 8
	end	
	
	if sk.quickRelaunch then
		lcd.drawText(42, 15, "QR", INVERS)
	end

	if sk.eowTimerStop then
		lcd.drawText(40, 33, "EoW", INVERS)
	end

	att = 0
	
	if sk.state >= sk.STATE_FLYING then
		lcd.drawText(62, 15, "Flt")
	else
		lcd.drawText(62, 15, "Tgt")

		if sk.p.pokerCalled then
			att = INVERS + BLINK
		end
	end
	if sk.flightTimer < 0 then
		att = INVERS + BLINK
	end
	lcd.drawTimer(LCD_W, 10, model.getTimer(0).value, DBLSIZE + RIGHT + att)

	lcd.drawText(62, 33, "Win")
	att = 0
	
	if sk.state == sk.STATE_PAUSE then
		lcd.drawText(LCD_W, 53, string.format("Total score %i s", sk.p.totalScore), RIGHT)
	elseif sk.state == sk.STATE_FINISHED then
		lcd.drawText(45, 53, "Done!", BLINK)
		lcd.drawText(LCD_W, 53, string.format("Total %i s", sk.p.totalScore), RIGHT)
	else
		if sk.winTimer < 0 then
			att = INVERS + BLINK
		end

		if sk.launches >= 0 then
			local s = ""
			if sk.launches ~= 1 then s = "es" end
			lcd.drawText(45, 53, string.format("%i launch%s left", sk.launches, s))
		end

		if sk.state >= sk.STATE_COMMITTED and sk.taskScores - #sk.scores > 1 and sk.p.pokerCalled then
			lcd.drawText(45, 53, "Next call")
			lcd.drawTimer(LCD_W, 50, sk.PokerCall(), RIGHT + MIDSIZE)
		end
	end
	
	lcd.drawTimer(LCD_W, 28, model.getTimer(1).value, DBLSIZE + RIGHT + att)
end -- Draw()

function ui.PromptScores()
	soarUtil.InfoBar(sk.taskName)
	lcd.drawText(8, 15, "Save scores?", MIDSIZE)
	lcd.drawText(8, 35, "ENTER = SAVE")
	lcd.drawText(8, 45, "EXIT = DON'T")
end -- PromptScores()

function ui.NotifyStopWindow()
	soarUtil.InfoBar(sk.taskName)
	lcd.drawText(8, 15, "Stop window", MIDSIZE)
	lcd.drawText(8, 30, "timer before", MIDSIZE)
	lcd.drawText(8, 45, "leaving task.", MIDSIZE)
end -- NotifyStopWindow()

function ui.NotifyStopFlight()
	soarUtil.InfoBar(sk.taskName)
	lcd.drawText(8, 15, "Stop the flight", MIDSIZE)
	lcd.drawText(8, 30, "timer before", MIDSIZE)
	lcd.drawText(8, 45, "pausing window.", MIDSIZE)
end -- NotifyStopFlight()

return ui