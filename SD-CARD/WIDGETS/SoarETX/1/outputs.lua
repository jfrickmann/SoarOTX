---------------------------------------------------------------------------
-- SoarETX outputs configuration widget, loadable part                   --
--                                                                       --
-- Author:  Jesper Frickmann                                             --
-- Date:    2021-12-23                                                   --
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

local widget, soarGlobals =  ...
local libGUI =  loadGUI()
libGUI.flags =  MIDSIZE
local gui
local prompt =  libGUI.newGUI()
local colors =  libGUI.colors
local title =   "Outputs"

local channels                                -- List sub-GUIs for named channels
local focusNamed = 0                          -- Index of sub-GUI in focus
local firstLine = 1                           -- Index of sub-GUI on the first line
local N = 32                                  -- Highest channel number to swap
local MAXOUT = 1500                           -- Maximum output value
local MINDIF = 100                            -- Minimum difference between lower, center and upper values
local SOURCE0 = 	getFieldInfo("ch1").id - 1  -- Base of channel sources

-- Screen drawing constants
local HEADER =   40
local MARGIN =   10
local TOP =      50
local ROW =      38
local HEIGHT =   ROW - 4
local PROMPT_W = 300
local PROMPT_H = 170

-- Setup warning prompt
do
  local left = (LCD_W - PROMPT_W) / 2
  local top = (LCD_H - PROMPT_H) / 2
  
  function prompt.fullScreenRefresh()
    local txt = "Please disable the motor!\n\n" ..
                "Sudden spikes may occur when channels are moved.\n\n" ..
                "Press ENTER to proceed."
    
    lcd.drawFilledRectangle(left, top, PROMPT_W, HEADER, COLOR_THEME_SECONDARY1)
    lcd.drawFilledRectangle(left, top + HEADER, PROMPT_W, PROMPT_H - HEADER, libGUI.colors.primary2)
    lcd.drawRectangle(left, top, PROMPT_W, PROMPT_H, libGUI.colors.primary1, 2)
    lcd.drawText(left + MARGIN, top + HEADER / 2, "W A R N I N G", DBLSIZE + VCENTER + libGUI.colors.primary2)
    lcd.drawTextLines(left + MARGIN, top + HEADER + MARGIN, PROMPT_W - 2 * MARGIN, PROMPT_H - 2 * MARGIN, txt)
  end

  -- Make a dismiss button from a custom element
  local custom = prompt.custom({ }, left + PROMPT_W - HEADER, top, HEADER, HEADER)

  function custom.draw(focused)
    lcd.drawRectangle(left + PROMPT_W - 30, top + 10, 20, 20, libGUI.colors.primary2)
    lcd.drawText(left + PROMPT_W - 20, top + 20, "X", MIDSIZE + CENTER + VCENTER + libGUI.colors.primary2)
    if focused then
      custom.drawFocus(left + PROMPT_W - 30, top + 10, 20, 20)
    end
  end

  function custom.onEvent(event, touchState)
    if event == EVT_VIRTUAL_ENTER then
      gui.dismissPrompt()
    end
  end
end -- Warning prompt

-- Move output channel by swapping with previous or next; direction = -1 or +1
local function MoveOutput(direction, channel)
	local m = { } -- Channel indices
	m[1] = channel.iChannel -- Channel to move
	m[2] = m[1] + direction -- Neighbouring channel to swap
	
	-- Are we at then end?
	if m[2] < 1 or m[2] > N then
		playTone(3000, 100, 0, PLAY_NOW)
		return
	end
	
	local outputs = { } -- List of output tables
	local mixes = { }   -- List of lists of mixer tables

	-- Read channel into tables
	for i = 1, 2 do
		outputs[i] = model.getOutput(m[i] - 1)

		-- Read list of mixer lines
		mixes[i] = { }
		for j = 1, model.getMixesCount(m[i] - 1) do
			mixes[i][j] = model.getMix(m[i] - 1, j - 1)

