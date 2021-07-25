---------------------------------------------------------------------------
-- The dynamically loadable part of the shared Lua GUI library.          --
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

local lib = { }

-- Return true if the first arg matches any of the following args
local function match(x, ...)
  for i, y in ipairs({...}) do
    if x == y then
      return true
    end
  end
  return false
end

lib.match = match

-- Create a new GUI object with interactive screen elements
-- The following variables can be set by the client:
--> widgetRefresh = function; refresh screen in non-fullscreen mode
--> flags = lcd flags; will be used as defaults for drawing text and numbers

function lib.newGUI()
  local gui = { }
  gui.flags = 0
  local handlers = { }
  local elements = { }
  local focus = 1
  local edit = false

  -- Draw a rectangle with pattern lines
  local function drawRectangle(x, y, w, h, pat, flags)
    lcd.drawLine(x, y, x + w, y, pat, flags)
    lcd.drawLine(x + w, y, x + w, y + h, pat, flags)
    lcd.drawLine(x + w, y + h, x, y + h, pat, flags)
    lcd.drawLine(x, y + h, x, y, pat, flags)
  end
  
  -- Adjust text according to horizontal alignment
  local function align(x, w, flags)
    if bit32.band(flags, RIGHT) == RIGHT then
      return x + w - 2
    elseif bit32.band(flags, CENTER) == CENTER then
      return x + w / 2
    else
      return x + 2
    end
  end
  
  -- Move focus to another element
  local function moveFocus(delta)
    local count = 0 -- Prevent infinite loop
    repeat
      focus = focus + delta
      if focus > #elements then
        focus = 1
      elseif focus < 1 then
        focus = #elements
      end
      count = count + 1
    until not elements[focus].noFocus or count > #elements
  end -- moveFocus(...)
  
  -- Add an element and return it to the client
  local function addElement(element, x, y, w, h)
    local idx = #elements + 1
    
    local function covers(p, q)
      return (x <= p and p <= x + w and y <= q and q <= y + h)
    end
    
    if not element.covers then
      element.covers = covers
    end
    elements[idx] = element
    return element
  end -- addElement(...)
  
  -- Set a handler for event (if no element is being edited)
  gui.setHandler = function(event, f)
    table.insert(handlers, {event, f} )
  end -- setHandler
  
--  Public GUI interface starts here.
--> fullScreenRefresh = function
--> element.noFocus prevents element from taking focus
  
-- Run an event cycle
  function gui.run(event, touchState)
    if not event then -- widget mode; event == nil
      if gui.widgetRefresh then
        gui.widgetRefresh()
      else
        lcd.drawText(1, 1, "No widget refresh")
        lcd.drawText(1, 25, "function was loaded.")
      end
    else -- full screen mode; event is a value
      if elements[focus].noFocus then
        moveFocus(1)
        return
      end
      if gui.fullScreenRefresh then
        gui.fullScreenRefresh(event, touchState)
      end
      for idx, element in ipairs(elements) do
        element.draw(idx)
      end
      if event ~= 0 then -- non-zero event; process it
        if edit then -- Send the event to the element being edited
          -- Unless the finger missed the target!
          if match(event, EVT_TOUCH_FIRST, EVT_TOUCH_BREAK, EVT_TOUCH_TAP) then
            if not elements[focus].covers(touchState.x, touchState.y) then
              if event == EVT_TOUCH_TAP then
                event = EVT_VIRTUAL_EXIT -- Tap elsewhere to exit
              else
                return
              end
            end
          end
          elements[focus].run(event, touchState)
        else
          -- Is the event being "handled"?
          for i, h in ipairs(handlers) do
            local evt, f = h[1], h[2]
            if event == evt then
              return f()
            end
          end
          -- Move focus or send event to the focused element
          if event == EVT_TOUCH_FIRST then
            for idx, element in ipairs(elements) do
              if element.covers(touchState.x, touchState.y) then
                if not element.noFocus then
                  focus = idx
                end
                break
              end
            end
          elseif event == EVT_VIRTUAL_NEXT then
            moveFocus(1)
          elseif event == EVT_VIRTUAL_PREV then
            moveFocus(-1)
          else
            elements[focus].run(event, touchState)
          end
        end
      end
    end
  end -- run(...)

-- Create a button to trigger a function
  function gui.button (x, y, w, h, title, callBack, flags)
    flags = bit32.bor(flags or gui.flags, CENTER, VCENTER)
    local self = { title = title }
    
    function self.draw(idx)
      local flags = flags
      
      if focus == idx then
        flags = bit32.bor(flags, BOLD)
        drawRectangle(x - 1, y - 1, w + 2, h + 2, DOTTED, HIGHLIGHT_COLOR)
      end
      lcd.drawFilledRectangle(x, y, w, h, FOCUS_BGCOLOR)
      lcd.drawText(x + w / 2, y + h / 2, self.title, bit32.bor(FOCUS_COLOR, flags))
    end
    
    function self.run(event, touchState)
      if match(event, EVT_VIRTUAL_ENTER, EVT_TOUCH_TAP) then
        return callBack(self)
      end
    end
    
    return addElement(self, x, y, w, h)
  end -- button(...)
  
