--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
function widget:GetInfo()
	return {
		name    = "Battle Auto Boss",
		desc    = "Takes boss when joining a lobby as a player if you are not the boss and no other players are present.",
		author  = "vexalous",
		date    = "9 October 2026",
		license = "GNU LGPL, v2.1 or later",
		layer   = 0,
		enabled = true
	}
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
local lobby
local didBoss = false

local function OnJoinedBattle(listener, battleID, userName)
	if userName ~= lobby:GetMyUserName() then
		return
	end
	didBoss = false
end

local function BattleHasOtherPlayer(battle, myUserName)
	for _, userName in ipairs(battle.users or {}) do
		if userName ~= myUserName and userName ~= battle.founder then
			local status = lobby:GetUserBattleStatus(userName)
			if not status or status.isSpectator ~= true then
				return true
			end
		end
	end
	return false
end

local function TryAutoBoss()
	local Configuration = WG.Chobby and WG.Chobby.Configuration
	if Configuration and Configuration.autoBossEmptyLobby == false then
		return
	end
	if didBoss then
		return
	end

	local myUserName = lobby:GetMyUserName()
	local battleID = lobby:GetMyBattleID()
	if not battleID then
		return
	end
	local battle = lobby:GetBattle(battleID)
	if not battle or battle.isRunning then
		return
	end

	local myStatus = lobby:GetUserBattleStatus(myUserName)
	if not myStatus or myStatus.isSpectator ~= false then
		return
	end
	if lobby:GetMyIsBoss() then
		return
	end
	if BattleHasOtherPlayer(battle, myUserName) then
		return
	end

	lobby:SayBattle("!boss " .. myUserName)
	didBoss = true
end

local function OnUpdateUserBattleStatus(listener, userName, status)
	if didBoss then
		return
	end

	local battleID = lobby:GetMyBattleID()
	if not battleID then
		return
	end
	local battle = lobby:GetBattle(battleID)
	if not battle then
		return
	end

	if userName == lobby:GetMyUserName() then
		TryAutoBoss()
		return
	end

	for _, other in ipairs(battle.users or {}) do
		if other == userName then
			TryAutoBoss()
			return
		end
	end
end

function widget:Initialize()
	CHOBBY_DIR = LUA_DIRNAME .. "widgets/chobby/"
	VFS.Include(LUA_DIRNAME .. "widgets/chobby/headers/exports.lua", nil, VFS.RAW_FIRST)

	lobby = WG.LibLobby and WG.LibLobby.lobby
	if lobby then
		lobby:AddListener("OnJoinedBattle", OnJoinedBattle)
		lobby:AddListener("OnUpdateUserBattleStatus", OnUpdateUserBattleStatus)
	end
end

function widget:Shutdown()
	if lobby then
		lobby:RemoveListener("OnJoinedBattle", OnJoinedBattle)
		lobby:RemoveListener("OnUpdateUserBattleStatus", OnUpdateUserBattleStatus)
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