local mm = m[i]
print("----> Read CH" .. mm .. " MX" .. j)
for k, v in pairs(mixes[i][j]) do
  if type(v) == "boolean" then
    if v then
      print("  " .. k .." = TRUE")
    else
      print("  " .. k .." = FALSE")
    end
  else
    print("  " .. k .." = " .. v)
  end
end

		end
	end
	
	-- Write back swapped data
	for i = 1, 2 do
		model.setOutput(m[i] - 1, outputs[3 - i])

		-- Delete existing mixer lines
		for j = 1, model.getMixesCount(m[i] - 1) do
			model.deleteMix(m[i] - 1, 0)
		end

		-- Write back mixer lines
		for j, mix in pairs(mixes[3 - i]) do
			model.insertMix(m[i] - 1, j - 1, mix)

local mm = m[i]
print("----> Wrote CH" .. mm .. " MX" .. j)
for k, v in pairs(mix) do
  if type(v) == "boolean" then
    if v then
      print("  " .. k .." = TRUE")
    else
      print("  " .. k .." = FALSE")
    end
  else
    print("  " .. k .." = " .. v)
  end
end

		end
	end

	-- Swap sources for the two channels in all mixes
	for i = 1, N do
		local mixes = { }   -- List of mixer tables
		local dirty = false -- If any sources were swapped, then write back data

		-- Read mixer lines and swap sources if they match the two channels being swapped
		for j = 1, model.getMixesCount(i - 1) do
			mixes[j] = model.getMix(i - 1, j - 1)
			if mixes[j].source == m[1] + SOURCE0 then
				dirty = true
				mixes[j].source = m[2] + SOURCE0
			elseif mixes[j].source == m[2] + SOURCE0 then
				dirty = true
				mixes[j].source = m[1] + SOURCE0
			end
		end
		
		-- Do we have to write back data?
		if dirty then
			-- Delete existing mixer lines
			for j = 1, model.getMixesCount(i - 1) do
				model.deleteMix(i - 1, 0)
			end

			-- Write new mixer lines
			for j, mix in pairs(mixes) do
				model.insertMix(i - 1, j - 1, mix)
			end
		end
	end

	-- Update channel GUI(s) on the screen
  channel.iChannel = m[2]
  channel.output = outputs[1]
  local iNamed2 = channel.iNamed + direction
  local channel2 = channels[iNamed2]
	if channel2 and channel2.iChannel == m[2] then
		-- Swapping two named channels!
    channel2.iChannel = m[1]
    channel2.output = outputs[2]
    channels[channel.iNamed], channels[iNamed2] = channel2, channel
    channel.iNamed, channel2.iNamed = iNamed2, channel.iNamed
		gui.moveFocused(direction)
	end
end -- MoveOutput()

