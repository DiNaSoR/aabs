_G.DOTA_DUEL_STATUS_NONE = 0
_G.DOTA_DUEL_STATUS_WATING = 1
_G.DOTA_DUEL_STATUS_IN_PROGRESS = 2
LinkLuaModifier("modifier_duel_hero_disabled_for_duel", "modifiers/modifier_duel_hero_disabled_for_duel.lua", LUA_MODIFIER_MOTION_NONE)
if Duel == nil then
	_G.Duel = class({})
	Duel.TimeUntilDuel = ARENA_SETTINGS.DelayFromGameStart
	Duel.TimeUntilDuelEnd = 0
	Duel.GlobalTimer = nil
	Duel.DuelStatus = DOTA_DUEL_STATUS_NONE
	Duel.EntIndexer = {}
	Duel.Particles = {}
	Duel.DuelCounter = 0
end

function Duel:CreateGlobalTimer()
	Duel.DuelStatus = DOTA_DUEL_STATUS_WATING
	PlayerTables:SetTableValue("arena", "duel_timer", Duel.TimeUntilDuel)
	Duel.GlobalTimer = Timers:CreateTimer(function()
		if Duel.DuelStatus == DOTA_DUEL_STATUS_WATING then
			Duel.TimeUntilDuel = Duel.TimeUntilDuel - 1
			if Duel.TimeUntilDuel <= 0 then
				Duel:StartDuel()
				PlayerTables:SetTableValue("arena", "duel_timer", 0)
			else
				PlayerTables:SetTableValue("arena", "duel_timer", Duel.TimeUntilDuel)
			end
		end
		if Duel.DuelStatus == DOTA_DUEL_STATUS_IN_PROGRESS then
			Duel.TimeUntilDuelEnd = Duel.TimeUntilDuelEnd - 1
			if Duel.TimeUntilDuelEnd <= 0 then
				Duel:EndDuel()
				PlayerTables:SetTableValue("arena", "duel_timer", 0)
			else
				PlayerTables:SetTableValue("arena", "duel_timer", Duel.TimeUntilDuelEnd)
			end
		end
		return 1
	end)

	Physics:RemoveCollider("collider_box_blocker_arena")
	local a1 = Entities:FindByName(nil, "target_mark_arena_blocker_1"):GetAbsOrigin()
	local a2 = Entities:FindByName(nil, "target_mark_arena_blocker_2"):GetAbsOrigin()
	local collider = Physics:AddCollider("collider_box_blocker_arena", Physics:ColliderFromProfile("boxblocker"))
	collider.box = CreateSimpleBox(a1, a2)
	collider.findClearSpace = true
	collider.test = function(self, unit)
		if not IsPhysicsUnit(unit) and unit.IsConsideredHero and unit:IsConsideredHero() then
			Physics:Unit(unit)
		end
		return IsPhysicsUnit(unit) and Duel.DuelStatus == DOTA_DUEL_STATUS_WATING and not unit.InArena
	end
end

