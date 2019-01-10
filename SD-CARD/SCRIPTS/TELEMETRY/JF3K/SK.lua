-- User interface for several score keeper plugins
-- Timestamp: 2019-01-09
-- Created by Jesper Frickmann

local 	exitTask = 0 -- Prompt to save task before EXIT
local stopWindow = 0 -- Prompt to stop flight timer first
local Draw -- Function to draw the screen for specific transmitter

-- Convert time to minutes and seconds
local function MinSec(t)
	local m = math.floor(t / 60)
	return m, t - 60 * m
end -- MinSec()

-- Transmitter specific
if tx == TX_X9D then

	Draw = function()
		local x = 0
		local y = 9
		local split
		local att -- Screen drawing attribues
		
		DrawMenu(" " .. sk.taskName .. " ")

		-- Draw scores
		if sk.taskScores == 5 or sk.taskScores == 6 then
			split = 4
		else
			split = 5
		end

		for i = 1, sk.taskScores do
			if i == split then
				x = 52
				y = 9
			end

			if i <= #sk.scores then
				lcd.drawText(x, y, string.format("%i. %02i:%02i", i, MinSec(sk.scores[i])), MIDSIZE)
			else
				lcd.drawText(x, y, string.format("%i. - - -", i), MIDSIZE)
			end

			y = y + 14
		end
		
		if sk.quickRelaunch then
			lcd.drawText(105, 13, "QR", MIDSIZE + INVERS)
		end

		if sk.eowTimerStop then
			lcd.drawText(102, 31, "EoW", MIDSIZE + INVERS)
		end

		att = 0			
		if sk.state >= sk.STATE_FLYING then
			lcd.drawText(133, 13, "Flt", MIDSIZE)
		else
			lcd.drawText(133, 13, "Tgt", MIDSIZE)

			if plugin.pokerCalled then
				att = INVERS + BLINK
			end
		end
		if sk.flightTimer < 0 then
			att = INVERS + BLINK
		end
		lcd.drawTimer(LCD_W, 10, model.getTimer(0).value, DBLSIZE + RIGHT + att)

		lcd.drawText(133, 31, "Win", MIDSIZE)
		att = 0
		if sk.state >= sk.STATE_WINDOW then
			if sk.winTimer < 0 then
				att = INVERS + BLINK
			end

			if sk.launches >= 0 then
				local s = ""
				if sk.launches ~= 1 then s = "es" end
				lcd.drawText(LCD_W, 50, string.format("%i launch%s left", sk.launches, s), MIDSIZE + RIGHT)
			end

			if sk.state >= sk.STATE_COMMITTED and sk.taskScores - #sk.scores > 1 and plugin.pokerCalled then
				local m = math.floor((1024 + getValue(sk.set1id)) / 205)
				local s = math.floor((1024 + getValue(sk.set2id)) / 34.2)
				local t = math.max(5, math.min(sk.winTimer - 1, 60 * m + s))
				
				lcd.drawText(104, 50, "Next call", MIDSIZE)
				lcd.drawTimer(LCD_W, 50, t, RIGHT + MIDSIZE)
			end

		else

			if sk.state == sk.STATE_FINISHED then
				lcd.drawText(LCD_W - 4, 50, "GAME OVER!", MIDSIZE + RIGHT + BLINK)
			end
		end
		lcd.drawTimer(LCD_W, 28, model.getTimer(1).value, DBLSIZE + RIGHT + att)
	end  --  Draw()

else -- TX_QX7 or X-lite

	-- The smaller screens can only fit 7 flights
	sk.launches = math.min(7, sk.launches)
	sk.taskScores = math.min(7, sk.taskScores)
	
	Draw = function()
		local y = 8
		local att -- Screen drawing attribues
		
		DrawMenu(sk.taskName)
		
		-- Draw scores
		for i = 1, sk.taskScores do
			lcd.drawNumber(6, y, i, RIGHT)
			lcd.drawText(7, y, ".")

			if i <= #sk.scores then
				lcd.drawText(0, y, string.format("%i. %02i:%02i", i, MinSec(sk.scores[i])))
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

			if plugin.pokerCalled then
				att = INVERS + BLINK
			end
		end
		if sk.flightTimer < 0 then
			att = INVERS + BLINK
		end
		lcd.drawTimer(LCD_W, 10, model.getTimer(0).value, DBLSIZE + RIGHT + att)

		lcd.drawText(62, 33, "Win")
		att = 0
		if sk.state >= sk.STATE_WINDOW then
			if sk.winTimer < 0 then
				att = INVERS + BLINK
			end

			if sk.launches >= 0 then
				local s = ""
				if sk.launches ~= 1 then s = "es" end
				lcd.drawText(LCD_W, 54, string.format("%i launch%s left", sk.launches, s), RIGHT)
			end

			if sk.state >= sk.STATE_COMMITTED and sk.taskScores - #sk.scores > 1 and plugin.pokerCalled then
				local m = math.floor((1024 + getValue(sk.set1id)) / 205)
				local s = math.floor((1024 + getValue(sk.set2id)) / 34.2)
				local t = math.max(5, math.min(sk.winTimer - 1, 60 * m + s))
				
				lcd.drawText(45, 53, "Next call")
				lcd.drawTimer(LCD_W, 50, t, RIGHT + MIDSIZE)
			end

		else

			if sk.state == sk.STATE_FINISHED then
				lcd.drawText(LCD_W - 4, 50, "GAME OVER!", MIDSIZE + RIGHT + BLINK)
			end
		end
		lcd.drawTimer(LCD_W, 28, model.getTimer(1).value, DBLSIZE + RIGHT + att)
	end -- Draw()