local function init()
  -- Start building GUI from scratch
  gui = libGUI.newGUI()
  gui.showPrompt(prompt)

  function gui.fullScreenRefresh()
    -- Top bar
    lcd.drawFilledRectangle(0, 0, LCD_W, HEADER, COLOR_THEME_SECONDARY1)
    lcd.drawText(MARGIN, HEADER / 2 - 2, "Configure   outputs", DBLSIZE + VCENTER + colors.primary2)
    
    -- Row background
    for i = 0, 6 do
      local y = HEADER + i * ROW
      if i % 2 == 1 then
        lcd.drawFilledRectangle(0, y, LCD_W, ROW, COLOR_THEME_SECONDARY2, 2)
      else
        lcd.drawFilledRectangle(0, y, LCD_W, ROW, COLOR_THEME_SECONDARY3, 2)
      end
    end
    
    -- Adjust scroll for channels
    if focusNamed > 0 then
      if focusNamed < firstLine then
        firstLine = focusNamed
      elseif firstLine + 5 < focusNamed then
        firstLine = focusNamed - 5
      end
    end
    focusNamed = 0
  end

  -- Minimize button
  local buttonMin = gui.custom({ }, LCD_W - HEADER, 0, HEADER, HEADER)

  function buttonMin.draw(focused)
    lcd.drawRectangle(LCD_W - 34, 6, 28, 28, colors.primary2)
    lcd.drawFilledRectangle(LCD_W - 30, 19, 20, 3, colors.primary2)

    if focused then
      buttonMin.drawFocus(LCD_W - 34, 6, 28, 28)
    end
  end

  function buttonMin.onEvent(event)
    if event == EVT_VIRTUAL_ENTER then
      lcd.exitFullScreen()
    end
  end

	-- Build the list of named channels, each in their own movable GUI
  do
    local iNamed = 0
    channels = { }
    
    for iChannel = 1, N do
      local output = model.getOutput(iChannel - 1)
      
      if output and output.name ~= "" then
        local channel = gui.gui(2, LCD_H, LCD_W - 4, HEIGHT)
        local d0

        iNamed = iNamed + 1
        channels[iNamed] = channel
        channel.iNamed = iNamed
        channel.iChannel = iChannel

        -- Hack the sub-GUI's draw function to do a few extra things
        local draw = channel.draw
        function channel.draw(focused)
          if focused then
            focusNamed = channel.iNamed
          end
          if channel.iNamed < firstLine or channel.iNamed > firstLine + 5 then
            channel.y = LCD_H
          else
            channel.y = HEADER + (channel.iNamed - firstLine) * ROW + 2
            draw(focused)
          end
        end

        -- Custom element for changing output channel (and moving all mixer lines etc.)
        local nbrChannel = channel.custom({ }, 0, 0, 30, HEIGHT)        
        
        function nbrChannel.draw(focused)
          local fg = libGUI.colors.primary1
          if focused then
            nbrChannel.drawFocus(0, 0, 30, HEIGHT)
            if channel.editing then
              fg = libGUI.colors.primary2
              channel.drawFilledRectangle(0, 0, 30, HEIGHT, libGUI.colors.edit)
            end
          end
          channel.drawNumber(30, HEIGHT / 2, channel.iChannel, libGUI.flags + VCENTER + RIGHT + fg)
        end

        function nbrChannel.onEvent(event, touchState)
          if channel.editing then
            if libGUI.match(event, EVT_VIRTUAL_ENTER, EVT_VIRTUAL_EXIT) then
              channel.editing = false
            elseif event == EVT_VIRTUAL_INC then
              MoveOutput(1, channel)
            elseif event == EVT_VIRTUAL_DEC then
              MoveOutput(-1, channel)
            elseif event == EVT_TOUCH_FIRST then
              d0 = 0
            elseif event == EVT_TOUCH_SLIDE and channel.scrolling then
              local d = math.floor((touchState.y - touchState.startY) / ROW + 0.5)
              if d ~= d0 then
                MoveOutput(d - d0, channel)
                d0 = d
              end
            end
          elseif event == EVT_VIRTUAL_ENTER then
            channel.editing = true
          end
        end -- onEvent(...)
      
        -- Label for channel name
        local lblName = channel.label(30, 0, 140, HEIGHT, ". " .. output.name)
        
        -- Custom element to invert output direction
        local revert = channel.custom({ }, 170, 0, 30, HEIGHT)
        
        function revert.draw(focused)
          local y = HEIGHT / 2 + 1
          if output.revert == 1 then
            channel.drawFilledRectangle(176, y - 1, 19, 3, colors.primary1)
            for x = 175, 178 do
              channel.drawLine(x, y, x + 8, y - 8, SOLID, colors.primary1)
              channel.drawLine(x, y, x + 8, y + 8, SOLID, colors.primary1)
            end
          else
            channel.drawFilledRectangle(175, y - 1, 19, 3, colors.primary1)
            for x = 192, 195 do
              channel.drawLine(x, y, x - 8, y - 8, SOLID, colors.primary1)
              channel.drawLine(x, y, x - 8, y + 8, SOLID, colors.primary1)
            end
          end
          
          function revert.onEvent(event, touchState)
            if event == EVT_VIRTUAL_ENTER then
              output.revert = 1 - output.revert
              model.setOutput(channel.iChannel - 1, output)
            end
          end

          if focused then
            revert.drawFocus(170, 0, 30, HEIGHT)
          end
        end

        -- Custom element to adjust center and end points
  --[[
  out.offset
  out.min
  out.max
  ]]--
      end
    end
  end
