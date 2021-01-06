-- JF Logical Switch Swap
-- Timestamp: 2021-01-03
-- Created by Jesper Frickmann

local N = 64 -- Highest switch number to swap
local LS_BASE -- May change with firmware versions - see init()
 -- Add LS_BASE to LS# to get the switch index. E.g. LS1 has LS_BASE + 1; !LS01 has -(LS_BASE + 1)
local FM_BASE -- Same for flight modes. 

local switches = {} -- List of switch data
local activeSwitches = {} -- List of switches
local firstLine = 1 -- Switch displayed on the first line
local selection = 1 -- Selected switch
local moving = false -- Selected switch is being moved

-- We run out of CPU time if finding all dependencies in one go - therefore:
local stage = 1 -- 1:Find dependencies 2:Show warning 3:Run
local iDep = 1 -- Current channel when finding dependencies

-- Transmitter specific
TX_UNKNOWN = 0
TX_X9D = 1 
TX_QX7 = 2

-- Needs to be sync'd with version and radio from files listed under getFieldInfo() in the OpenTX Lua Reference Guide
local sourceNames = {"ail", "ch1", "ch2", "ch3", "ch4", "ch5", "ch6", "ch7", "ch8", "ch9", "ch10", 
	"ch11", "ch12", "ch13", "ch14", "ch15", "ch16", "ch17", "ch18", "ch19", "ch20", "ch21", 
	"ch22", "ch23", "ch24", "ch25", "ch26", "ch27", "ch28", "ch29", "ch30", "ch31", "ch32", 
	"clock", "cyc1", "cyc2", "cyc3", "ele", "gvar1", "gvar2", "gvar3", "gvar4", "gvar5", "gvar6", 
	"gvar7", "gvar8", "gvar9", "input1", "input2", "input3", "input4", "input5", "input6", "input7", 
	"input8", "input9", "input10", "input11", "input12", "input13", "input14", "input15", "input16", 
	"input17", "input18", "input19", "input20", "input21", "input22", "input23", "input24", "input25", 
	"input26", "input27", "input28", "input29", "input30", "input31", "input32", "ls", "ls1", "ls2", 
	"ls3", "ls4", "ls5", "ls6", "ls7", "ls8", "ls9", "ls10", "ls11", "ls12", "ls13", "ls14", "ls15", "ls16", 
	"ls17", "ls18", "ls19", "ls20", "ls21", "ls22", "ls23", "ls24", "ls25", "ls26", "ls27", "ls28", "ls29", 
	"ls30", "ls31", "ls32", "ls33", "ls34", "ls35", "ls36", "ls37", "ls38", "ls39", "ls40", "ls41", "ls42", 
	"ls43", "ls44", "ls45", "ls46", "ls47", "ls48", "ls49", "ls50", "ls51", "ls52", "ls53", "ls54", "ls55", 
	"ls56", "ls57", "ls58", "ls59", "ls60", "ls61", "ls62", "ls63", "ls64", "rs", "rud", "s1", "s2", "s3", 
	"sa", "sb", "sc", "sd", "se", "sf", "sg", "sh", "thr", "timer1", "timer2", "timer3", "trim-ail", 
	"trim-ele", "trim-rud", "trim-thr", "trn1", "trn2", "trn3", "trn4", "trn5", "trn6", "trn7", "trn8", 
	"trn9", "trn10", "trn11", "trn12", "trn13", "trn14", "trn15", "trn16", "tx-voltage" }

local sources = {} -- Table of source ids and names; reverse of getFieldInfo

local switchNames -- Names of physical switches

-- Source types for V1 and V2. We do not mess with V3.
local refTypes = {
	[1] = {1, 3}, 
	[2] = {1, 3}, 
	[3] = {1, 3}, 
	[4] = {1, 3}, 
	[6] = {1, 3}, 
	[7] = {1, 3}, 
	[8] = {2, 2}, 
	[9] = {2, 2}, 
	[10] = {2, 2}, 
	[11] = {2, 0}, 
	[12] = {1, 1}, 
	[13] = {1, 1}, 
	[14] = {1, 1}, 
	[15] = {1, 3}, 
	[16] = {1, 3}, 
	[17] = {0, 0}, 
	[18] = {2, 2}
} -- 0 is unknown, 1 is source, 2 is switch, 3 is number

