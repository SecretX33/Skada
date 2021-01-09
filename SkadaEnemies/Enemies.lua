local L = LibStub("AceLocale-3.0"):GetLocale("Skada", false)

local Skada = Skada

local done = Skada:NewModule(L["Enemy damage done"])
local taken = Skada:NewModule(L["Enemy damage taken"])

local doneplayers = Skada:NewModule(L["Damage done per player"])
local takenplayers = Skada:NewModule(L["Damage taken per player"])

local function find_player(mob, name)
	for i, p in ipairs(mob.players) do
		if p.name == name then
			return p
		end
	end
	
	local player = {name = name, done = 0, taken = 0, class = select(2, UnitClass(name))}
	table.insert(mob.players, player)
	return player
end

local GroupName = {
	["The Lich King"] = "useful targets",
	["Professor Putricide"] = "Oozes",
	["Blood Prince Council"] = "Princes overkilling",
	["Lady Deathwhisper"] = "Adds",
	["Halion"] = "Halion and Inferno",
	["Valkyrs"] = "Valkyrs overkilling",
}

local ValidTarget = {
	["The Lich King"] = "The Lich King", 
	["Raging Spirit"] = "The Lich King",
	["Ice Sphere"] = "The Lich King",
	["Val'kyr Shadowguard"] = "The Lich King",
	["Wicked Spirit"] = "The Lich King",
	
	["Gas Cloud"] = "Professor Putricide",
	["Volatile Ooze"] = "Professor Putricide",
	
	["Prince Valanar"] = "Blood Prince Council",
	["Prince Taldaram"] = "Blood Prince Council",
	["Prince Keleseth"] = "Blood Prince Council",
	
	["Cult Adherent"] = "Lady Deathwhisper",
	["Empowered Adherent"] = "Lady Deathwhisper",
	["Reanimated Adherent"] = "Lady Deathwhisper",
	["Cult Fanatic"] = "Lady Deathwhisper",
	["Deformed Fanatic"] = "Lady Deathwhisper",
	["Reanimated Fanatic"] = "Lady Deathwhisper",
	["Darnavan"] = "Lady Deathwhisper",
	
	["Halion"] = "Halion",
	["Living Inferno"] = "Halion",
	
	--["Val'kyr Shadowguard"] = "Valkyrs",
}

function GetFatRaidDifficulty() 
	local _, instanceType, difficulty, _, _, playerDifficulty, isDynamicInstance = GetInstanceInfo()
	if instanceType == "raid" and isDynamicInstance then -- "new" instance (ICC)
		if difficulty == 1 or difficulty == 3 then -- 10 men
			return playerDifficulty == 0 and "normal10" or playerDifficulty == 1 and "heroic10" or "unknown"
		elseif difficulty == 2 or difficulty == 4 then -- 25 men
			return playerDifficulty == 0 and "normal25" or playerDifficulty == 1 and "heroic25" or "unknown"
		end
	else -- support for "old" instances
		if GetInstanceDifficulty() == 1 then 
			return "normal10"
		elseif GetInstanceDifficulty() == 2 then 
			return "normal25"
		elseif GetInstanceDifficulty() == 3 then 
			return "heroic10" 
		elseif GetInstanceDifficulty() == 4 then 
			return "heroic25" 
		end
	end
end 

local Valk25MaxHP = 2992000
local Valk10MaxHP = 1900000
local Valkyrs = {}