end -- init()

function widget.refresh(event, touchState)
  if not event then
    gui = nil
    lcd.drawFilledRectangle(6, 4, widget.zone.w - 12, widget.zone.h - 8, colors.focus)
    lcd.drawRectangle(7, 5, widget.zone.w - 14, widget.zone.h - 10, colors.primary2, 1)
    lcd.drawText(widget.zone.w / 2, widget.zone.h / 2, title, CENTER + VCENTER + DBLSIZE + colors.primary2)
    return
  elseif gui == nil then
    init()
  end
  
  gui.run(event, touchState)
end -- refresh(...)

function widget.background()
  gui = nil
end -- background()

-----------------------------------------------------------------------------------------------------
-- JF Channel configuration
-- Timestamp: 2021-01-03
-- Created by Jesper Frickmann
--[[
local function Draw()
	soarUtil.InfoBar(MENUTXT)
	
	-- Draw vertical reference lines
	for i = -6, 6 do
		local x = CTR - i * MAXOUT * SCALE / 6
		lcd.drawLine(x, 8, x, LCD_H, DOTTED, FORCE)
	end

	for iLine = 1, math.min(6, #namedChs - firstLine + 1) do		
		local iNamed = iLine + firstLine - 1
		local iChannel = namedChs[iNamed]
		local out = model.getOutput(iChannel - 1)
		local x0 = CTR + SCALE * out.offset
		local x1 = CTR + SCALE * out.min
		local x2 = CTR + SCALE * out.max
		local y0 = 1 + 9 * iLine

		-- Drawing attributes for blinking etc.
		local attName = 0
		local attCh = 0
		local attDir = 0
		local attCtr = 0
		local attLwr = 0
		local attUpr = 0
		
		if selection == iNamed then
			attName = INVERS
			if editing == 1 then
				attCh = INVERS
			elseif editing == 2 then
				attDir = INVERS
			elseif editing == 3 then
				attCtr = INVERS
				attLwr = INVERS
				attUpr = INVERS
			elseif editing == 4 then
				attLwr = INVERS
				attUpr = INVERS
			elseif editing == 5 then
				attLwr = INVERS
			elseif editing == 6 then
				attCtr = INVERS
			elseif editing == 7 then
				attUpr = INVERS
			elseif editing == 11 then
				attCh = INVERS + BLINK
			elseif editing == 13 then
				attCtr = INVERS + BLINK
				attLwr = INVERS + BLINK
				attUpr = INVERS + BLINK
			elseif editing == 14 then
				attLwr = INVERS + BLINK
				attUpr = INVERS + BLINK
			elseif editing == 15 then
				attLwr = INVERS + BLINK
			elseif editing == 16 then
				attCtr = INVERS + BLINK
			elseif editing == 17 then
				attUpr = INVERS + BLINK
			end
		end

		-- Draw channel no. and name
		lcd.drawNumber(XDOT, y0, iChannel, RIGHT + attCh)
		lcd.drawText(XDOT + 4, y0, out.name, attName)
		lcd.drawText(XDOT, y0, ".")
		
		-- Channel direction indicator
		if out.revert == 1 then
			lcd.drawText(XREV, y0, "<", attDir)
		else
			lcd.drawText(XREV, y0, ">", attDir)
		end

		-- Draw markers
		if bit32.btest(attCtr, BLINK) then
			lcd.drawNumber(x0 - 8, y0 + 4, out.offset, PREC1 + SMLSIZE)
		end
		lcd.drawText(x0, y0, "|", SMLSIZE + attCtr)
		
		if bit32.btest(attLwr, BLINK) then
			lcd.drawNumber(x1 - 10, y0 + 4, out.min, PREC1 + SMLSIZE)
		end
		lcd.drawText(x1, y0, "|", SMLSIZE + attLwr)
		
		if bit32.btest(attUpr, BLINK) then
			lcd.drawNumber(x2 - 6, y0 + 4, out.max, PREC1 + SMLSIZE)
		end
		lcd.drawText(x2, y0, "|", SMLSIZE + attUpr)

		-- Draw horizontal channel range lines
		lcd.drawLine(x1, y0 + 2, x2, y0 + 2, SOLID, FORCE)
		lcd.drawLine(x1, y0 + 3, x2, y0 + 3, SOLID, FORCE)
		
		-- And current position inducator
		x0 = getValue(SOURCE0 + iChannel)
		if x0 >= 0 then
			x0 = out.offset + math.min(x0, 1024) * (out.max - out.offset) / 1024 
		else
			x0 = out.offset + math.max(x0, -1024) * (out.offset - out.min) / 1024 
		end

		x0 = CTR + SCALE * x0
		lcd.drawLine(x0, y0 + 1, x0, y0 + 1, SOLID, FORCE)
		lcd.drawLine(x0 - 1, y0, x0 + 1, y0, SOLID, FORCE)
		lcd.drawLine(x0 - 2, y0 - 1, x0 + 2, y0 - 1, SOLID, FORCE)
	end
end

local function run(event)
	-- Update the screen
	if stage == 1 then
		soarUtil.InfoBar(" Warning! ")

		lcd.drawText(XTXT, 12, "Disconnect the motor!", ATT1)
		lcd.drawText(XTXT, 28, "Sudden spikes may occur", ATT2)
		lcd.drawText(XTXT, 38, "when channels are moved.", ATT2)
		lcd.drawText(XTXT, 48, "Press ENTER to proceed.", ATT2)
	else
		Draw()
	end

	if stage == 1 then
		if event == EVT_VIRTUAL_ENTER then
			stage = 2
		elseif event == EVT_VIRTUAL_EXIT then
			return true -- Quit
		end
	elseif stage == 2 then
		local iChannel
		local out
	
		if editing > 1 then
			iChannel = namedChs[selection]
			out = model.getOutput(iChannel - 1)
		end
		
		-- Handle key events
		if editing == 0 then
			-- No editing; move channel selection
			if event == EVT_VIRTUAL_EXIT then
				return true -- Quit
			elseif event == EVT_VIRTUAL_ENTER then
				editing = 1
			elseif event == EVT_VIRTUAL_PREV or event == EVT_VIRTUAL_PREV_REPT then
				if selection == 1 then
					playTone(3000, 100, 0, PLAY_NOW)
				else
					selection = selection - 1
				end
			elseif event == EVT_VIRTUAL_NEXT or event == EVT_VIRTUAL_NEXT_REPT then
				if selection == #namedChs then
					playTone(3000, 100, 0, PLAY_NOW)
				else
					selection = selection + 1
				end
			end
			
			soarUtil.ShowHelp({enter = "EDIT", exit = "EXIT", ud = "SELECT CH." })
			
		elseif editing == 2 then
			-- Editing direction
			if event == EVT_VIRTUAL_ENTER then
				out.revert = 1 - out.revert
				model.setOutput(iChannel - 1, out)
			elseif event == EVT_VIRTUAL_PREV or event == EVT_VIRTUAL_PREV_REPT then
				editing = 1
			elseif event == EVT_VIRTUAL_NEXT or event == EVT_VIRTUAL_NEXT_REPT then
				editing = 3
			elseif event == EVT_VIRTUAL_EXIT then
				editing = 0
			end
			
			soarUtil.ShowHelp({enter = "REVERSE", exit = "BACK", lr = "SELECT PAR." })
			
		elseif editing <= 7 then
			-- Item(s) selected, but not edited
			if event == EVT_VIRTUAL_ENTER then
				-- Start editing
				editing = editing + 10
			elseif event == EVT_VIRTUAL_PREV or event == EVT_VIRTUAL_PREV_REPT then
				editing = editing - 1
				if editing < 1 then editing = 7 end
			elseif event == EVT_VIRTUAL_NEXT or event == EVT_VIRTUAL_NEXT_REPT then
				editing = editing + 1
				if editing > 7 then editing = 1 end
			elseif event == EVT_VIRTUAL_EXIT then
				editing = 0
			end
			
			soarUtil.ShowHelp({enter = "EDIT", exit = "BACK", lr = "SELECT PAR." })
			
		elseif editing == 11 then
			-- Channel number edited
			if event == EVT_VIRTUAL_ENTER or event == EVT_VIRTUAL_EXIT then
				editing = 1
			elseif event == EVT_VIRTUAL_PREV or event == EVT_VIRTUAL_PREV_REPT then
				return MoveSelected(-1)
			elseif event == EVT_VIRTUAL_NEXT or event == EVT_VIRTUAL_NEXT_REPT then
				return MoveSelected(1)
			end
			
			soarUtil.ShowHelp({enter = "BACK", exit = "BACK", ud = "MOVE" })
			
		elseif editing >= 13 then
			local delta = 0
			
			if event == EVT_VIRTUAL_ENTER or event == EVT_VIRTUAL_EXIT then
				editing = editing - 10
			elseif event == EVT_VIRTUAL_INC_REPT then
				delta = 10
			elseif event == EVT_VIRTUAL_INC then
				delta = 1
			elseif event == EVT_VIRTUAL_DEC_REPT  then
				delta = -10
			elseif event == EVT_VIRTUAL_DEC then
				delta = -1
			end
			
			
			soarUtil.ShowHelp({enter = "BACK", exit = "BACK", ud = "CHANGE" })
			
			if editing == 13 then
				-- Lower, Center, Upper edited
				if delta > 0 then
					delta = math.max(0, math.min(delta, 0 - out.min, 1000 - out.offset, MAXOUT - out.max))
				else
					delta = math.min(0, math.max(delta, -MAXOUT - out.min, -1000 - out.offset, 0 - out.max))
				end
				
				out.min = out.min + delta
				out.offset = out.offset + delta
				out.max = out.max + delta
			elseif editing == 14 then
				-- Range edited
				if delta > 0 then
					delta = math.max(0, math.min(delta, MAXOUT + out.min, MAXOUT - out.max))
				else
					delta = math.min(0, math.max(delta, out.min, -out.offset + out.min + MINDIF, 0 - out.max, out.offset - out.max + MINDIF))
				end

				out.max = out.max + delta
				out.min = out.min - delta
			elseif editing == 15 then
				-- Lower limit
				if delta > 0 then
					delta = math.max(0, math.min(delta, 0 - out.min, out.offset - out.min - MINDIF))
				else
					delta = math.min(0, math.max(delta, -MAXOUT - out.min))
				end
				out.min = out.min + delta
			elseif editing == 16 then
				-- Center value
				if delta > 0 then
					delta = math.max(0, math.min(delta, 1000 - out.offset, out.max - out.offset - MINDIF))
				else
					delta = math.min(0, math.max(delta, -1000 - out.offset, out.min - out.offset + MINDIF))
				end
				out.offset = out.offset + delta
			else
				-- Upper limit
				if delta > 0 then
					delta = math.max(0, math.min(delta, MAXOUT - out.max))
				else
					delta = math.min(0, math.max(delta, 0 - out.max, out.offset - out.max + MINDIF))
				end
				out.max = out.max + delta
			end

			model.setOutput(iChannel - 1, out)
		end

		-- Scroll if necessary
		if selection < firstLine then
			firstLine = selection
		elseif selection - firstLine > 5 then
			firstLine = selection - 5
		end
	end
end

return {init = init, run = run}
]]--