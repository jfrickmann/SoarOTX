-- JF Channel configuration
-- Timestamp: 2021-01-03
-- Created by Jesper Frickmann

local N = 32 -- Highest channel number to swap
local MAXOUT = 1500 -- Maximum output value
local MINDIF = 100 -- Minimum difference between lower, center and upper values

local namedChs = {} -- List of named channels
local firstLine = 1 -- Named channel displayed on the first line
local selection = 1 -- Selected named channel
local srcBase = 	getFieldInfo("ch1").id - 1 -- ASSUMING that channel sources are consecutive!
local stage = 1 -- 1:Show warning 2:Run

 -- Screen size specific variables
local 	MENUTXT, XDOT, XREV, CENTER, SCALE, XTXT, ATT1, ATT2 = soarUtil.LoadWxH("JF/CHANNELS.lua")

local editing = 0 
--[[ Selected channel is being edited
	0 = Not edited
	1 = Channel no. selected
	2 = Direction selected
	3 = Lower, Center, Upper selected
	4 = Range selected
	5 = Lower selected
	6 = Center selected
	7 = Upper selected
	11 = Channel no. edited
	13 = Lower, Center, Upper edited
	14 = Range edited
	15 = Lower edited
	16 = Center edited
	17 = Upper edited
]]

local function init()
	-- Build the list of named channels that are displayed and can be moved
	local j = 0
	
	for i = 1, N do
		local out = model.getOutput(i - 1)
		
		if out and out.name ~= "" then
			j = j + 1
			namedChs[j] = i
		end
	end
end -- init()

-- Swap two channels, direction = -1 or +1
local function MoveSelected(direction)
	local m = {} -- Channel indices
	m[1] = namedChs[selection] -- Channel to move
	m[2] = m[1] + direction -- Neighbouring channel to swap
	
	-- Are we at then end?
	if m[2] < 1 or m[2] > N then
		playTone(3000, 100, 0, PLAY_NOW)
		return
	end
	
	local out = {} -- List of output tables
	local mixes = {} -- List of lists of mixer tables

	-- Read channel into tables
	for i = 1, 2 do
		out[i] = model.getOutput(m[i] - 1)

		-- Read list of mixer lines
		mixes[i] = {}
		for j = 1, model.getMixesCount(m[i] - 1) do
			mixes[i][j] = model.getMix(m[i] - 1, j - 1)
		end
	end
	
	-- Write back swapped data
	for i = 1, 2 do
		model.setOutput(m[i] - 1, out[3 - i])

		-- Delete existing mixer lines
		for j = 1, model.getMixesCount(m[i] - 1) do
			model.deleteMix(m[i] - 1, 0)
		end

		-- Write back mixer lines
		for j, mix in pairs(mixes[3 - i]) do
			model.insertMix(m[i] - 1, j - 1, mix)
		end
	end

	-- Swap sources for the two channels in all mixes
	for i = 1, N do
		local mixes = {} -- List of mixer tables
		local dirty = false -- If any sources were swapped, then write back data

		-- Read mixer lines and swap sources if they match the two channels being swapped
		for j = 1, model.getMixesCount(i - 1) do
			mixes[j] = model.getMix(i - 1, j - 1)
			if mixes[j].source == m[1] + srcBase then
				dirty = true
				mixes[j].source = m[2] + srcBase
			elseif mixes[j].source == m[2] + srcBase then
				dirty = true
				mixes[j].source = m[1] + srcBase
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

	-- Update selection on screen
	if namedChs[selection + direction] and namedChs[selection + direction] == m[2] then
		-- Swapping two named channels?
		selection = selection + direction
	else
		-- Swapping named channel with unnamed, invisible channel
		namedChs[selection] = m[2]
	end
end -- SwapChannels()

local function Draw()
	soarUtil.InfoBar(MENUTXT)
	
	-- Draw vertical reference lines
	for i = -6, 6 do
		local x = CENTER - i * MAXOUT * SCALE / 6
		lcd.drawLine(x, 8, x, LCD_H, DOTTED, FORCE)
	end

	for iLine = 1, math.min(6, #namedChs - firstLine + 1) do		
		local iNamed = iLine + firstLine - 1
		local iCh = namedChs[iNamed]
		local out = model.getOutput(iCh - 1)
		local x0 = CENTER + SCALE * out.offset
		local x1 = CENTER + SCALE * out.min
		local x2 = CENTER + SCALE * out.max
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
		lcd.drawNumber(XDOT, y0, iCh, RIGHT + attCh)
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
		x0 = getValue(srcBase + iCh)
		if x0 >= 0 then
			x0 = out.offset + math.min(x0, 1024) * (out.max - out.offset) / 1024 
		else
			x0 = out.offset + math.max(x0, -1024) * (out.offset - out.min) / 1024 
		end

		x0 = CENTER + SCALE * x0
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
		local iCh
		local out
	
		if editing > 1 then
			iCh = namedChs[selection]
			out = model.getOutput(iCh - 1)
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
				model.setOutput(iCh - 1, out)
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

			model.setOutput(iCh - 1, out)
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