local function log_damage_taken(set, dmg) -- mobs dmg taken
	set.mobtaken = set.mobtaken + dmg.amount
	
	if not set.mobs[dmg.dstName] then
		set.mobs[dmg.dstName] = {taken = 0, done = 0, players = {}}
	end
	
	local mob = set.mobs[dmg.dstName]
	
	mob.taken = mob.taken + dmg.amount
	
	local player = find_player(mob, dmg.srcName)
	player.taken = player.taken + dmg.amount
	
	if ValidTarget[dmg.dstName] then
		
		if not set.mobs[GroupName[ValidTarget[dmg.dstName]]] then
			set.mobs[GroupName[ValidTarget[dmg.dstName]]] = {taken = 0, done = 0, players = {}}
		end
		
		if dmg.dstName == "Val'kyr Shadowguard" then
			local difficulty =  GetFatRaidDifficulty();
			if difficulty == "heroic25" or difficulty == "heroic10" then
				if Valkyrs[dmg.dstGUID] then
					if difficulty == "heroic25" then
						if Valkyrs[dmg.dstGUID] < Valk25MaxHP/2 then 
							if not set.mobs["Valkyrs overkilling"] then
								set.mobs["Valkyrs overkilling"] = {taken = 0, done = 0, players = {}}
							end
	
							set.mobs["Valkyrs overkilling"].taken = set.mobs["Valkyrs overkilling"].taken + dmg.amount;
	
							local uplayer = find_player(set.mobs["Valkyrs overkilling"], dmg.srcName)
							uplayer.taken = uplayer.taken + dmg.amount;
							return 
						end
					else
						if Valkyrs[dmg.dstGUID] < Valk10MaxHP/2 then 
							if not set.mobs["Valkyrs overkilling"] then
								set.mobs["Valkyrs overkilling"] = {taken = 0, done = 0, players = {}}
							end
	
							set.mobs["Valkyrs overkilling"].taken = set.mobs["Valkyrs overkilling"].taken + dmg.amount;
	
							local uplayer = find_player(set.mobs["Valkyrs overkilling"], dmg.srcName)
							uplayer.taken = uplayer.taken + dmg.amount;
							return 
						end
					end
					Valkyrs[dmg.dstGUID] = Valkyrs[dmg.dstGUID] - dmg.amount
				else
					if difficulty == "heroic25" then
						Valkyrs[dmg.dstGUID] = Valk25MaxHP - dmg.amount
					else
						Valkyrs[dmg.dstGUID] = Valk10MaxHP - dmg.amount
					end
				end		
			end	
		end
		
		local add = dmg.amount
		if ValidTarget[dmg.dstName] == "Blood Prince Council" then add = dmg.overkill end
		
		set.mobs[GroupName[ValidTarget[dmg.dstName]]].taken = set.mobs[GroupName[ValidTarget[dmg.dstName]]].taken + add;
		
		local uplayer = find_player(set.mobs[GroupName[ValidTarget[dmg.dstName]]], dmg.srcName)
		uplayer.taken = uplayer.taken + add;
	end
end

local function log_damage_done(set, dmg)
	set.mobdone = set.mobdone + dmg.amount

	if not set.mobs[dmg.srcName] then
		set.mobs[dmg.srcName] = {taken = 0, done = 0, players = {}}
	end
	
	local mob = set.mobs[dmg.srcName]
	
	mob.done = mob.done + dmg.amount
	
	local player = find_player(mob, dmg.dstName)
	player.done = player.done + dmg.amount
end

local dmg = {}

