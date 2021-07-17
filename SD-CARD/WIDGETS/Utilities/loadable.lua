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
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         --
-- GNU General Public License for more details.                          --
---------------------------------------------------------------------------
local widget = ... -- The widget table is passed as an argument to chunk()
local util = Utilities(widget.dir)
widget.util = util
local gui = util.GUI()
local border = false
local toggle = ""

local function A()
  border = true
end

local function B()
  border = false
end

local function T(value)
  if value then
    toggle = "ON"
  else
    toggle = "OFF"
  end
end

local function drawFull()
  if border then
    for i = 0, 5 do
      lcd.drawRectangle(i, i, LCD_W - 2 * i, LCD_H - 2 * i, BATTERY_CHARGE_COLOR)
    end
  end

  lcd.drawText(65, 40, "Toggle = " .. toggle)
end

local function drawZone()
  lcd.drawRectangle(0, 0, widget.zone.w, widget.zone.h, BATTERY_CHARGE_COLOR)
  lcd.drawText(5, 5, "GUI test")
end

do -- Initialization happens here
  util.setWidgetRefresh(drawZone)
  gui.setFullScreenRefresh(drawFull)
  
  local a = gui.button(5, 5, 50, 25, "A", A)
  local b = gui.button(65, 5, 50, 25, "B", B)
  local t = gui.toggleButton(5, 35, 50, 25, "T", true, T)
  
  a.title("ON")
  b.title("OFF")
  t.title("Toggle")
end

widget.update = function(options)
end

widget.background = function()
end

widget.refresh = function(event, touchState)
  gui.run(event, touchState)
end

return