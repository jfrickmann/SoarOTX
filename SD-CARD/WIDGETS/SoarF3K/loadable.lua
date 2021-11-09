---------------------------------------------------------------------------
-- SoarETX F3K score keeper widget, loadable part                        --
--                                                                       --
-- Author:  Jesper Frickmann                                             --
-- Date:    2021-11-09                                                   --
-- Version: 0.99                                                         --
--                                                                       --
-- Copyright (C) Jesper Frickmann                                        --
--                                                                       --
-- License GPLv2: http://www.gnu.org/licenses/gpl-2.0.html               --
--                                                                       --
-- This program is free software; you can redistribute it and/or modify  --
-- it under the terms of the GNU General Public License version 2 as     --
-- published by the Free Software Foundation.                            --
--                                                                       --
-- This program is distributed in the hope that it will be useful        --
-- but WITHOUT ANY WARRANTY; without even the implied warranty of        --
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         --
-- GNU General Public License for more details.                          --
---------------------------------------------------------------------------

local zone, options = ...     -- zone and options were passed as arguments to chunk(...).
local widget = { }            -- The widget table will be returned to the main script.
local libGUI = loadGUI()      -- GUI library
libGUI.flags = DBLSIZE        -- Default drawing flags
local colors = libGUI.colors  -- Short cut

-- GUIs for the different screens and popups
local menuMain = libGUI.newGUI()
local menuF3K = libGUI.newGUI()
local menuPractice = libGUI.newGUI()
local screenTask = libGUI.newGUI()
local promptSaveScores = libGUI.newGUI()
local menuScores = { }

-- Screen drawing constants
local HEADER =   40
local LEFT =     25
local RGT =      LCD_W - 15
local TOP =      50
local LINE =     54
local LINE2 =    28 
local HEIGHT =   38
local HEIGHT2 =  18
local BUTTON_W = 90
local PROMPT_W = 260
local PROMPT_H = 170
local PROMPT_M = 30
local N_LINES =  5

local trimSources = {         -- Input sources for the trim buttons
  getFieldInfo("trim-ail").id,
  getFieldInfo("trim-rud").id,
  getFieldInfo("trim-ele").id,
  getFieldInfo("trim-thr").id
}

-- Battery
local rxBatV = 0              -- Receiver battery V
local rxBatSrc                -- Receiver battery source
local rxBatNxtWarn = 0        -- Time for next battery warning call

-- Constants
local LS_ALT = getFieldInfo("ls1").id   -- Input ID for allowing altitude calls
local LS_ALT10 = getFieldInfo("ls6").id -- Input ID for altitude calls every 10 sec.
local FM_ADJUST = 1                     -- Adjustment flight mode
local FM_LAUNCH = 2                     -- Launch/motor flight mode
local GV_BAT = 6                        -- GV used for battery warning in FM_ADJUST
local ALT_UNIT = 9                      -- Altitude units (m)
local COLOR_NOTIFY_TEXT = lcd.RGB(255, 255, 127)
local COLOR_NOTIFY_BG =   lcd.RGB(0, 0, 128)

-- Program states
local STATE_IDLE = 1      -- Task window not running
local STATE_PAUSE = 2     -- Task window paused, not flying
local STATE_FINISHED = 3  -- Task has been finished
local STATE_WINDOW = 4    -- Task window started, not flying
local STATE_READY = 5     -- Flight timer will be started when launch switch is released
local STATE_FLYING = 6    -- Flight timer started but flight not yet committed
local STATE_COMMITTED = 7 -- Flight timer started, and flight committed
local STATE_FREEZE = 8    -- Still committed, but freeze  the flight timer
local state               -- Current program state

-- Common variables for score keeping
local scores = { }              -- List of saved scores
local taskWindow = 0            -- Task window duration (zero counts up)
local launches = -1             -- Number of launches allowed, -1 for unlimited
local taskScores = 0            -- Number of scores in task 
local finalScores = false       -- Task scores are final
local targetType = 0            -- 1. Huge ladder, 2. Poker, 3. "1234", 4. Big ladder, Else: constant time
local scoreType                 -- 1. Best, 2. Last, 3. Make time
local totalScore                -- Total score
local prevFM = getFlightMode()  -- Used for detecting when FM changes
local prevWt                    -- Previous value of the window timer
local prevFt                    -- Previous value of flight timer

-- Other common variables
local counts = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 15, 20, 30, 45} -- Flight timer countdown
local countIndex            -- Index of timer count
local nextCall = 0          -- Call out altitude every 10 sec.
local winTimer = 0          -- Window timer
local flightTimer           -- Flight timer
local flightTime            -- Flight flown

-- Variables used for Poker task
local pokerCalled     -- Lock in time in Poker task
local lastInput = 0   -- For announcing changes in PokerCall
local lastChange = 0  -- Same
local tblStep = { {30, 5}, {60, 10}, {120, 15}, {210, 30}, {420, 60}, {taskWindow + 60} } -- Step sizes for input of call time

-- Browsing scores
local SCORE_FILE = "/LOGS/JF F3K Scores.csv"

-- Set GV for controlling timers
local function SetGVTmr(tmr)
	model.setGlobalVariable(8, 0, tmr)
end

