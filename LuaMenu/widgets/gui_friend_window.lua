--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
	return {
		name      = "Friend Window",
		desc      = "Handles friends.",
		author    = "gajop",
		date      = "13 August 2016",
		license   = "GNU LGPL, v2.1 or later",
		layer     = -100000,
		enabled   = true  --  loaded by default?
	}
end

local friendWindow

local function ChobbyReady()
	return WG.Chobby ~= nil and WG.Chobby.Configuration ~= nil
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- External Interface

local FriendWindow = {}

function FriendWindow.GetControl()
	if not ChobbyReady() then
		return nil
	end
	friendWindow = WG.Chobby.FriendListWindow()
	return friendWindow.window
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Widget Interface

local function DelayedInitialize()
end

function widget:Initialize()
	CHOBBY_DIR = LUA_DIRNAME .. "widgets/chobby/"
	VFS.Include(LUA_DIRNAME .. "widgets/chobby/headers/exports.lua", nil, VFS.RAW_FIRST)

	WG.Delay(DelayedInitialize, 1)

	WG.FriendWindow = FriendWindow
end

function widget:Shutdown()
	-- if WG.LibLobby then

	-- end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
