function widget:GetInfo()
	return {
		name      = "Chili lobby",
		desc      = "Chili example lobby",
		author    = "gajop",
		date      = "in the future",
		license   = "GPL-v2",
		layer     = 1001,
		enabled   = true,
	}
end

require("keysym.lua")

CHOBBY_DIR = LUA_DIRNAME .. "widgets/chobby/"

local interfaceRoot

local oldSizeX, oldSizeY
local lobbyIcon
local lastIconReapply = Spring.GetTimer()
local ICON_REAPPLY_INTERVAL = 5
local ingame = false
function widget:ViewResize(vsx, vsy, viewGeometry)
	oldSizeX, oldSizeY = vsx, vsy
	if interfaceRoot then
		interfaceRoot.ViewResize(vsx, vsy)
	end
	WG.Chobby:_ViewResize(vsx, vsy)
end

function widget:Update(dt)
	local screenWidth, screenHeight = Spring.GetWindowGeometry()
	if screenWidth ~= oldSizeX or screenHeight ~= oldSizeY then
		widget:ViewResize(screenWidth, screenHeight)
	end

	if lobbyIcon and not ingame then
		local now = Spring.GetTimer()
		if Spring.DiffTimers(now, lastIconReapply) >= ICON_REAPPLY_INTERVAL then
			lastIconReapply = now
			Spring.SetWMIcon(lobbyIcon, true)
		end
	end
end

local function SetIngame(value)
	ingame = value
	if interfaceRoot then
		interfaceRoot.SetIngame(value)
	end
	WG.Delay(function() lobby:SetIngameStatus(value) end, 1)
end

local ignoreFirstCall = true
function widget:ActivateMenu()
	if ignoreFirstCall then
		ignoreFirstCall = false
		return
	end
	SetIngame(false)
end

function widget:ActivateGame()
	SetIngame(true)
end

local function ApplyTaskbarIdentity()
	local gameConfig = Chobby.Configuration.gameConfig
	local taskbarTitle = gameConfig.taskbarTitle
	if taskbarTitle then
		Spring.SetWMCaption(taskbarTitle, gameConfig.taskbarTitleShort or taskbarTitle)
	end
	lobbyIcon = gameConfig.taskbarIcon or "bitmaps/logo.png"
	Spring.SetWMIcon(lobbyIcon, true)
end

function widget:Initialize()
	if WG.LimitFps then
		WG.LimitFps.ForceRedrawPeriod(5)
	end
	if not WG.LibLobby then
		Spring.Log("chobby", LOG.ERROR, "Missing liblobby.")
		widgetHandler:RemoveWidget(widget)
		return
	end
	if not WG.Chili then
		Spring.Log("chobby", LOG.ERROR, "Missing chiliui.")
		widgetHandler:RemoveWidget(widget)
		return
	end

	Chobby = VFS.Include(CHOBBY_DIR .. "core.lua", nil)

	WG.Chobby = Chobby
	WG.Chobby:_Initialize()

	interfaceRoot = WG.Chobby.GetInterfaceRoot()

	lobbyInterfaceHolder = interfaceRoot.GetLobbyInterfaceHolder()
	Chobby.lobbyInterfaceHolder = lobbyInterfaceHolder
	Chobby.interfaceRoot = interfaceRoot

	ApplyTaskbarIdentity()

	local function OnBattleAboutToStart()
		lobby:SetIngameStatus(true)
		lobby:SetBattleStatus({ isReady = false })
		Spring.Echo("Game starting, ensuring Chobby garbage is collected.")
		collectgarbage("collect")
	end
	WG.LibLobby.localLobby:AddListener("OnBattleAboutToStart", OnBattleAboutToStart)
	WG.LibLobby.lobby:AddListener("OnBattleAboutToStart", OnBattleAboutToStart)

	local function onConfigurationChange(listener, key, value)
		if key == "gameConfigName" then
			ApplyTaskbarIdentity()
		elseif key == "language" then
			Spring.Echo("Set language to " .. value)
			i18n.setLocale(value)
		end
	end
	Chobby.Configuration:AddListener("OnConfigurationChange", onConfigurationChange)
end

function widget:KeyPress(key, mods, isRepeat, label, unicode)
	return interfaceRoot and interfaceRoot.KeyPressed(key, mods, isRepeat, label, unicode)
end

function widget:Shutdown()
	Spring.Log("Chobby", LOG.NOTICE, "Chobby Shutdown")
	WG.Chobby = nil
end

function widget:DrawScreen()
	if WG.Chobby then
		WG.Chobby:_DrawScreen()
	end
end

function widget:GetConfigData()
	if WG.Chobby == nil then
		Spring.Log("Chobby", LOG.ERROR, "No WG.Chobby available during widget:GetConfigData()")
		return
	end
	return WG.Chobby:_GetConfigData()
end

function widget:SetConfigData(...)
	if WG.Chobby == nil then
		Spring.Log("Chobby", LOG.ERROR, "No WG.Chobby available during widget:SetConfigData()")
		return
	end
	WG.Chobby:_SetConfigData(...)
end