-- Handle transitions between program states
local function GotoState(newState)
  state = newState
 
  -- Stop blinking
    screenTask.timer0.blink = false

    if state < STATE_WINDOW or state == STATE_FREEZE then
		-- Stop both timers
		SetGVTmr(0)
    screenTask.labelTimer0.title = "Target:"
    screenTask.locked = false

  elseif state == STATE_WINDOW then
		-- Start task window timer, but not flight timer
		SetGVTmr(1)
    screenTask.labelTimer0.title = "Target:"
    screenTask.locked = true
	
  elseif state == STATE_FLYING then
		-- Start both timers
		SetGVTmr(2)
    screenTask.labelTimer0.title = "Flight:"
    screenTask.locked = true
    
    if model.getTimer(0).start > 0 then
      -- Report the target time
      playDuration(model.getTimer(0).start, 0)
    else
      -- ... or beep
      playTone(1760, 100, PLAY_NOW)
    end
  
  elseif state == STATE_COMMITTED then
    -- Call launch height
    if getValue(LS_ALT) > 0 then
      playNumber(getValue("Alt+"), ALT_UNIT)
    end
    
    if launches > 0 then 
      launches = launches - 1
    end
  
    lastChange = 0
 
 elseif state == STATE_FINISHED then
    playTone(880, 1000, 0)
  end
  
  -- Configure "button3"
  screenTask.button3.disabled = false
  if state <= STATE_PAUSE then
    screenTask.button3.title = "Start"    
  elseif state == STATE_WINDOW then
    screenTask.button3.title = "Pause"
  elseif state >= STATE_COMMITTED then
    screenTask.button3.title = "Zero"
  else
    screenTask.button3.disabled = true  
  end
  
  -- Configure info text label
	if state == STATE_PAUSE then
    screenTask.labelInfo.title = string.format("Total: %i sec.", totalScore)
	elseif state == STATE_FINISHED then
    screenTask.labelInfo.title = string.format("Done! %i sec.", totalScore)
	else
		if launches >= 0 then
			local s = ""
			if launches ~= 1 then s = "es" end
      screenTask.labelInfo.title = string.format("%i launch%s left", launches, s)
    else
      screenTask.labelInfo.title = ""
		end
	end
end -- GotoState()

-- Function for setting up a task
local function SetupTask(taskName, taskData)
  screenTask.title = taskName
  
  taskWindow = taskData[1]
  launches = taskData[2]
  taskScores = taskData[3]
  finalScores = taskData[4]
  targetType = taskData[5]
  scoreType = taskData[6]
  screenTask.buttonQR.value = taskData[7]  
  scores = { }
  totalScore = 0
  pokerCalled = false
  
  -- Setup scores
  for i = 1, N_LINES do
    if i > taskScores then
      screenTask.scoreLabels[i].hidden = true
      screenTask.scores[i].hidden = true
    else
      screenTask.scoreLabels[i].hidden = false
      screenTask.scores[i].hidden = false
    end
  end
  
  -- A few extra counts in 1234
  if targetType == 3 then
		counts = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 15, 20, 30, 45, 65, 70, 75, 125, 130, 135, 185, 190, 195}
  else
    counts = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 15, 20, 30, 45}
  end

  GotoState(STATE_IDLE)
end -- SetupTask(...)

-- Keep the best scores
local function RecordBest(scores, newScore)
  local n = #scores
  local i = 1
  local j = 0

  -- Find the position where the new score is going to be inserted
  if n == 0 then
    j = 1
  else
    -- Find the first position where existing score is smaller than the new score
    while i <= n and j == 0 do
      if newScore > scores[i] then j = i end
      i = i + 1
    end
    
    if j == 0 then j = i end -- New score is smallest; end of the list
  end

  -- If the list is not yet full; let it grow
  if n < taskScores then n = n + 1 end

  -- Insert the new score and move the following scores down the list
  for i = j, n do
    newScore, scores[i] = scores[i], newScore
  end
end  --  RecordBest (...)

-- Used for calculating the total score and sometimes target time
local function MaxScore(iFlight)
  if targetType == 1 then -- Huge ladder
    return 60 + 120 * iFlight
  elseif targetType == 2 then -- Poker
    return 9999
  elseif targetType == 3 then -- 1234
    return 300 - 60 * iFlight
  elseif targetType == 4 then -- Big ladder
    return 30 + 30 * iFlight
  else -- MaxScore = targetType
    return targetType
  end
end