-- Return descriptive string for reference, if available
local function RefString(i, type)
	if type == 1 then -- Input source
		if i == 0 then
			return "---"
		else
			local name = sources[i]
			
			if name then
				return string.upper(name)
			else
				return "??"
			end
		end
	elseif type == 2 then -- Switch
		if i == 0 then
			return "---"
		elseif i >= 1 and i <= #switchNames then
			return "S" .. switchNames[i]
		elseif i <= -1 and i >= -24 then
			return "!S" .. switchNames[-i]
		elseif i > LS_BASE and i <= LS_BASE + 64 then
			return "LS" .. i - LS_BASE
		elseif i < -LS_BASE and i >= -LS_BASE - 64 then
			return "!LS" .. -i - LS_BASE
		elseif i >= FM_BASE and i <= FM_BASE + 8 then
			return "FM" .. i - FM_BASE
		elseif i <= -FM_BASE and i >= -FM_BASE - 8 then
			return "!FM" .. -i - FM_BASE
		else
			return "??"
		end
	else -- Assuming number value
		return i
	end
end

-- Create a string describing an LS
local function LSstring(iLS)
	local ls = switches[iLS]
	local func = ls.switch.func
	local v1str = RefString(ls.switch.v1, refTypes[func][1])
	local v2str = RefString(ls.switch.v2, refTypes[func][2])
	local str
	
	if func == 1 then -- a=x
		str = v1str .. "=" .. v2str
	elseif func == 2 then -- a~x
		str = v1str .. " ~ " .. v2str
	elseif func == 3 then -- a>x
		str = v1str .. ">" .. v2str
	elseif func == 4 then -- a<x
		str = v1str .. "<" .. v2str
	elseif func == 6 then -- |a|>x
		str = "|" .. v1str .. "|>" .. v2str
	elseif func == 7 then -- |a|<x
		str = "|" .. v1str .. "|<" .. v2str
	elseif func == 8 then -- AND
		str = v1str .. " AND " .. v2str
	elseif func == 9 then -- OR
		str = v1str .. " OR " .. v2str
	elseif func == 10 then -- XOR
		str = v1str .. " XOR " .. v2str
	elseif func == 11 then -- Edge
		str = "Edge(" .. v1str ..")"
	elseif func == 12 then -- a=b
		str = v1str .. "=" .. v2str
	elseif func == 13 then -- a>b
		str = v1str .. ">" .. v2str
	elseif func == 14 then -- a<b
		str = v1str .. "<" .. v2str
	elseif func == 15 then -- d>=x
		str = "d" .. v1str .. ">=" .. v2str
	elseif func == 16 then -- |d|>=x
		str = "|d" .. v1str .. "|>=" .. v2str
	elseif func == 17 then -- Timer
		str = "Timer"
	elseif func == 18 then -- Sticky
		str = "Sticky(" .. v1str .. "," .. v2str ..")"
	else
		return "Unknown!!"
	end

	if ls.switch["and"] ~= 0 then
		str = "(" .. str .. ") AND " .. RefString(ls.switch["and"], 2)
	end
	
	return str
end