end

local function run(event)
	if exitTask == -1 then -- Popup menu active
		local menuReply = popupInput("Save scores?", event, 0, 0, 0)

		-- Record scores if user pressed ENTER
		if menuReply == "OK" then
			local now = getDateTime()
			local dateStr = string.format("%04i-%02i-%02i", now.year, now.mon, now.day)
			local timeStr = string.format("%02i:%02i", now.hour, now.min)
			local nameStr = model.getInfo().name
			local logFile = io.open("/LOGS/JF F3K Scores.csv", "a")
			if logFile then
				io.write(logFile, string.format("%s,%s,%s,%s,s", nameStr, sk.taskName, dateStr, timeStr))
				for i = 1, #sk.scores do
					io.write(logFile, string.format(",%i", sk.scores[i]))
				end
				io.write(logFile, "\n")
				io.close(logFile)
			end
		end

		-- Dismiss the popup menu and move on
		if menuReply ~= 0 then
			sk.run = sk.menu
		end

	elseif exitTask > 0 then
		if getTime() > exitTask then
			exitTask = 0
		else
			if tx == TX_X9D then
				DrawMenu(" " .. sk.taskName .. " ")
				lcd.drawText(38, 18, "Stop window timer", MIDSIZE)
				lcd.drawText(38, 40, "before leaving task.", MIDSIZE)
			else -- TX_QX7 or X-lite
				DrawMenu(sk.taskName)
				lcd.drawText(8, 15, "Stop window", MIDSIZE)
				lcd.drawText(8, 30, "timer before", MIDSIZE)
				lcd.drawText(8, 45, "leaving task.", MIDSIZE)
			end
		end
	
	elseif stopWindow > 0 then
		if getTime() > stopWindow then
			stopWindow = 0
		else
			if tx == TX_X9D then
				DrawMenu(" " .. sk.taskName .. " ")
				lcd.drawText(30, 18, "Stop the flight timer", MIDSIZE)
				lcd.drawText(30, 40, "before pausing window.", MIDSIZE)
			else -- TX_QX7 or X-lite
				DrawMenu(sk.taskName)
				lcd.drawText(8, 15, "Stop the flight", MIDSIZE)
				lcd.drawText(8, 30, "timer before", MIDSIZE)
				lcd.drawText(8, 45, "pausing window.", MIDSIZE)
			end
		end
	
	else
		Draw()

		-- Toggle quick relaunch QR
		if event == EVT_PLUS_BREAK or event == EVT_ROT_RIGHT or event == EVT_UP_BREAK then
			sk.quickRelaunch = not sk.quickRelaunch
			playTone(1760, 100, PLAY_NOW)
		end
		
		-- Toggle end of window timer stop EoW
		if event == EVT_MINUS_BREAK or event == EVT_ROT_LEFT or event == EVT_DOWN_BREAK then
			sk.eowTimerStop = not sk.eowTimerStop
			playTone(1760, 100, PLAY_NOW)
		end

		if event == EVT_ENTER_BREAK then
			if sk.state <= sk.STATE_PAUSE then
				-- Start task window
				sk.state = sk.STATE_WINDOW
			elseif sk.state == sk.STATE_WINDOW then
				-- Pause task window
				sk.state = sk.STATE_PAUSE
			elseif sk.state >= sk.STATE_READY then
				stopWindow = getTime() + 100
			end
			
			playTone(1760, 100, PLAY_NOW)
		end
		
		if (event == EVT_MENU_LONG or event == EVT_SHIFT_LONG) and sk.state == sk.STATE_COMMITTED then
			-- Record a zero score!
			sk.flightTime = 0
			sk.Score()
			
			-- Change state
			if sk.winTimer <= 0 or (sk.finalScores and #sk.scores == sk.taskScores) or sk.launches == 0 then
				sk.state = sk.STATE_FINISHED
			else
				sk.state = sk.STATE_WINDOW
			end

			playTone(440, 333, PLAY_NOW)
		end

		if event == EVT_EXIT_BREAK then
			-- Quit task
			if sk.state == sk.STATE_IDLE then
				sk.run = sk.menu
			elseif sk.state == sk.STATE_PAUSE or sk.state == sk.STATE_FINISHED then
				exitTask = -1
			else
				exitTask = getTime() + 100
			end
			
			playTone(1760, 100, PLAY_NOW)
		end
	end
end  --  run()

return { run = run }