-- Create a toggle button that turns on/off. callBack gets true/false
  function gui.toggleButton(x, y, w, h, title, value, callBack, flags)
    flags = bit32.bor(flags or gui.flags, CENTER, VCENTER)
    local self = { title = title, value = value }

    function self.draw(idx)
      local flags = flags
      local fg = FOCUS_COLOR
      local bg = FOCUS_BGCOLOR

      if self.value then
        fg = DEFAULT_COLOR
        bg = HIGHLIGHT_COLOR 
      end
      
      if focus == idx then
        drawRectangle(x - 1, y - 1, w + 2, h + 2, DOTTED, HIGHLIGHT_COLOR)
        flags = bit32.bor(flags, BOLD)
      end
      lcd.drawFilledRectangle(x, y, w, h, bg)
      lcd.drawText(x + w / 2, y + h / 2, self.title, bit32.bor(fg, flags))
    end
    
    function self.run(event, touchState)
      if match(event, EVT_VIRTUAL_ENTER, EVT_TOUCH_TAP) then
        self.value = not self.value
        return callBack(self)
      end
    end
    
    return addElement(self, x, y, w, h)
  end -- toggleButton(...)
  
-- Create a number that can be edited
  function gui.number(x, y, w, h, value, callBack, flags)
    flags = bit32.bor(flags or gui.flags, VCENTER)
    local self = { value = value, delta = 0 }
    
    function self.draw(idx)
      local fg = DEFAULT_COLOR
      local flags = flags
      
      if focus == idx then
        drawRectangle(x - 1, y - 1, w + 2, h + 2, DOTTED, HIGHLIGHT_COLOR)
        flags = bit32.bor(flags, BOLD)
        if edit then
          fg = FOCUS_COLOR
          lcd.drawFilledRectangle(x, y, w, h, FOCUS_BGCOLOR)
        end
      end
      lcd.drawNumber(align(x, w, flags), y + h / 2, self.value, bit32.bor(fg, flags))
    end
    
    function self.run(event, touchState)
      self.delta = 0
      if match(event, EVT_VIRTUAL_ENTER, EVT_TOUCH_TAP) then
        edit = not edit
      elseif event == EVT_VIRTUAL_EXIT then
        edit = false
      elseif event == EVT_VIRTUAL_INC then
        self.delta = 1
      elseif event == EVT_VIRTUAL_DEC then
        self.delta = -1
      elseif event == EVT_TOUCH_SLIDE then
        self.delta = -touchState.slideY
      end
      if self.delta ~= 0 then
        return callBack(self)
      end
    end
    
    return addElement(self, x, y, w, h)
  end -- number(...)
  
-- Create a text label; cannot be edited
  function gui.label(x, y, w, h, title, flags)
    flags = bit32.bor(flags or gui.flags, VCENTER, DEFAULT_COLOR)
    local self = { title = title, noFocus = true }
    
    function self.draw(idx)
      lcd.drawText(align(x, w, flags), y + h / 2, self.title, flags)
    end

    -- We should not ever run, but just in case...
    function self.run(event, touchState)
      self.noFocus = true
      moveFocus(1)
    end
    
    function self.covers(p, q)
      return false
    end
     
    return addElement(self, x, y, w, h)
  end -- label(...)
  
-- Create a display of current time on timer[tmr]
-- Set timer.value to show a different value
  function gui.timer(x, y, w, h, tmr, callBack, flags)
    flags = bit32.bor(flags or gui.flags, VCENTER)
    local self = { }

    function self.draw(idx)
      local flags = flags
      local fg = DEFAULT_COLOR
      -- self.value overrides the timer value
      local value = self.value or model.getTimer(tmr).value
      
      if focus == idx then
        drawRectangle(x - 1, y - 1, w + 2, h + 2, DOTTED, HIGHLIGHT_COLOR)
        flags = bit32.bor(flags, BOLD)
        if edit then
          fg = FOCUS_COLOR
          lcd.drawFilledRectangle(x, y, w, h, FOCUS_BGCOLOR)
        end
      end
      lcd.drawTimer(align(x, w, flags), y + h / 2, value, bit32.bor(fg, flags))
    end
    
    function self.run(event, touchState)
      if edit then
        if match(event, EVT_VIRTUAL_ENTER, EVT_TOUCH_TAP, EVT_VIRTUAL_EXIT) then
          edit = false
        end
        -- Since there are so many possibilities, we leave it up to the callBack to take action
        return callBack(self, event, touchState)
      else
        edit = match(event, EVT_VIRTUAL_ENTER, EVT_TOUCH_TAP)
      end
    end
    
    return addElement(self, x, y, w, h)
  end -- timer(...)
  
  return gui
end -- gui(...)

return lib

--[[
    function gui.menu(left, top, rowHeight, rowCount, items, callBack, flags)
    items = items or { "EMPTY" }
    flags = bit32.bor(flags or gui.flags, DEFAULT_COLOR)
    local self = { }
    local firstItem = 1 -- Item on first visible line
    local selected = 1

    function self.run(event, touchState)
      local sel = 0
      
      if event == EVT_VIRTUAL_ENTER then
        return callBack(self)
      elseif event == EVT_VIRTUAL_EXIT then
        return true -- Signal menu exit
      elseif event == EVT_VIRTUAL_NEXT then
        selected = selected + 1
        if selected > #items then
          selected = 1
        end
      elseif event == EVT_VIRTUAL_PREV then
        selected = selected - 1
        if selected < 1 then
          selected = #items
        end
      elseif event == EVT_TOUCH_SLIDE then
        local scroll = math.floor(-touchState.slideY / rowHeight + 0.5)
        -- Husk startpunkt!
      elseif event == EVT_TOUCH_TAP then
        -- Hvis tap på selected så callback, ellers select
      end
      
      -- Scroll if necessary
      if selected < firstItem then
        firstItem = selected
      elseif selected - firstItem >= rowCount then
        firstItem = selected - rowCount + 1
      end
      -- Draw
      for line = 1, math.min(rowCount, #items - firstItem + 1) do
        local item = line + firstItem - 1
        local y = top + rowheight * (line - 1)
        local flags = flags

        if item == selected then
          flags = bit32.bor(flags, INVERS)
        end
        lcd.drawText(left, y, items[item], flags)
      end
    end -- run(...)
]]--
