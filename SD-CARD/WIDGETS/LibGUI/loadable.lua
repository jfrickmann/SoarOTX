---------------------------------------------------------------------------
-- The dynamically loadable part of the demonstration Lua widget.        --
--                                                                       --
-- Author:  Jesper Frickmann                                             --
-- Date:    2021-XX-XX                                                   --
-- Version: 0.9                                                          --
--                                                                       --
-- Copyright (C) EdgeTX                                                  --
--                                                                       --
-- License GPLv2: http://www.gnu.org/licenses/gpl-2.0.html               --
--                                                                       --
-- This program is free software; you can redistribute it and/or modify  --
-- it under the terms of the GNU General Public License version 2 as     --
-- published by the Free Software Foundation.                            --
--                                                                       --
-- This program is distributed in the hope that it will be useful        --
-- but WITHOUT ANY WARRANTY; without even the implied warranty of        --
-- MERCHANTABILITY or FITNESS FOR borderON PARTICULAR PURPOSE. See the   --
-- GNU General Public License for more details.                          --
---------------------------------------------------------------------------

-- This code chunk is loaded on demand by the LibGUI widget's main script
-- when the create(...) function is run. Hence, the body of this file is
-- executed by the widget's create(...) function.

local zone, options = ... --zone and options were passed as arguments to chunk(...).
local widget = { } -- The widget table will be returned to the main script.

-- Load the GUI library by calling the global function declared in the main script.
-- As long as LibGUI is on the SD card, any widget can call loadGUI() because it is global.
local libGUI = loadGUI()
local gui = libGUI.newGUI() -- Instantiate a new GUI object.
gui.flags = MIDSIZE -- Default flags that are used unless other flags are passed.

-- Local constants and variables:
local LEFT = 10
local TOP = 10
local COL = 150
local ROW = 50
local WIDTH = 120
local HEIGHT = 40
local TMR = 0
local border = false
local labelToggle

-- Called by gui in full screen mode
local function drawFull()
  if border then
    for i = 0, 5 do
      lcd.drawRectangle(i, i, LCD_W - 2 * i, LCD_H - 2 * i, BATTERY_CHARGE_COLOR)
    end
  end
end

-- Called by gui in widget zone mode
local function drawZone()
  lcd.drawRectangle(0, 0, zone.w, zone.h, BATTERY_CHARGE_COLOR)
  lcd.drawText(5, 5, "LibGUI")
end

-- Call back for button "ON"
local function borderON()
  border = true
end

-- Call back for button "OFF"
local function borderOFF()
  border = false
end

-- Call back for toggle button
local function doToggle(toggleButton)
  if toggleButton.value then
    labelToggle.title = "Toggle = ON"
  else
    labelToggle.title = "Toggle = OFF"
  end
end

-- Call back for number
local function numberChange(number)
  -- Scale down slide input
  local d = number.delta
  if math.abs(d) > 1 then
    d = math.floor(0.1 * d + 0.5)
  end
  number.value = number.value + d
end

-- Call back for timer
local function timerChange(timer, event, touchState)
  local d = 0

  if not timer.value then  -- Initialize at first call
    timer.value = model.getTimer(TMR).value
  end
  if libGUI.match(event, EVT_VIRTUAL_ENTER, EVT_TOUCH_TAP) then
    local tmr = model.getTimer(TMR)
    tmr.value = timer.value
    model.setTimer(TMR, tmr)
  elseif event == EVT_VIRTUAL_EXIT then
    timer.value = nil
  elseif event == EVT_VIRTUAL_INC then
    d = 20
  elseif event == EVT_VIRTUAL_DEC then
    d = -20
  elseif event == EVT_TOUCH_SLIDE then
    d = -touchState.slideY
  end
  if d >= 20 then
    timer.value = 60 * math.ceil((timer.value + 1) / 60)
  elseif d <= -20 then
    timer.value = 60 * math.floor((timer.value - 1) / 60)
  end
end

do -- Initialization happens here
  local x = LEFT
  local y = TOP
  
  local function nextCol()
    x = x + COL
  end
  
  local function nextRow()
    x = LEFT
    y = y + ROW
  end
  
  gui.widgetRefresh = drawZone
  gui.fullScreenRefresh = drawFull
  
  gui.button(x, y, WIDTH, HEIGHT, "ON", borderON)
  nextCol()
  gui.button(x, y, WIDTH, HEIGHT, "OFF", borderOFF)
  nextRow()
  gui.toggleButton(x, y, WIDTH, HEIGHT, "Toggle", true, doToggle)
  nextCol()
  labelToggle = gui.label(x, y, WIDTH, HEIGHT, "")
  nextRow()
  gui.label(x, y, WIDTH, HEIGHT, "Number =")
  nextCol()
  gui.number(x, y, WIDTH, HEIGHT, 0, numberChange, bit32.bor(gui.flags, RIGHT))
  nextRow()
  gui.label(x, y, WIDTH, HEIGHT, "Timer =")
  nextCol()
  gui.timer(x, y, WIDTH, HEIGHT, TMR, timerChange, bit32.bor(gui.flags, RIGHT))
end

-- This function is called from the refresh(...) function in the main script
function widget.refresh(event, touchState)
  gui.run(event, touchState)
end

-- Return to the create(...) function in the main script
return widget