function Duel:StartDuel()
	Duel.heroes_teams_for_duel = {}
	local heroes_in_teams_count = {}
	for playerID = 0, DOTA_MAX_TEAM_PLAYERS - 1  do
		if PlayerResource:IsValidPlayerID(playerID) and not IsPlayerAbandoned(playerID) then
			local team = PlayerResource:GetTeam(playerID)
			local hero = PlayerResource:GetSelectedHeroEntity(playerID)
			if IsValidEntity(hero) then
				Duel.heroes_teams_for_duel[team] = Duel.heroes_teams_for_duel[team] or {}
				table.insert(Duel.heroes_teams_for_duel[team], hero)
			end
		end
	end
	for i,v in pairs(Duel.heroes_teams_for_duel) do
		if not heroes_in_teams[i] then heroes_in_teams[i] = 0 end
		for _,vi in pairs(v) do
			if vi:IsAlive() and PlayerResource:GetConnectionState(pid) == DOTA_CONNECTION_STATE_CONNECTED then
				heroes_in_teams[i] = heroes_in_teams[i] + 1
			end
		end
	end
	local heroes_to_fight_n = math.min(unpack(table.iterate(heroes_in_teams)))
	Duel.TimeUntilDuelEnd = ARENA_SETTINGS.DurationBase + ARENA_SETTINGS.DurationForPlayer * heroes_to_fight_n
	if heroes_to_fight_n > 0 and table.count(Duel.heroes_teams_for_duel) > 1 then
		Duel.IsFirstDuel = Duel.DuelCounter == 0
		--[[for _,v in ipairs(Entities:FindAllByName("npc_dota_arena_statue")) do
			local particle1 = ParticleManager:CreateParticle("particles/arena/units/arena_statue/statue_eye.vpcf", PATTACH_ABSORIGIN, v)
			local particle2 = ParticleManager:CreateParticle("particles/arena/units/arena_statue/statue_eye.vpcf", PATTACH_ABSORIGIN, v)
			ParticleManager:SetParticleControlEnt(particle1, 0, v, PATTACH_POINT_FOLLOW, "attach_eye_l", v:GetAbsOrigin(), true)
			ParticleManager:SetParticleControlEnt(particle2, 0, v, PATTACH_POINT_FOLLOW, "attach_eye_r", v:GetAbsOrigin(), true)
			table.insert(Duel.Particles, particle1)
			table.insert(Duel.Particles, particle2)
		end]]
		Duel.DuelStatus = DOTA_DUEL_STATUS_IN_PROGRESS
		local rndtbl = PlayerTables:copy(Duel.heroes_teams_for_duel)
		for i,v in pairs(rndtbl) do
			if #v > 0 then
				table.shuffle(v)
				local count = 0
				repeat
					local unit = v[1]
					if IsValidEntity(unit) then
						local pid = unit:GetPlayerOwnerID()
						if not unit.DuelChecked and unit:IsAlive() and PlayerResource:IsValidPlayerID(pid) and PlayerResource:GetConnectionState(pid) == DOTA_CONNECTION_STATE_CONNECTED then
							unit.InArena = true
							Duel:FillPreduelUnitData(unit)
							unit:SetHealth(unit:GetMaxHealth())
							unit:SetMana(unit:GetMaxMana())
							count = count + 1
						end
						unit.DuelChecked = true
					end
					table.shuffle(v)
				until count >= heroes_to_fight_n
			end
		end
		for team,tab in pairs(Duel.heroes_teams_for_duel) do
			for _,unit in pairs(tab) do
				for _,v in ipairs(DUEL_PURGED_MODIFIERS) do
					if unit:HasModifier(v) then
						unit:RemoveModifierByName(v)
					end
				end
				if unit.PocketItem then
					UTIL_Remove(unit.PocketItem)
				end
				
				if unit.InArena then
					unit.ArenaBeforeTpLocation = unit:GetAbsOrigin()
					unit:Stop()
					PlayerResource:SetCameraTarget(unit:GetPlayerOwnerID(), unit)
					FindClearSpaceForUnit(unit, Entities:FindByName(nil, "target_mark_arena_team" .. team):GetAbsOrigin(), true)
					Timers:CreateTimer(0.1, function() PlayerResource:SetCameraTarget(unit:GetPlayerOwnerID(), nil); unit:Stop() end)
				elseif unit:IsAlive() then
					Duel:SetUpVisitor(unit)
				end
				--TODO Meepo
			end
		end
		CustomGameEventManager:Send_ServerToAllClients("create_custom_toast", {
			type = "generic",
			text = "#custom_toast_DuelStarted",
			variables = {
				["{duel_index}"] = Duel.DuelCounter + 1
			}
		})
	else
		Duel:EndDuelLogic(false, true)
		Notifications:TopToAll({text="#duel_no_heroes", duration=9.0})
	end
end

function Duel:EndDuel()
	for _,v in ipairs(Duel.Particles) do
		ParticleManager:DestroyParticle(v, false)
	end
	local winner = Duel:GetWinner()
	if winner then
		Notifications:TopToAll({text="#duel_over_winner_p1", duration=9.0})
		Notifications:TopToAll(CreateTeamNotificationSettings(winner, false))
		Notifications:TopToAll({text="#duel_over_winner_p2", continue=true})
		local goldAmount = GetFilteredGold(ARENA_SETTINGS.WinGold_Base + (ARENA_SETTINGS.WinGold_PerDuel * Duel.DuelCounter))
		local g1,g2 = CreateGoldNotificationSettings(goldAmount)
		Notifications:TopToAll(g1)
		Notifications:TopToAll(g2)
		for _,v in ipairs(Duel.heroes_teams_for_duel[winner]) do
			if v and not v:IsNull() then
				Gold:ModifyGold(v, goldAmount)
			end
		end
	else
		Notifications:TopToAll({text="#duel_over_winner_none", duration=9.0})
	end
	Duel.DuelCounter = Duel.DuelCounter + 1
	Duel:EndDuelLogic(true, true)
end

function Duel:GetWinner()
	local teams = {}
	for team,tab in pairs(Duel.heroes_teams_for_duel) do
		for _,unit in pairs(tab) do
			if unit and not unit:IsNull() and unit:IsAlive() then
				if not table.contains(teams, team) and unit.InArena then
					table.insert(teams, team)
				end
			end
		end
	end
	return #teams == 1 and teams[1] or nil
