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
-- MERCHANTABILITY or FITNESS FOR turnON PARTICULAR PURPOSE.  See the         --
-- GNU General Public License for more details.                          --
---------------------------------------------------------------------------
local widget = ... -- The widget table is passed as an argument to chunk()
local util = Utilities(widget.dir)
local gui = util.GUI()
util.flags = bit32.bor(MIDSIZE)

local LEFT = 10
local TOP = 10
local COL = 150
local ROW = 60
local WIDTH = 120
local HEIGHT = 40

local border = false
local buttonON, buttonOFF, toggleButton, number, labelToggle, lableNumber

local function drawFull()
  if border then
    for i = 0, 5 do
      lcd.drawRectangle(i, i, LCD_W - 2 * i, LCD_H - 2 * i, BATTERY_CHARGE_COLOR)
    end
  end
end

local function drawZone()
  lcd.drawRectangle(0, 0, widget.zone.w, widget.zone.h, BATTERY_CHARGE_COLOR)
  lcd.drawText(5, 5, "Utilities")
end

local function turnON()
  border = true
end

local function turnOFF()
  border = false
end

local function doToggle(value)
  if value then
    labelToggle.title = "Toggle = ON"
  else
    labelToggle.title = "Toggle = OFF"
  end
end

local function numberChange(d)
  number.value = number.value + d
end

do -- Initialization happens here
  util.widgetRefresh = drawZone
  gui.fullScreenRefresh = drawFull
  
  local x = LEFT
  local y = TOP
  
  local function nc()
    x = x + COL
  end
  
  local function nl()
    x = LEFT
    y = y + ROW
  end
  
  buttonON = gui.button(x, y, WIDTH, HEIGHT, "ON", turnON)
  nc()
  buttonOFF = gui.button(x, y, WIDTH, HEIGHT, "OFF", turnOFF)
  nl()
  toggleButton = gui.toggleButton(x, y, WIDTH, HEIGHT, "Toggle", true, doToggle)
  nc()
  labelToggle = gui.label(x, y, WIDTH, HEIGHT, "")
  nl()
  labelNumber = gui.label(x, y, WIDTH, HEIGHT, "Number =")
  nc()
  number = gui.number(x, y, WIDTH, HEIGHT, 0, numberChange, RIGHT)
end

widget.update = function(options)
end

widget.background = function()
end

widget.refresh = function(event, touchState)
  gui.run(event, touchState)
end

return