local function SpellDamageTaken(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
	local spellId, spellName, spellSchool, samount, soverkill, sschool, sresisted, sblocked, sabsorbed, scritical, sglancing, scrushing = ...
	if srcName and dstName then
		srcGUID, srcName = Skada:FixMyPets(srcGUID, srcName)
		
		dmg.dstName = dstName
		dmg.srcName = srcName
		dmg.amount = math.max(0,samount - soverkill)
		dmg.overkill = soverkill
		dmg.dstGUID = dstGUID;

		log_damage_taken(Skada.current, dmg)
	end
end

local function SpellDamageDone(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
	local spellId, spellName, spellSchool, samount, soverkill, sschool, sresisted, sblocked, sabsorbed, scritical, sglancing, scrushing = ...
	if srcName and dstName then
		dmg.dstName = dstName
		dmg.srcName = srcName
		dmg.amount = math.max(0,samount - soverkill)
		dmg.overkill = soverkill
		dmg.dstGUID = dstGUID;

		log_damage_done(Skada.current, dmg)
	end
end

local function SwingDamageTaken(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
	local samount, soverkill, sschool, sresisted, sblocked, sabsorbed, scritical, sglancing, scrushing = ...
	if srcName and dstName then
		srcGUID, srcName = Skada:FixMyPets(srcGUID, srcName)
		
		dmg.dstName = dstName
		dmg.srcName = srcName
		dmg.amount = math.max(0,samount - soverkill)
		dmg.overkill = soverkill
		dmg.dstGUID = dstGUID;
		
		log_damage_taken(Skada.current, dmg)
	end
end

local function SwingDamageDone(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
	local samount, soverkill, sschool, sresisted, sblocked, sabsorbed, scritical, sglancing, scrushing = ...
	if srcName and dstName then
		dmg.dstName = dstName
		dmg.srcName = srcName
		dmg.amount = math.max(0,samount - soverkill)
		dmg.overkill = soverkill
		dmg.dstGUID = dstGUID;
		
		log_damage_done(Skada.current, dmg)
	end
end

-- Enemy damage taken - list mobs.
function taken:Update(win, set)
	local nr = 1
	local max = 0
	
	for name, mob in pairs(set.mobs) do
		if mob.taken > 0 then
			local d = win.dataset[nr] or {}
			win.dataset[nr] = d
			
			d.value = mob.taken
			d.id = name
			d.valuetext = Skada:FormatNumber(mob.taken)
			d.label = name
			
			if mob.taken > max then
				max = mob.taken
			end
			
			nr = nr + 1
		end
	end
	
	win.metadata.maxvalue = max
end

function done:Update(win, set)
	local nr = 1
	local max = 0
	
	for name, mob in pairs(set.mobs) do
		if mob.done > 0 then
			local d = win.dataset[nr] or {}
			win.dataset[nr] = d
			
			d.value = mob.done
			d.id = name
			d.valuetext = Skada:FormatNumber(mob.done)
			d.label = name
			
			if mob.done > max then
				max = mob.done
			end
			
			nr = nr + 1
		end
	end
	
	win.metadata.maxvalue = max
end

function doneplayers:Enter(win, id, label)
	doneplayers.title = L["Damage from"].." "..label
	doneplayers.mob = label
end

function doneplayers:Update(win, set)
	if self.mob then
	
		for name, mob in pairs(set.mobs) do
	
			local nr = 1
			local max = 0
	
			if name == self.mob then
				for i, player in ipairs(mob.players) do
					if player.done > 0 then
					
						local d = win.dataset[nr] or {}
						win.dataset[nr] = d
						
						d.id = player.name
						d.label = player.name
						d.value = player.done
						d.valuetext = Skada:FormatNumber(player.done)..(" (%02.1f%%)"):format(player.done / mob.done * 100)
						d.class = player.class
						
						if player.done > max then
							max = player.done
						end
						
						nr = nr + 1
					end
				end
		
				win.metadata.maxvalue = max
		
			end
		end
	end
end

function takenplayers:Enter(win, id, label)
	takenplayers.title = L["Damage on"].." "..label
	takenplayers.mob = label
end

function takenplayers:Update(win, set)
	if self.mob then
		
		-- Look for the chosen mob. We could store a reference here, but that would complicate garbage collecting the data later.
		for name, mob in pairs(set.mobs) do
		
			local nr = 1
			local max = 0
			
			-- Yay, we found it.
			if name == self.mob then
				
				-- Iterations 'R' Us.
				for i, player in ipairs(mob.players) do
					if player.taken > 0 then
					
						local d = win.dataset[nr] or {}
						win.dataset[nr] = d
						
						d.id = player.name
						d.label = player.name
						d.value = player.taken
						d.valuetext = Skada:FormatNumber(player.taken)..(" (%02.1f%%)"):format(player.taken / mob.taken * 100)
						d.class = player.class
						
						if player.taken > max then
							max = player.taken
						end
						
						nr = nr + 1
					end
				end
				
				win.metadata.maxvalue = max
				return
			end
			
		end
	end
end


function done:OnEnable()
	takenplayers.metadata 	= {showspots = true}
	doneplayers.metadata 	= {showspots = true}
	done.metadata 			= {click1 = doneplayers}
	taken.metadata 			= {click1 = takenplayers}

	Skada:RegisterForCL(SpellDamageTaken, 'SPELL_DAMAGE', {src_is_interesting = true, dst_is_not_interesting = true})
	Skada:RegisterForCL(SpellDamageTaken, 'SPELL_PERIODIC_DAMAGE', {src_is_interesting = true, dst_is_not_interesting = true})
	Skada:RegisterForCL(SpellDamageTaken, 'SPELL_BUILDING_DAMAGE', {src_is_interesting = true, dst_is_not_interesting = true})
	Skada:RegisterForCL(SpellDamageTaken, 'RANGE_DAMAGE', {src_is_interesting = true, dst_is_not_interesting = true})
	Skada:RegisterForCL(SwingDamageTaken, 'SWING_DAMAGE', {src_is_interesting = true, dst_is_not_interesting = true})

	Skada:RegisterForCL(SpellDamageDone, 'SPELL_DAMAGE', {dst_is_interesting_nopets = true, src_is_not_interesting = true})
	Skada:RegisterForCL(SpellDamageDone, 'SPELL_PERIODIC_DAMAGE', {dst_is_interesting_nopets = true, src_is_not_interesting = true})
	Skada:RegisterForCL(SpellDamageDone, 'SPELL_BUILDING_DAMAGE', {dst_is_interesting_nopets = true, src_is_not_interesting = true})
	Skada:RegisterForCL(SpellDamageDone, 'RANGE_DAMAGE', {dst_is_interesting_nopets = true, src_is_not_interesting = true})
	Skada:RegisterForCL(SwingDamageDone, 'SWING_DAMAGE', {dst_is_interesting_nopets = true, src_is_not_interesting = true})
	
	Skada:AddMode(self)
end

function done:OnDisable()
	Skada:RemoveMode(self)
end

function taken:OnEnable()
	Skada:AddMode(self)
end

function taken:OnDisable()
	Skada:RemoveMode(self)
end

function done:GetSetSummary(set)
	return Skada:FormatNumber(set.mobdone)
end

function taken:GetSetSummary(set)
	return Skada:FormatNumber(set.mobtaken)
end

-- Called by Skada when a new set is created.
function done:AddSetAttributes(set)
	if not set.mobs then
		set.mobs = {}
		set.mobdone = 0
		set.mobtaken = 0
		set.useful = false;
		Valkyrs = {};
	end
end