end

function Duel:SetUpVisitor(unit)
	unit.ArenaBeforeTpLocation = unit:GetAbsOrigin()
	Duel:FillPreduelUnitData(unit)
	local team = unit:GetTeamNumber()
	Duel.EntIndexer[team] = Entities:FindByName(Duel.EntIndexer[team], "target_mark_arena_viewers_team" .. team)
	unit:Stop()
	PlayerResource:SetCameraTarget(unit:GetPlayerOwnerID(), unit)
	FindClearSpaceForUnit(unit, Duel.EntIndexer[team]:GetAbsOrigin(), true)
	Timers:CreateTimer(0.1, function() PlayerResource:SetCameraTarget(unit:GetPlayerOwnerID(), nil); unit:Stop() end)
	unit:AddNewModifier(unit, nil, "modifier_duel_hero_disabled_for_duel", {})
end

function Duel:EndDuelForUnit(unit)
	unit:RemoveModifierByName("modifier_duel_hero_disabled_for_duel")
	Timers:CreateTimer(0.1, function()
		if unit:IsAlive() and unit.StatusBeforeArena then
			if unit.StatusBeforeArena.Health then unit:SetHealth(unit.StatusBeforeArena.Health) end
			if unit.StatusBeforeArena.Mana then unit:SetMana(unit.StatusBeforeArena.Mana) end
			if unit.StatusBeforeArena.AbilityCooldowns and type(unit.StatusBeforeArena.AbilityCooldowns) == "table" then
				for ability,v in pairs(unit.StatusBeforeArena.AbilityCooldowns) do
					if ability and not ability:IsNull() and unit:HasAbility(ability:GetAbilityName()) then
						ability:EndCooldown()
						ability:StartCooldown(v)
					end
				end
			end
			if unit.StatusBeforeArena.ItemCooldowns and type(unit.StatusBeforeArena.ItemCooldowns) == "table" then
				for item,v in pairs(unit.StatusBeforeArena.ItemCooldowns) do
					if item and not item:IsNull() then
						item:EndCooldown()
						item:StartCooldown(v)
					end
				end
			end
			unit.StatusBeforeArena = nil
		end
	end)
	unit:Stop()
	PlayerResource:SetCameraTarget(unit:GetPlayerOwnerID(), unit)
	FindClearSpaceForUnit(unit, unit.ArenaBeforeTpLocation or FindFountain(unit:GetTeamNumber()):GetAbsOrigin(), true)
	Timers:CreateTimer(0.1, function()
			PlayerResource:SetCameraTarget(unit:GetPlayerOwnerID(), nil)
			if unit then
				unit:Stop()
			end
		end)
	unit.InArena = nil
	unit.ArenaBeforeTpLocation = nil
	unit.DuelChecked = nil
end

function Duel:EndDuelLogic(bEndForUnits, timeUpdate)
	Duel.EntIndexer = {}
	Duel.DuelStatus = DOTA_DUEL_STATUS_WATING
	Duel.heroes_teams_for_duel = {}
	if bEndForUnits then
		for playerID = 0, DOTA_MAX_TEAM_PLAYERS-1  do
			if PlayerResource:IsValidPlayerID(playerID) then
				local hero = PlayerResource:GetSelectedHeroEntity(playerID)
				if hero then
					Duel:EndDuelForUnit(hero)
				end
			end
		end
	end
	if timeUpdate then
		Duel.TimeUntilDuel = table.nearestOrLowerKey(ARENA_SETTINGS.DelaysFromLast, GetDOTATimeInMinutesFull()) 
	end
end

function Duel:FillPreduelUnitData(unit)
	unit.StatusBeforeArena = {
		Health = unit:GetHealth(),
		Mana = unit:GetMana(),
		AbilityCooldowns = {},
		ItemCooldowns = {},
	}
	for i = 0, unit:GetAbilityCount() - 1 do
		local ability = unit:GetAbilityByIndex(i)
		if ability and ability:GetCooldown(ability:GetLevel()) > 0 then
			unit.StatusBeforeArena.AbilityCooldowns[ability] = ability:GetCooldownTimeRemaining()
			ability:EndCooldown()
		end
	end
	for i = 0, 5 do
		local item = unit:GetItemInSlot(i)
		if item and item:GetAbilityName() ~= "item_aegis_arena" then
			unit.StatusBeforeArena.ItemCooldowns[item] = item:GetCooldownTimeRemaining()
			item:EndCooldown()
		end
	end
end

function Duel:IsDuelOngoing()
	return Duel.DuelStatus == DOTA_DUEL_STATUS_IN_PROGRESS
end