-- Record scores
local function Score()
	if scoreType == 1 then -- Best scores
    RecordBest(scores, flightTime)

  elseif scoreType == 2 then -- Last scores
    local n = #scores
    if n >= taskScores then
      -- List is full; move other scores one up to make room for the latest at the end
      for j = 1, n - 1 do
        scores[j] = scores[j + 1]
      end
    else
      -- List can grow; add to the end of the list
      n = n + 1
    end
    scores[n] = flightTime

  else -- Must make time to get score
    local score = flightTime
    -- Did we make time?
    if flightTimer > 0 then
      return
    else
      -- In Poker, only score the call
      if pokerCalled then
        score = model.getTimer(0).start
        pokerCalled = false
      end
    end
    scores[#scores + 1] = score

	end

  totalScore = 0  
  for i = 1, #scores do
    totalScore = totalScore + math.min(MaxScore(i), scores[i])
  end
end -- Score()

-- Reset altimeter
local function ResetAlt()
  for i = 0, 31 do
    if model.getSensor(i).name == "Alt" then 
      model.resetSensor(i)
      break
    end
  end
end

-- Find the best target time, given what has already been scored, as well as the remaining time of the window.
-- Note: maxTarget ensures that recursive calls to this function only test shorter target times. That way, we start with
-- the longest flight and work down the list. And we do not waste time testing the same target times in different orders.
local function Best1234Target(timeLeft, scores, maxTarget)
  local bestTotal = 0
  local bestTarget = 0

  -- Max. minutes there is time left to fly
  local maxMinutes = math.min(maxTarget, 4, math.ceil(timeLeft / 60))

  -- Iterate from 1 to n minutes to find the best target time
  for i = 1, maxMinutes do
    local target
    local tl
    local tot
    local dummy

    -- Target in seconds
    target = 60 * i

    -- Copy scores to a new table
    local s = {}
    for j = 1, #scores do
      s[j] = scores[j]
    end

    -- Add new target time to s; only until the end of the window
    RecordBest(s, math.min(timeLeft, target))
    tl = timeLeft - target

    -- Add up total score, assuming that the new target time was made
    if tl <= 0 or i == 1 then
      -- No more flights are made; sum it all up
      tot = 0
      for j = 1, math.min(4, #s) do
        tot = tot + math.min(300 - 60 * j, s[j])
      end
    else
      -- More flights can be made; add more flights recursively
      -- Subtract one second from tl for turnaround time
      dummy, tot = Best1234Target(tl - 1, s, i - 1)
    end

    -- Do we have a new winner?
    if tot > bestTotal then
      bestTotal = tot
      bestTarget = target
    end
  end

  return bestTarget, bestTotal
end  --  Best1234Target(..)

-- Get called time from user in Poker
local function PokerCall()
  local dial
  
  -- Find dials for setting target time in Poker and height ceilings etc.
  for input = 0, 31 do
    local tbl = model.getInput(input, 0)
    
    if tbl and tbl.name == "Dial" then
      dial = tbl.source
    end
  end

  -- If input lines were not found, then default to S1 and S2
  if not dial then dial = getFieldInfo("s1").id end

  local input = getValue(dial)
  local i, x = math.modf(1 + (#tblStep - 1) * (math.min(1023, input) + 1024) / 2048)
  local t1 = tblStep[i][1]
  local t2 = tblStep[i + 1][1]
  local dt = tblStep[i][2]
  
  local result = t1 + dt * math.floor(x * (t2 - t1) /dt)
  
  if scoreType == 3 then
    result = math.min(winTimer - 1, result)
  end
  
  if math.abs(input - lastInput) >= 20 then
    lastInput = input
    lastChange = getTime()
  end
  
  if state == STATE_COMMITTED and lastChange > 0 and getTime() - lastChange > 100 then
    playTone(3000, 100, PLAY_NOW)
    playDuration(result)
    lastChange = 0
  end
  
  return result
end -- PokerCall()

local function TargetTime()
	if targetType == 2 then -- Poker
    if pokerCalled then
      return model.getTimer(0).start
    else
      return PokerCall()
    end
	elseif targetType == 3 then -- 1234
    return Best1234Target(winTimer, scores, 4)
	else -- All other tasks
    return MaxScore(#scores + 1)
	end
end -- TargetTime()
	
-- Initialize variables before flight
local function InitializeFlight()
	local targetTime = TargetTime()
	
	-- Get ready to count down
	countIndex = #counts
	while countIndex > 1 and counts[countIndex] >= targetTime do
		countIndex = countIndex - 1
	end

	-- Set flight timer
	model.setTimer(0, { start = targetTime, value = targetTime })
	flightTimer = targetTime
	prevFt = targetTime
end  --  InitializeFlight()

function widget.background()
  local now = getTime()
	local flightMode = getFlightMode()
	local launchPulled = (flightMode == FM_LAUNCH and prevFM ~= flightMode)
	local launchReleased = (flightMode ~= prevFM and prevFM == FM_LAUNCH)
	prevFM = flightMode

  -- Reset altitude
	if launchPulled then
		ResetAlt()
	end
	
  -- Call altitude every 10 sec.
	if getValue(LS_ALT10) > 0 and now > nextCall then
		playNumber(getValue("Alt"), ALT_UNIT)
		nextCall = now + 1000
	end

	-- Write the current flight mode to a telemetry sensor.
	setTelemetryValue(0x5050, 0, 224, getFlightMode(), 0, 0, "FM")
	
	if state <= STATE_READY and state ~= STATE_FINISHED then
		InitializeFlight()
	end
	
	flightTimer = model.getTimer(0).value
	flightTime = math.abs(model.getTimer(0).start - flightTimer)
	winTimer = model.getTimer(1).value
	
	if state < STATE_WINDOW then
		if state == STATE_IDLE then
			-- Set window timer
			model.setTimer(1, { start = taskWindow, value = taskWindow })
			winTimer = taskWindow
			prevWt = taskWindow

			-- Automatically start window and flight if launch switch is released
			if launchPulled then
				GotoState(STATE_READY)
			end
		end

	else
		-- Did the window expire?
		if prevWt > 0 and winTimer <= 0 then
			playTone(880, 1000, 0)

			if state < STATE_FLYING then
				GotoState(STATE_FINISHED)
			elseif screenTask.buttonEoW.value then
				GotoState(STATE_FREEZE)
			end
		end

		if state == STATE_WINDOW then
			if launchPulled then
				GotoState(STATE_READY)
			elseif launchReleased then
				-- Play tone to warn that timer is NOT running
				playTone(1760, 200, 0, PLAY_NOW)
			end
			
		elseif state == STATE_READY then
			if launchReleased then
				GotoState(STATE_FLYING)
			end

		elseif state >= STATE_FLYING then
			-- Time counts
			if flightTimer <= counts[countIndex] and prevFt > counts[countIndex]  then
				if flightTimer > 15 then
					playDuration(flightTimer, 0)
				else
					playNumber(flightTimer, 0)
				end
				if countIndex > 1 then countIndex = countIndex - 1 end
			elseif flightTimer > 0 and math.ceil(flightTimer / 60) < math.ceil(prevFt / 60) then
				playDuration(flightTimer, 0)
			end
			
      -- Blink when flight ttimer is negative
      if flightTimer < 0 then
        screenTask.timer0.blink = true
      end
      
			if state == STATE_FLYING then
				-- Within 10 sec. "grace period", cancel the flight
				if launchPulled then
					GotoState(STATE_WINDOW)
				end

				-- After 10 seconds, commit flight
				if flightTime >= 10 then
					GotoState(STATE_COMMITTED)
				end
				
			elseif launchPulled then
				-- Report the time after flight is done
				if model.getTimer(0).start == 0 then
					playDuration(flightTime, 0)
				end

				Score()
				
				-- Change state
				if (finalScores and #scores == taskScores) or launches == 0 or (taskWindow > 0 and winTimer <= 0) then
					GotoState(STATE_FINISHED)
				elseif screenTask.buttonQR.value then
					GotoState(STATE_READY)
				else
					GotoState(STATE_WINDOW)
				end
			end
		end
		
		prevWt = winTimer
		prevFt = flightTimer
	end

  -- Update info for user dial targets
	if state == STATE_COMMITTED and targetType == 2 and (scoreType ~= 3 or taskScores - #scores > 1) then
    local call = PokerCall()
    local min = math.floor(call / 60)
    local sec = call - 60 * min
    screenTask.labelInfo.title = string.format("Next call: %02i:%02i", min, sec)
  end

  -- "Must make time" tasks
	if scoreType == 3 then
    if state == STATE_COMMITTED then
      pokerCalled = true
    elseif state < STATE_FLYING and state ~= STATE_FINISHED and winTimer < TargetTime() then
      GotoState(STATE_FINISHED)
    end
	end
  
  -- Receiver battery
  if not rxBatSrc then 
    rxBatSrc = getFieldInfo("Cels")
    if not rxBatSrc then rxBatSrc = getFieldInfo("RxBt") end
    if not rxBatSrc then rxBatSrc = getFieldInfo("A1") end
    if not rxBatSrc then rxBatSrc = getFieldInfo("A2") end
  end
  
  if rxBatSrc then
    rxBatV = getValue(rxBatSrc.id)
    
    if type(rxBatV) == "table" then
      for i = 2, #rxBatV do
        rxBatV[1] = math.min(rxBatV[1], rxBatV[i])
      end
      rxBatV = rxBatV[1]
    end
  end

  if not rxBatV then
    rxBatV = 0
  end
  
  -- Warn about low receiver battery or Rx off
  if now > rxBatNxtWarn then
    if rxBatV == 0 then
      if flightMode == FM_LAUNCH then
        playHaptic(200, 0, 1)
        playFile("lowbat.wav")
        rxBatNxtWarn = now + 200
      end
    else
      if rxBatV < 0.1 * options.Battery then
        playHaptic(200, 0, 1)
        playFile("lowbat.wav")
        playNumber(10 * rxBatV + 0.5, 1, PREC1)
        rxBatNxtWarn = now + 2000
      end
    end
  end
end -- background()

function widget.update(opt)
  options = opt
end

-- Push new GUI as sub screen
local function PushGUI(gui)
  gui.parent = widget.gui
  widget.gui = gui
end

-- Are we allowed to pop screen?
local function CanPopGUI()
  return widget.gui.parent and not widget.gui.editing and not widget.gui.locked
end

-- Pop GUI to return to previous screen
local function PopGUI()
  if CanPopGUI() then
    widget.gui = widget.gui.parent
    return true
  end
end

-- Draw zone area when not in fullscreen mode
local function drawZone()
  lcd.drawFilledRectangle(0, 0, zone.w, zone.h, options.BgColor, options.BgOpacity)
  
  -- Draw Rx battery
  local color = colors.text
  if rxBatV == 0 then
    color = COLOR_THEME_DISABLED
  end
  str = string.format("%1.1fV", rxBatV)
  lcd.drawText(zone.w, 0, str, RIGHT + BOLD + color)
  
  -- Draw scores
  x = 5
  local y = 0
  local dy = zone.h / N_LINES
  
  for i = 1, taskScores do
    lcd.drawText(x, y, string.format("%i.", i), colors.text + DBLSIZE)
    if i > #scores then
      lcd.drawText(x + 30, y, "  -   -   -", colors.text + DBLSIZE)
    else
      lcd.drawTimer(x + 30, y, scores[i], colors.text + DBLSIZE)
    end
    
    y = y + dy
  end

  -- Draw timers
  local blink = 0
  local x = zone.w - lcd.sizeText("-00:00 ", DBLSIZE)
  local y = 18
  
  local tmr = model.getTimer(0).value
  if tmr < 0 and state == STATE_COMMITTED then 
    blink = BLINK
  end

  lcd.drawText(x, y, screenTask.labelTimer0.title, colors.text + MIDSIZE)
  y = y + 24
  lcd.drawTimer(x, y, tmr, colors.text + blink + DBLSIZE)
  
  tmr = model.getTimer(1).value
  y = y + 48
  lcd.drawText(x, y, "Task:", colors.text + MIDSIZE)
  y = y + 24
  lcd.drawTimer(x, y, tmr, colors.text + DBLSIZE)
end -- drawZone()


-- Setup screen with title, trims, flight mode etc.
local function SetupScreen(gui, title)
  gui.widgetRefresh = drawZone
  gui.title = title
  
  function gui.fullScreenRefresh()
    local color

    -- Bleed out background to make all of the screen readable
    lcd.drawFilledRectangle(0, HEADER, LCD_W, LCD_H - HEADER, options.BgColor, options.BgOpacity)

    -- Top bar
    lcd.drawFilledRectangle(0, 0, LCD_W, HEADER, COLOR_THEME_SECONDARY1)
    lcd.drawText(10, 2, gui.title, bit32.bor(DBLSIZE, colors.focusText))

    -- Date
    local now = getDateTime()
    local str = string.format("%02i:%02i", now.hour, now.min)
    lcd.drawText(LCD_W - 80, 6, str, RIGHT + MIDSIZE + colors.focusText)    

    if rxBatV == 0 then
      color = COLOR_THEME_DISABLED
    else
      color = colors.focusText
    end
    
    str = string.format("%1.1fV", rxBatV)
    lcd.drawText(LCD_W - 140, 6, str, RIGHT + MIDSIZE + color)
    
    -- Draw trims
    local p = {
    --{ x, y, h, w }
      { LCD_W - 191, LCD_H - 13, 177, 8 },
      { 14, LCD_H - 13, 177, 8 },
      { LCD_W - 13, 68, 8, 177 },
      { 6, 68, 8, 177 },
    }
    
    for i = 1, 4 do
      local q = p[i]
      local value = getValue(trimSources[i]) / 10.24
      local x, y
      if q[3] > q[4] then
        x = q[1] + q[3] * (value + 100) / 200
        y = q[2] + q[4] / 2
      else
        x = q[1] + q[3] / 2
        y = q[2] + q[4] * (100 - value) / 200
      end
      
      lcd.drawFilledRectangle(q[1], q[2], q[3], q[4], COLOR_THEME_SECONDARY1)
      lcd.drawFilledRectangle(x - 7, y - 7, 15, 15, COLOR_THEME_PRIMARY1)
      lcd.drawFilledRectangle(x - 8, y - 8, 15, 15, colors.buttonBackground)
      lcd.drawNumber(x, y, value, SMLSIZE + VCENTER + CENTER + colors.focusText)
    end
    
    -- Flight mode
    lcd.drawText(LCD_W / 2, LCD_H - LINE2, select(2, getFlightMode()), MIDSIZE + CENTER + COLOR_THEME_SECONDARY1)    
  end -- fullScreenRefresh()
  
  -- Return button
  gui.buttonRet = gui.button(LCD_W - 74, 6, 28, 28, "", PopGUI)

  -- Paint another face on it
  local drawRet = gui.buttonRet.draw
  function gui.buttonRet.draw(idx)
    local color
    drawRet(idx)

    if CanPopGUI() then
      color = colors.focusText
      gui.buttonRet.disabled = nil
    else
      color = COLOR_THEME_DISABLED
      gui.buttonRet.disabled = true
    end
    
    lcd.drawFilledRectangle(LCD_W - 74, 6, 28, 28, COLOR_THEME_SECONDARY1)
    lcd.drawRectangle(LCD_W - 74, 6, 28, 28, color)
    for i = -1, 1 do
      lcd.drawLine(LCD_W - 60 + i, 12, LCD_W - 60 + i, 30, SOLID, color)
    end
    for i = 0, 3 do
      lcd.drawLine(LCD_W - 60 , 10 + i, LCD_W - 50 - i, 20, SOLID, color)
      lcd.drawLine(LCD_W - 60 , 10 + i, LCD_W - 70 + i, 20, SOLID, color)
    end
  end

  -- Minimize button
  local buttonMin = gui.button(LCD_W - 34, 6, 28, 28, "", function() lcd.exitFullScreen() end)

  -- Paint another face on it
  local drawMin = buttonMin.draw
  function buttonMin.draw(idx)
    drawMin(idx)
    
    lcd.drawFilledRectangle(LCD_W - 34, 6, 28, 28, COLOR_THEME_SECONDARY1)
    lcd.drawRectangle(LCD_W - 34, 6, 28, 28, colors.focusText)
    for y = 19, 21 do
      lcd.drawLine(LCD_W - 30, y, LCD_W - 10, y, SOLID, colors.focusText)
    end
  end
  
  -- Short press EXIT to return to previous screen
  local function HandleEXIT(event, touchState)
    if PopGUI() then
      return false
    else
      return event
    end
  end
  gui.SetEventHandler(EVT_VIRTUAL_EXIT, HandleEXIT)
  
  return gui
end -- SetupScreen

-- Setup main menu
do
  SetupScreen(menuMain, "SoarETX  F3K")

  local items = {
    "1. F3K tasks",
    "2. Practice tasks",
    "3. View saved scores"
  }
  
  local subMenus = {
    menuF3K,
    menuPractice,
    menuScores
  }
  
  -- Call back function running when a menu item was selected
  local function callBack(item, event, touchState)
    PushGUI(subMenus[item.idx])
  end

  menuMain.menu(LEFT, TOP, N_LINES, items, callBack)
  widget.gui = menuMain
end


do -- Setup F3K tasks menu
  SetupScreen(menuF3K, "Select  F3K  Task")

	local tasks = {
		"A. Last flight",
		"B. Two last flights 3:00",
		"B. Two last flights 4:00",
		"C. All up last down",
		"D. Two flights only",
		"E. Poker 10 min.",
		"E. Poker 15 min.",
		"F. Three best out of six",
		"G. Five best flights",
		"H. 1-2-3-4 in any order",
		"I. Three best flights",
		"J. Three last flights",
		"K. Big Ladder",
		"L. One flight only",
		"M. Huge Ladder"
	}
  
  -- {win, launches, scores, final, tgtType, scoType, QR }
  local taskData = {
    { 420, -1, 1, false, 300, 2, false },   -- A. Last flight
    { 420, -1, 2, false, 180, 2, false },   -- B. Two last 3:00
    { 600, -1, 2, false, 240, 2, false },   -- B. Two last 4:00
    { 0, 5, 5, true, 180, 2, false },       -- C. AULD
    { 600, 2, 2, true, 300, 2, true },      -- D. Two flights only
    { 600, -1, 3, true, 2, 3, true },       -- E. Poker 10 min.
    { 900, -1, 3, true, 2, 3, true },       -- E. Poker 15 min.
    { 600, 6, 3, false, 180, 1, false },    -- F. 3 best of 6
    { 600, -1, 5, false, 120, 1, true },    -- G. 5 x 2:00
    { 600, -1, 4, false, 3, 1, true },      -- H. 1234
    { 600, -1, 3, false, 200, 1, true },    -- I. 3 Best
    { 600, -1, 3, false, 180, 2, false },   -- J. 3 last
    { 600, 5, 5, true, 4, 2, true },        -- K. Big ladder
    { 600, 1, 1, true, 599, 2, false },     -- L. One flight only
    { 900, 3, 3, true, 1, 2, true }         -- M. Huge Ladder
  }

  -- Call back function running when a menu item is selected
  local function callBack(item, event, touchState)
    SetupTask(tasks[item.idx], taskData[item.idx])
    PushGUI(screenTask)
  end

  menuF3K.menu(LEFT, TOP, N_LINES, tasks, callBack)
end

do -- Setup practice tasks menu
  SetupScreen(menuPractice, "Select  Practice  Task")
  
	local tasks = {
		"Just Fly!",
		"Quick Relaunch!",
		"Deuces"
	}

  -- {win, launches, scores, final, tgtType, scoType, QR }
  local taskData = {
    { 0, -1, 5, false, 0, 2, false }, -- Just fly
    { 0, -1, 5, false, 2, 2, true },  -- QR
    { 600, 2, 2, true, 2, 2, false }  -- Deuces
  }
  
  -- Call back function running when a menu item is selected
  local function callBack(item)
    SetupTask(tasks[item.idx], taskData[item.idx])
    PushGUI(screenTask)
  end

  menuPractice.menu(LEFT, TOP, N_LINES, tasks, callBack)
end


do -- Setup score keeper screen for F3K and Practice tasks
  SetupScreen(screenTask, "")
  
  -- Restore default task and dismiss task screen
  function screenTask.dismiss()  
    SetupTask("Just Fly!", { 0, -1, 5, false, 0, 2, false })
    PopGUI()
  end
  
  -- Return button shows prompt to save scores instead of popping right away
  function screenTask.buttonRet.callBack()
    if state == STATE_IDLE then
      screenTask.dismiss()
    else
      screenTask.prompt = promptSaveScores
    end
  end
  
  -- Add score times
  local y = TOP
  local dy = select(2, lcd.sizeText("", libGUI.flags))
  
  screenTask.scoreLabels = { }
  screenTask.scores = { }

  for i = 1, N_LINES do
    screenTask.scoreLabels[i] = screenTask.label(LEFT, y, 20, HEIGHT, string.format("%i.", i))
    
    local s = screenTask.timer(LEFT + 30, y, 60, HEIGHT, 0, nil)
    s.disabled = true
    s.value = "- - -"
    screenTask.scores[i] = s

    -- Modify timer's draw function to insert score value
    local draw = s.draw
    function s.draw(idx)
      if i > #scores then 
        screenTask.scores[i].value = " -   -   -"
      else
        screenTask.scores[i].value = scores[i]
      end
      
      draw(idx)
    end
    
    y = y + dy
  end
  
  -- Add center buttons
  local x = (LCD_W - BUTTON_W) / 2
  local y = TOP
  screenTask.buttonQR = screenTask.toggleButton(x, y, BUTTON_W, HEIGHT, "QR", false, nil)
  y = y + LINE
  screenTask.buttonEoW = screenTask.toggleButton(x, y, BUTTON_W, HEIGHT, "EoW", true, nil)
  
  local function callBack(button)
    if state <= STATE_PAUSE then
      GotoState(STATE_WINDOW)
    
    elseif state == STATE_WINDOW then
      GotoState(STATE_PAUSE)
    
    elseif state >= STATE_COMMITTED then
      -- Record a zero score!
      flightTime = 0
      Score()
      
      -- Change state
      if winTimer <= 0 or (finalScores and #scores == taskScores) or launches == 0 then
        GotoState(STATE_FINISHED)
      else
        playTone(440, 333, PLAY_NOW)
        GotoState(STATE_WINDOW)
      end
    end
  end
  
  y = y + LINE
  screenTask.button3 = screenTask.button(x, y, BUTTON_W, HEIGHT, "Start", callBack)
  
  -- Info text label
  y = y + LINE
  screenTask.labelInfo = screenTask.label(RGT - 250, y, 250, HEIGHT, "", libGUI.flags + RIGHT)
  
  -- Add timers
  y = TOP
  screenTask.labelTimer0 = screenTask.label(RGT - 160, y, 50, HEIGHT2, "Target:", MIDSIZE)
  y = y + LINE2
  screenTask.timer0 = screenTask.timer(RGT - 160, y, 160, HEIGHT, 0, nil, XXLSIZE + RIGHT)
  screenTask.timer0.disabled = true
  
  y = y + LINE
  screenTask.label(RGT - 160, y, 50, HEIGHT2, "Task:", MIDSIZE)
  y = y + LINE2
  local tmr = screenTask.timer(RGT - 160, y, 160, HEIGHT, 1, nil, XXLSIZE + RIGHT)
  tmr.disabled = true
  
-- Short press EXIT handler must prompt to save scores
  local function HandleEXIT(event, touchState)
    if CanPopGUI() then
      screenTask.buttonRet.callBack()
      return false
    else
      return event
    end
  end
  screenTask.SetEventHandler(EVT_VIRTUAL_EXIT, HandleEXIT)
end

do -- Prompt asking to save scores and exit task window
  local x0 = (LCD_W - PROMPT_W) / 2
  local y0 = (LCD_H - PROMPT_H) / 2
  local LEFT = x0 + PROMPT_M
  local RGT = x0 + PROMPT_W - PROMPT_M
  local TOP = y0 + PROMPT_M
  local BOTTOM = y0 + PROMPT_H - PROMPT_M
  
  function promptSaveScores.fullScreenRefresh()
    lcd.drawFilledRectangle(x0, y0, PROMPT_W, PROMPT_H, COLOR_THEME_PRIMARY2, 2)
    lcd.drawRectangle(x0, y0, PROMPT_W, PROMPT_H, COLOR_THEME_PRIMARY1, 3)
  end

  promptSaveScores.label(x0, TOP, PROMPT_W, HEIGHT, "Save scores?", libGUI.flags + CENTER)

  local function callBack(button)
    if button == promptSaveScores.buttonYes then
      local scoreFile = io.open(SCORE_FILE, "a")
      if scoreFile then
        io.write(scoreFile, string.format("%s,%s", model.getInfo().name, screenTask.title))

        local now = getDateTime()				
        io.write(scoreFile, string.format(",%04i-%02i-%02i", now.year, now.mon, now.day))
        io.write(scoreFile, string.format(",%02i:%02i", now.hour, now.min))				
        io.write(scoreFile, string.format(",s,%i", taskScores))
        io.write(scoreFile, string.format(",%i", totalScore))
        
        for i = 1, #scores do
          io.write(scoreFile, string.format(",%i", scores[i]))
        end
        
        io.write(scoreFile, "\n")
        io.close(scoreFile)
      end
    end
    
    -- Dismiss prompt and return to menu
    screenTask.prompt = nil
    screenTask.dismiss()
  end -- callBack(...)

  promptSaveScores.buttonYes = promptSaveScores.button(LEFT, BOTTOM - HEIGHT, BUTTON_W, HEIGHT, "Yes", callBack)
  promptSaveScores.button(RGT - BUTTON_W, BOTTOM - HEIGHT, BUTTON_W, HEIGHT, "No", callBack)

end

do -- Setup score browser screen
  local RECORD_H = 58     -- Height of a record on the screen
  local records           -- Score records
  local firstRecord       -- First record on the screen
  local scoreFile         -- File handle
  local pos               -- Read position in file
  local firstRecordTouch  -- First record at the start of touch slide
  
  -- Read a line of a log file
  local function ReadLine(scoreFile, pos)
    if scoreFile and pos then
      io.seek(scoreFile, pos)
      local str = io.read(scoreFile, 100)
      local endPos = string.find(str, "\n")

      if endPos then
        pos = pos + endPos
        str = string.sub(str, 1, endPos - 1)
        return pos, str
      end
    end
    
    -- No "\n" was found; return nothing
    return 0, ""
  end  --  ReadLine()

  -- Read a line a split comma separated fields
  local function ParseLineData(str)
    local i = 0
    local record = { }
    record.scores = { }

    for field in string.gmatch(str, "[^,]+") do
      i = i + 1
      
      if i == 1 then
        record.planeName = field
      elseif i == 2 then
        record.taskName = field
      elseif i == 3 then
        record.dateStr = field
      elseif i == 4 then
        record.timeStr = field
      elseif i == 5 then
        record.unitStr = field
      elseif i == 6 then
        record.taskScores = tonumber(field)
      elseif i == 7 then
        record.totalScore = tonumber(field)
      else
        record.scores[#record.scores + 1] = tonumber(field)
      end
    end
    
    if record.totalScore then
      records[#records + 1] = record
    end
  end  --  ReadLineData()
  
  local function DrawRecord(i, r)
    local top = 40 + i * RECORD_H
    local left = 200
    local w = (LCD_W - left - 10) / 3
    local record = records[r]
    
    if r % 2 == 0 then
      lcd.drawFilledRectangle(1, top, LCD_W, RECORD_H, COLOR_THEME_SECONDARY2, 6)
    else
      lcd.drawFilledRectangle(1, top, LCD_W, RECORD_H, COLOR_THEME_SECONDARY3, 6)
    end
    
    lcd.drawText(10, top + 6, record.taskName, BOLD)
    lcd.drawText(10, top + 24, record.dateStr .. " " .. record.timeStr, SMLSIZE)
    lcd.drawText(10, top + 36, record.planeName, SMLSIZE)
    
    local x = left
    local y = top + 6
    
    for j = 1, math.min(5, record.taskScores) do
      lcd.drawText(x, y, j .. ".")

      if j > #record.scores then
        lcd.drawText(x + 18, y, " -  -  -")
      elseif record.unitStr == "s" then
        lcd.drawTimer(x + 18, y, record.scores[j])
      else
        lcd.drawText(x + 18, y, record.scores[j] .. record.unitStr)
      end
      
      if j == 3 then
        x = left
        y = top + 30
      else
        x = x + w
      end
    end
    
    lcd.drawText(left + 2 * w, top + 30, "Total: " .. record.totalScore .. record.unitStr)
  end -- DrawRecord

  function menuScores.run(event, touchState)
    local color
    local PROMPT_W = 300
    local PROMPT_H = 200

    if not event then
      drawZone()
      return
    end
  
    -- Bleed out background to make all of the screen readable
    lcd.drawFilledRectangle(0, HEADER, LCD_W, LCD_H - HEADER, options.BgColor, options.BgOpacity)

    -- Top bar
    lcd.drawFilledRectangle(0, 0, LCD_W, HEADER, COLOR_THEME_SECONDARY1)
    lcd.drawText(10, 2, "Score Card", bit32.bor(DBLSIZE, colors.focusText))

    -- Date
    local now = getDateTime()
    local str = string.format("%02i:%02i", now.hour, now.min)
    lcd.drawText(LCD_W - 80, 6, str, RIGHT + MIDSIZE + colors.focusText)    

    if rxBatV == 0 then
      color = COLOR_THEME_DISABLED
    else
      color = colors.focusText
    end
    
    str = string.format("%1.1fV", rxBatV)
    lcd.drawText(LCD_W - 140, 6, str, RIGHT + MIDSIZE + color)
    
    -- Return button
    lcd.drawFilledRectangle(LCD_W - 74, 6, 28, 28, COLOR_THEME_SECONDARY1)
    lcd.drawRectangle(LCD_W - 74, 6, 28, 28, colors.focusText)
    
    for i = -1, 1 do
      lcd.drawLine(LCD_W - 60 + i, 12, LCD_W - 60 + i, 30, SOLID, colors.focusText)
    end
    
    for i = 0, 3 do
      lcd.drawLine(LCD_W - 60 , 10 + i, LCD_W - 50 - i, 20, SOLID, colors.focusText)
      lcd.drawLine(LCD_W - 60 , 10 + i, LCD_W - 70 + i, 20, SOLID, colors.focusText)
    end

    -- Minimize button
    lcd.drawFilledRectangle(LCD_W - 34, 6, 28, 28, COLOR_THEME_SECONDARY1)
    lcd.drawRectangle(LCD_W - 34, 6, 28, 28, colors.focusText)
    for y = 19, 21 do
      lcd.drawLine(LCD_W - 30, y, LCD_W - 10, y, SOLID, colors.focusText)
    end
  
    if event ~= EVT_TOUCH_SLIDE then
      firstRecordTouch = nil
    end
    
    if event == EVT_VIRTUAL_EXIT then
      firstRecord = nil
      PopGUI()
    elseif event == EVT_TOUCH_TAP then
      local x, y = touchState.x, touchState.y
      
      if 6 <= y and y <= 34 then
        if LCD_W - 74 <= x and x <= LCD_W - 40 then
          firstRecord = nil
          PopGUI()
        elseif x >= LCD_W - 34 then
          lcd.exitFullScreen()
        end
      end
    elseif event == EVT_VIRTUAL_PREV then
      firstRecord = math.max(1, firstRecord - 1)
    elseif event == EVT_VIRTUAL_NEXT then
      firstRecord = math.min(#records - 3, firstRecord + 1)
    elseif event == EVT_TOUCH_SLIDE then
      if not firstRecordTouch then
        firstRecordTouch = firstRecord
      end
      local delta = math.floor((touchState.startY - touchState.y) / RECORD_H + 0.5)
      firstRecord = math.max(1, math.min(#records - 3, firstRecordTouch + delta))
    end

    if firstRecord then
      for i = 0, 3 do
        local r = i + firstRecord
        
        if r > #records then
          break
        end
        
        DrawRecord(i, r)
      end
    
    else -- Read score records
      lcd.drawText(LCD_W / 2, LCD_H / 2, "Reading scores ...", VCENTER + CENTER + DBLSIZE + COLOR_THEME_PRIMARY1)      

      if not scoreFile then
        scoreFile = io.open(SCORE_FILE, "r")
        pos = 0
        if scoreFile then
          records = { }
        end
      end
      
      if scoreFile then
        for i = 1, 10 do
          local str
          pos, str = ReadLine(scoreFile, pos)
          ParseLineData(str)
          if pos == 0 then
            io.close(scoreFile)
            firstRecord = math.max(1, #records - 3)
            
            if #records == 0 then
              firstRecord = nil
            end
            
            break
          end
        end
      end
    end
  end -- run(...)
end

-- Initialize stuff
SetupTask("Just Fly!", { 0, -1, 5, false, 0, 2, false })
widget.update(options)

return widget