---------------------------------------------------------------------------
-- SoarETX, loadable component                                           --
--                                                                       --
-- Author:  Jesper Frickmann                                             --
-- Date:    2021-12-18                                                   --
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

local widget = ...
local libGUI = loadGUI()
local gui = libGUI.newGUI()
local colors = libGUI.colors
local title = "Title"

-- Screen drawing constants
local HEADER =   40

function widget.background()
end -- background()

function widget.refresh(event, touchState)
  gui.run(event, touchState)
end -- refresh(...)

-------------------------------- Setup GUI --------------------------------

function gui.widgetRefresh()
  lcd.drawFilledRectangle(6, 4, widget.zone.w - 12, widget.zone.h - 8, colors.focus)
  lcd.drawRectangle(7, 5, widget.zone.w - 14, widget.zone.h - 10, colors.primary2, 1)
  lcd.drawText(widget.zone.w / 2, widget.zone.h / 2, title, CENTER + VCENTER + DBLSIZE + colors.primary2)
end

function gui.fullScreenRefresh()
  -- Top bar
  lcd.drawFilledRectangle(0, 0, LCD_W, HEADER, COLOR_THEME_SECONDARY1)
  lcd.drawText(10, 2, title, bit32.bor(DBLSIZE, colors.primary2))

  -- Bleed out background to make all of the screen readable
  lcd.drawFilledRectangle(0, HEADER, LCD_W, LCD_H - HEADER, WHITE, 10)
end

-- Minimize button
local buttonMin = gui.button(LCD_W - 34, 6, 28, 28, "", function() lcd.exitFullScreen() end)

-- Paint another face on it
local drawMin = buttonMin.draw
function buttonMin.draw(idx)
  drawMin(idx)
  
  lcd.drawFilledRectangle(LCD_W - 34, 6, 28, 28, COLOR_THEME_SECONDARY1)
  lcd.drawRectangle(LCD_W - 34, 6, 28, 28, colors.primary2)
  for y = 19, 21 do
    lcd.drawLine(LCD_W - 30, y, LCD_W - 10, y, SOLID, colors.primary2)
  end
end