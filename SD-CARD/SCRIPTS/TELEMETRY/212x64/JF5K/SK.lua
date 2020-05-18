-- 212x64/JF5K/SK.lua
-- Timestamp: 2020-04-10
-- Created by Jesper Frickmann

local sk = ...  -- List of variables shared between fixed and loadable parts
local ui = { } -- User interface functions

function ui.Draw()
	local x = 0
	local y = 9
	local split
	local att -- Screen drawing attribues
	
	soarUtil.InfoBar(sk.taskName)

	-- Draw scores
	if sk.taskScores == 5 or sk.taskScores == 6 then
		split = 4
	else
		split = 5
	end

	for i = 1, sk.taskScores do
		if i == split then
			x = 60
			y = 9
		end

		if i <= #sk.scores then
			lcd.drawText(x, y, string.format("%i. %s", i, soarUtil.TmrStr(sk.scores[i][1])), MIDSIZE)
		else
			lcd.drawText(x, y, string.format("%i. - - -", i), MIDSIZE)
		end

		y = y + 14
	end
	
	att = 0			
	if sk.state >= sk.STATE_LAUNCHING then
		lcd.drawText(133, 13, "Flt", MIDSIZE)
	else
		lcd.drawText(133, 13, "Tgt", MIDSIZE)

		if sk.p.pokerCalled then
			att = INVERS + BLINK
		end
	end
	if sk.flightTimer < 0 then
		att = INVERS + BLINK
	end
	lcd.drawTimer(LCD_W, 10, model.getTimer(0).value, DBLSIZE + RIGHT + att)

	lcd.drawText(133, 31, "Win", MIDSIZE)
	att = 0
	
	if sk.state == sk.STATE_PAUSE then
		lcd.drawText(LCD_W, 50, string.format("Total %i sec.", sk.p.totalScore), RIGHT)
	elseif sk.state == sk.STATE_FINISHED then
		lcd.drawText(128, 50, "Done!", BLINK)
		lcd.drawText(160, 50, string.format("%i sec.", sk.p.totalScore))
	else
		if sk.winTimer < 0 then
			att = INVERS + BLINK
		end

		if sk.launches >= 0 then
			local s = ""
			if sk.launches ~= 1 then s = "es" end
			lcd.drawText(LCD_W, 50, string.format("%i launch%s left", sk.launches, s), RIGHT)
		end

		if sk.state >= sk.STATE_FLYING and sk.taskScores - #sk.scores > 1 and sk.p.pokerCalled then
			lcd.drawText(LCD_W, 50, string.format("Next call: %s", soarUtil.TmrStr(sk.PokerCall())), RIGHT)
		end
	end
	
	lcd.drawTimer(LCD_W, 28, model.getTimer(1).value, DBLSIZE + RIGHT + att)
end  --  Draw()

function ui.DrawEditScore(editing, score)
	local att = {0, 0}
	att[editing] = INVERS + BLINK
	
	soarUtil.InfoBar(sk.taskName)
	lcd.drawText(1, 15, "Flight time:")
	lcd.drawTimer(127, 15, score[1], RIGHT + att[1])
	
	lcd.drawText(1, 25, "Start height:")
	lcd.drawText(127, 25, string.format("%i m.", score[2]), RIGHT + att[2])
end

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