-- Find dependencies for a switch
local function FindDependencies(iLS)
	local ls =switches[iLS]
	local src = getFieldInfo("ls" .. iLS).id
	local swi = iLS + LS_BASE
	ls.depV1s = {}
	ls.depV2s = {}
	ls.depANDs = {}
	
	for j, swDep in pairs(switches) do
		local func = swDep.switch.func
		
		if func and func ~= 0 then
			if (refTypes[func][1] == 1 and swDep.switch.v1 == src) or
			   (refTypes[func][1] == 2 and math.abs(swDep.switch.v1) == swi) then
				ls.depV1s[#ls.depV1s + 1] = swDep
			end
			
			if (refTypes[func][2] == 1 and swDep.switch.v2 == src) or
			   (refTypes[func][2] == 2 and math.abs(swDep.switch.v2) == swi) then
				ls.depV2s[#ls.depV2s + 1] = swDep
			end
			
			if math.abs(swDep.switch["and"]) == swi then
				ls.depANDs[#ls.depANDs + 1] = swDep
			end
		end
	end
end -- FindDependencies()

-- Update dependent references to logical switch no iLS
local function UpdateDependents(iLS)
	local ls =switches[iLS]
	local src = getFieldInfo("ls" .. iLS).id
	local swi = iLS + LS_BASE
	
	for j, swDep in pairs(ls.depV1s) do
		if refTypes[swDep.switch.func][1] == 1 then
			swDep.switch.v1 = src
		elseif refTypes[swDep.switch.func][1] == 2 then
			if swDep.switch.v1 > 0 then
				swDep.switch.v1 = swi
			else
				swDep.switch.v1 = -swi
			end
		end
	end
	
	for j, swDep in pairs(ls.depV2s) do
		if refTypes[swDep.switch.func][2] == 1 then
			swDep.switch.v2 = src
		elseif refTypes[swDep.switch.func][2] == 2 then
			if swDep.switch.v2 > 0 then
				swDep.switch.v2 = swi
			else
				swDep.switch.v2 = -swi
			end
		end
	end
	
	for j, swDep in pairs(ls.depANDs) do
		if swDep.switch["and"] > 0 then
			swDep.switch["and"] = swi
		else
			swDep.switch["and"] = -swi
		end
	end
end

-- Rebuild the list of active switches that are displayed and can be moved
local function UpdateActiveSwitches()
	local j = 0
	for i, sw in pairs(switches) do
		if sw.switch.func ~= 0 then
			j = j + 1
			activeSwitches[j] = i
		end
	end
end -- UpdateActiveSwitches()

local function init()
	-- Transmitter specific
	local ver, radio = getVersion()

	if string.find(radio, "x7") then -- Qx7
		tx = TX_QX7
		LS_BASE = 38
		FM_BASE = 105
		switchNames = {
			"A\192", "A-", "A\193",
			"B\192", "B-", "B\193",
			"C\192", "C-", "C\193",
			"D\192", "D-", "D\193",
			"F\192", "F-", "F\193",
			"H\192", "H-", "H\193"
		}
	elseif string.find(radio, "x9d") then -- X9D		
		tx = TX_X9D
		LS_BASE = 50
		FM_BASE = 117 
		switchNames = {
			"A\192", "A-", "A\193",
			"B\192", "B-", "B\193",
			"C\192", "C-", "C\193",
			"D\192", "D-", "D\193",
			"E\192", "E-", "E\193",
			"F\192", "F-", "F\193",
			"G\192", "G-", "G\193",
			"H\192", "H-", "H\193"
		}
	end
	
	-- Read data for all switches
	for i = 1, N do
		-- Empty table to store switch data
		switches[i] = {}
		
		-- switch data
		switches[i].switch = model.getLogicalSwitch(i - 1)
	end
	
	UpdateActiveSwitches()
	
	-- Generate a table of source ids and names
	for i, n in pairs(sourceNames) do
		local s = getFieldInfo(n)
		if s then
			sources[s.id] = s.name
		end
	end
	
	-- Now we can get rid of sourceNames to save memory
	sourceNames = nil
	collectgarbage()
end -- init()

-- Write switches back to OpenTX; both outputs and mix lines
local function WriteSwitches()
	for i, ls in pairs(switches) do
		model.setLogicalSwitch(i - 1, ls.switch)		
	end
end -- WriteSwitches

local function Draw()
	local XDOT = 15
	
	lcd.clear()
	
	for iLine = 1, math.min(8, #activeSwitches - firstLine + 1) do		
		local iAct = iLine + firstLine - 1
		local iLS = activeSwitches[iAct]
		local switch = switches[iLS].switch
		local y0 = 8 * iLine - 7

		-- Drawing attributes for blinking etc.
		local attAct = 0
		local attNbr = 0
		
		if selection == iAct then
			attAct = INVERS
			if moving then
				attNbr = INVERS + BLINK
			end
		end

		-- Draw switch no. and name
		lcd.drawNumber(XDOT, y0, iLS, SMLSIZE + RIGHT + attNbr)
		lcd.drawText(XDOT, y0, ".", SMLSIZE)
		lcd.drawText(XDOT + 4, y0, LSstring(iLS), SMLSIZE + attAct)
	end	
end

local function run(event)
	if stage == 1 then
		FindDependencies(iDep)
		iDep = iDep + 1
		if iDep > 64 then 
			stage = 2 
		end
	elseif stage == 2 then
		if event == EVT_VIRTUAL_ENTER then
			stage = 3
		end
	elseif stage == 3 then
		local iLS = activeSwitches[selection]
		
		-- Handle key events
		if moving then
			-- switch number edited
			if event == EVT_VIRTUAL_ENTER or event == EVT_VIRTUAL_EXIT then
				moving = false
				WriteSwitches()
			elseif event == EVT_VIRTUAL_PREV or event == EVT_VIRTUAL_PREV_REPT then
				if iLS == 1 then
					playTone(3000, 100, 0, PLAY_NOW)
				else
					if selection > 1 and activeSwitches[selection - 1] == iLS - 1 then
						selection = selection - 1
					end
					switches[iLS - 1], switches[iLS] = switches[iLS], switches[iLS - 1]
					UpdateDependents(iLS - 1)
					UpdateDependents(iLS)
				end
			elseif event == EVT_VIRTUAL_NEXT or event == EVT_VIRTUAL_NEXT_REPT then
				if iLS == N then
					playTone(3000, 100, 0, PLAY_NOW)
				else
					if selection < #activeSwitches and activeSwitches[selection + 1] == iLS + 1 then
						selection = selection + 1
					end
					switches[iLS + 1], switches[iLS] = switches[iLS], switches[iLS + 1]
					UpdateDependents(iLS)
					UpdateDependents(iLS + 1)
				end
			end
			
			UpdateActiveSwitches()
		else
			-- No moving; move switch selection
			if event == EVT_VIRTUAL_EXIT then
				-- Quit
				return 1
			elseif event == EVT_VIRTUAL_ENTER then
				moving = true
			elseif event == EVT_VIRTUAL_PREV or event == EVT_VIRTUAL_PREV_REPT then
				if selection == 1 then
					playTone(3000, 100, 0, PLAY_NOW)
				else
					selection = selection - 1 
				end
			elseif event == EVT_VIRTUAL_NEXT or event == EVT_VIRTUAL_NEXT_REPT then
				if selection == #activeSwitches then
					playTone(3000, 100, 0, PLAY_NOW)
				else
					selection = selection + 1
				end
			end
		end

		-- Scroll if necessary
		if selection < firstLine then
			firstLine = selection
		elseif selection - firstLine > 7 then
			firstLine = selection - 7
		end
	end
	
	-- Update the screen
	if stage < 3 then
		local x, att1, att2
		
		if tx == TX_X9D then
			x = 30
			att1 = MIDSIZE
			att2 = 0
		else
			x = 7
			att1 = 0
			att2 = SMLSIZE
		end
		
		lcd.clear()

		lcd.drawText(x, 15, "Disconnect the motor!", att1)
		lcd.drawText(x, 30, "Sudden spikes may occur", att2)
		lcd.drawText(x, 40, "when switches are moved.", att2)
		if stage == 2 then
			lcd.drawText(x, 50, "Press ENTER to proceed.", att2)
		end
	else
		Draw()
	end
	return 0
end

return {init = init, run = run}