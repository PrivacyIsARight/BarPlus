LoginWindow = LCS.class{}

local spGetKeyCode = Spring.GetKeyCode

local EMAIL_PROVIDERS = {
	["gmail.com"] = {"gmai.com", "gmail.co", "gmial.com", "gmail.cm", "gmail.om", "gmail.con", "gmal.com", "gamil.com"},
	["hotmail.com"] = {"hotmai.com", "hotmail.co", "hotmil.com", "hotmail.cm", "hotmale.com", "hotmial.com"},
	["yahoo.com"] = {"yaho.com", "yahoo.co", "yahho.com", "yahoo.cm", "yajoo.com", "yahooo.com"},
	["outlook.com"] = {"outlook.co", "outlok.com", "outlook.cm", "outloook.com", "outlookk.com"},
	["aol.com"] = {"aol.co", "aol.cm", "aol.om", "aol.con"},
	["icloud.com"] = {"icloud.co", "icloud.cm", "iclud.com", "icloud.om", "icould.com"},
	["live.com"] = {"live.co", "live.cm", "liv.com", "livee.com"},
	["msn.com"] = {"msn.co", "msn.cm", "msnn.com"},
	["comcast.net"] = {"comcast.com", "comast.net", "comcst.net"},
	["verizon.net"] = {"verizon.com", "verison.net", "verizonn.net"},
	["web.de"] = {"webb.de", "weeb.de", "web.dee", "web.dde", "web.ed", "webde.de", "web-de.de", "wed.de"},
	["gmx.de"] = {"gmmx.de", "ggmx.de", "gmxx.de", "gmx.ed", "gmx.dee", "gmx.dde", "gmz.de"},
	["freenet.de"] = {"freeenet.de", "freenett.de", "ffreenet.de", "freenet.ed", "freenet.dee", "freenet.dde", "free-net.de", "freenet-mobilfunk.de", "frenet.de", "freenete.de"},
	["t-online.de"] = {"t-onlin.de", "tt-online.de", "t-onlinee.de", "t-online.ed", "t-online.dee", "t-online.dde", "t-onnline.de", "t-oonline.de", "tonline.de", "t-onine.de", "t-oneline.de", "t.online.de"},
	["protonmail.com"] = {"protonmail.co", "protonmail.cm", "protonmail.con", "protonmaill.com", "protonmai.com", "protomail.com", "protronmail.com", "prontonmail.com", "protonnmail.com", "protonmial.com"},
	["proton.me"] = {"proton.me.com", "proton.ne", "proton.ms", "proton.mr", "protom.me", "protron.me", "protonm.me"},
	["pm.me"] = {"pmme.com", "pm.me.com", "pn.me", "pm.ne", "pm.ms", "pm.mr", "pm-me.me"},
	["protonmail.ch"] = {"protonmail.c", "protonmail.h", "protonmai.ch", "protonmial.ch", "protomail.ch", "protronmail.ch", "prontonmail.ch"},
}

local EMAIL_TYPOS = {}
for correct, typos in pairs(EMAIL_PROVIDERS) do
	for i = 1, #typos do
		EMAIL_TYPOS[typos[i]] = correct
	end
end
EMAIL_PROVIDERS = nil

local RENAME_ERROR_WORDS = {"fail", "denied", "taken", "already", "cooldown", "week", "month", "max", "too "}

local function IsEnterKey(key)
	return key == spGetKeyCode("enter") or key == spGetKeyCode("numpad_enter")
end

local function ContainsAny(text, words)
	for i = 1, #words do
		if text:find(words[i], 1, true) then
			return true
		end
	end
	return false
end

function createTabGroup(ctrls, visibleFunc)
	local count = #ctrls
	for i = 1, count do
		local ctrl1 = ctrls[i]
		if ctrl1.OnKeyPress == nil then
			ctrl1.OnKeyPress = {}
		end

		table.insert(ctrl1.OnKeyPress,
			function(obj, key, mods, ...)
				if key ~= spGetKeyCode("tab") then
					return
				end
				local nextIndex = i % count + 1
				local ctrl2
				while (not ctrl2) and nextIndex ~= i do
					if (not visibleFunc[nextIndex]) or visibleFunc[nextIndex]() then
						ctrl2 = ctrls[nextIndex]
					end
					nextIndex = nextIndex % count + 1
				end

				if ctrl2 then
					screen0:FocusControl(ctrl2)
					if ctrl2.classname == "editbox" then
						local last = #ctrl2.text + 1
						ctrl2.selStart = 1
						ctrl2.selStartPhysical = 1
						ctrl2.selEnd = last
						ctrl2.selEndPhysical = last
					end
				end
			end
		)
	end
end

local lobbyName
local function GetLobbyName()
	if lobbyName then
		return lobbyName
	end
	local tag = "unknown"
	for _, v in ipairs(VFS.GetLoadedArchives()) do
		if string.find(v, "BYAR Chobby ", nil, true) then
			tag = string.gsub(string.gsub(v, "test%-", ""), "BYAR Chobby ", "")
			tag = string.gsub(tag, "[^%w]", " ")
			break
		end
	end
	lobbyName = 'BarPlus Version ' .. tag
	return lobbyName
end

local function Font(size)
	return WG.Chobby.Configuration:GetFont(size)
end

local function NewTextBox(props, fontSize, hintFontSize)
	props.objectOverrideFont = Font(fontSize or 3)
	props.objectOverrideHintFont = Font(hintFontSize or 11)
	return TextBox:New(props)
end

local function NewEditBox(props, fontSize, hintFontSize)
	props.objectOverrideFont = Font(fontSize or 3)
	props.objectOverrideHintFont = Font(hintFontSize or 11)
	return EditBox:New(props)
end

local function NewLabel(props, fontSize)
	props.objectOverrideFont = Font(fontSize or 3)
	return Label:New(props)
end

local function NewButton(props, fontSize)
	props.objectOverrideFont = Font(fontSize or 3)
	return Button:New(props)
end

local function NewConfigCheckbox(y, caption, configKey)
	return Checkbox:New {
		x = 15,
		width = 215,
		y = y,
		height = 35,
		boxalign = "right",
		boxsize = 15,
		caption = caption,
		checked = Configuration[configKey],
		objectOverrideFont = Font(2),
		OnClick = {function(obj)
			Configuration:SetConfigValue(configKey, obj.checked)
		end},
	}
end

function LoginWindow:init(failFunction, cancelText, windowClassname, params)
	if WG.Chobby.lobbyInterfaceHolder:GetChildByName("loginWindow") then
		Log.Error("Tried to spawn duplicate login window")
		return
	end

	local ww, wh = Spring.GetWindowGeometry()
	self.emailRequired = (params and params.emailRequired) or false
	local defaultWindowHeight = (params and params.windowHeight) or 800
	self.windowHeight = math.min(defaultWindowHeight, math.max(740, wh - 20))
	self.loginAfterRegister = (params and params.loginAfterRegister) or false

	local windowHeight = self.windowHeight
	local registerChildren = {}
	local recoverChildren = {}
	local loginChildren = {}

	local function add(list, ctrl)
		list[#list + 1] = ctrl
		return ctrl
	end

	self.ResetText = function()
		if self.txtError then
			self.txtError:SetText("")
		end
	end

	self.CancelFunc = function()
		self.window:Dispose()
		if failFunction then
			failFunction()
		end
		self.window = nil
	end

	local function PasswordKeyPress()
		return {
			function(obj, key)
				if IsEnterKey(key) then
					if self.tabPanel.tabBar:IsSelected("login") then
						self:MayBeDisconnectBeforeTryLogin()
					else
						self:tryRegister()
					end
				end
			end
		}
	end

	local function RegisterKeyPress()
		return {
			function(obj, key)
				if IsEnterKey(key) and self.tabPanel.tabBar:IsSelected("register") then
					self:tryRegister()
				end
			end
		}
	end

	local defaultName = Configuration.userName or Configuration.suggestedNameFromSteam or ""

	self.lblLoginInstructions = add(loginChildren, NewLabel({
		x = 15, width = 170, y = 14, height = 35,
		caption = i18n("login_long"),
	}))

	self.lblRegisterInstructions = add(registerChildren, NewLabel({
		x = 15, width = 170, y = 14, height = 35,
		caption = i18n("register_long"),
	}))

	self.txtUsername = add(loginChildren, NewTextBox({
		x = 15, width = 170, y = 60, height = 35,
		text = i18n("username") .. ":",
	}))

	self.ebUsername = add(loginChildren, NewEditBox({
		x = 135, width = 200, y = 51, height = 35,
		hint = i18n("enter_username"),
		text = defaultName,
	}))

	self.txtPassword = add(loginChildren, NewTextBox({
		x = 15, width = 170, y = 100, height = 35,
		text = i18n("password") .. ":",
	}))

	self.ebPassword = add(loginChildren, NewEditBox({
		x = 135, width = 200, y = 91, height = 35,
		text = Configuration.password or "",
		passwordInput = true,
		hint = i18n("enter_password"),
		OnKeyPress = PasswordKeyPress(),
	}))

	self.txtUsernameRegister = add(registerChildren, NewTextBox({
		x = 15, width = 170, y = 60, height = 35,
		text = i18n("username") .. ":",
	}))

	self.ebUsernameRegister = add(registerChildren, NewEditBox({
		x = 135, width = 200, y = 51, height = 35,
		hint = i18n("enter_username"),
		text = defaultName,
	}))

	self.txtPasswordRegister = add(registerChildren, NewTextBox({
		x = 15, width = 170, y = 100, height = 35,
		text = i18n("password") .. ":",
	}))

	self.ebPasswordRegister = add(registerChildren, NewEditBox({
		x = 135, width = 200, y = 91, height = 35,
		text = Configuration.password or "",
		passwordInput = true,
		hint = i18n("enter_password"),
		OnKeyPress = PasswordKeyPress(),
	}))

	self.txtConfirmPassword = add(registerChildren, NewTextBox({
		x = 15, width = 170, y = 140, height = 70,
		text = i18n("confirm") .. ":",
	}))

	self.ebConfirmPassword = add(registerChildren, NewEditBox({
		x = 135, width = 200, y = 131, height = 35,
		text = "",
		hint = i18n("confirm_password"),
		passwordInput = true,
		OnKeyPress = RegisterKeyPress(),
	}))

	if self.emailRequired then
		self.txtEmail = add(registerChildren, NewTextBox({
			x = 15, width = 170, y = 180, height = 35,
			text = i18n("email") .. ":",
		}))

		self.ebEmail = add(registerChildren, NewEditBox({
			x = 135, width = 200, y = 171, height = 35,
			text = "",
			hint = i18n("enter_email"),
			OnKeyPress = RegisterKeyPress(),
		}))

		self.txtConfirmEmail = add(registerChildren, NewTextBox({
			x = 15, width = 170, y = 220, height = 35,
			text = i18n("confirm") .. ":",
		}))

		self.ebConfirmEmail = add(registerChildren, NewEditBox({
			x = 135, width = 200, y = 211, height = 35,
			text = "",
			hint = i18n("confirm_email"),
			OnKeyPress = RegisterKeyPress(),
		}))
	end

	self.lblRegistrationMultiplayer = add(registerChildren, NewLabel({
		x = 15, width = 170, y = 260, height = 35,
		caption = i18n("required_for_online"),
	}))

	self.cbAutoLogin = add(loginChildren, NewConfigCheckbox(windowHeight - 180, i18n("autoLogin"), "autoLogin"))
	self.cbAutoLoginRegister = add(registerChildren, NewConfigCheckbox(windowHeight - 180, i18n("autoLogin"), "autoLogin"))
	self.cbRememberPassword = add(loginChildren, NewConfigCheckbox(windowHeight - 215, i18n("rememberPassword"), "rememberPassword"))
	self.cbRememberPasswordRegister = add(registerChildren, NewConfigCheckbox(windowHeight - 215, i18n("rememberPassword"), "rememberPassword"))

	self.txtError = add(loginChildren, NewTextBox({
		x = 15, right = 15, y = 140, height = 400,
		text = "",
	}))

	self.txtErrorRegister = add(registerChildren, NewTextBox({
		x = 15, right = 15, y = windowHeight - 246, height = 90,
		text = "",
	}))

	local btnLoginOnClick

	local function reEnableBtnLogin()
		self.btnLogin.tooltip = nil
		self.btnLogin.suppressButtonReaction = false
		self.btnLogin:SetEnabled(true)
		self.btnLogin.OnClick = {btnLoginOnClick}
	end

	btnLoginOnClick = function()
		self.btnLogin.tooltip = "Please wait a moment before retrying login"
		self.btnLogin.suppressButtonReaction = true
		self.btnLogin:SetEnabled(false)
		self.btnLogin.OnClick = {}
		self:MayBeDisconnectBeforeTryLogin()
		WG.Delay(reEnableBtnLogin, 20)
	end

	self.btnLogin = add(loginChildren, NewButton({
		right = 140, width = 130, y = windowHeight - 143, height = 70,
		caption = i18n("login_verb"),
		classname = "action_button",
		tooltip = nil,
		OnClick = {
			function()
				if lobby:GetConnectionStatus() ~= "connected" then
					btnLoginOnClick()
				else
					self.txtError:SetText(Configuration:GetErrorColor() .. "Already logged in")
				end
			end
		},
	}))

	self.btnRegister = add(registerChildren, NewButton({
		right = 140, width = 130, y = windowHeight - 143, height = 70,
		caption = i18n("register_verb"),
		classname = "option_button",
		OnClick = {
			function()
				self:tryRegister()
			end
		},
	}))

	self.btnCancel = NewButton({
		right = 2, width = 130, y = windowHeight - 143, height = 70,
		caption = i18n(cancelText or "cancel"),
		classname = "negative_button",
		OnClick = {
			function()
				self.CancelFunc()
			end
		},
	})

	local formw = 150
	local formh = 20
	local pad = 15

	self.txtChangeUserName = add(recoverChildren, NewTextBox({
		x = pad, y = pad, width = formw * 3, height = 60,
		text = "Change username. You must be logged in, and will be logged out on successful change. Max: 20 characters. Cooldown: no more than twice a week, 3/month.",
	}, 1, 1))

	self.ebChangeUserName = add(recoverChildren, NewEditBox({
		x = pad, y = 80, width = 350, height = formh,
		text = defaultName,
		tooltip = '3-20 characters. Letters, numbers, square brackets, and underscores only.',
	}, 1, 1))

	self.btnChangeUserName = add(recoverChildren, NewButton({
		x = pad + 360, y = 80, width = 150, height = formh,
		caption = i18n("change_username"),
		classname = "negative_button",
		OnClick = {
			function()
				self:tryChangeUserName()
			end
		},
	}, 1))

	self.txtHelpChangeUserName = add(recoverChildren, NewTextBox({
		x = pad, y = 105, width = formw * 3 + 60, height = formh,
		text = "If this doesnt work contact us on Discord.",
	}, 1, 1))

	self.txtErrorChangeUserName = add(recoverChildren, NewTextBox({
		x = pad, y = 128, width = formw * 3 + 60, height = 28,
		text = "",
	}, 1, 1))

	add(recoverChildren, Line:New{x = 5, y = 160, right = 5, height = 1})

	self.txtResetPassword = add(recoverChildren, NewTextBox({
		x = pad, y = 168, width = formw * 3, height = formh * 2,
		text = "Reset forgotten password: You need to use your web browser to reset a forgotten password.",
	}, 1, 1))

	self.txtChangePassword = add(recoverChildren, NewTextBox({
		x = pad, y = 292, width = formw * 3, height = formh * 2,
		text = "Change Password: You must be logged in, enter your old and your new password",
	}, 1, 1))

	self.txtChangeEmail = add(recoverChildren, NewTextBox({
		x = pad, y = 420, width = 520, height = 82,
		text = "Change email address associated with your account. You must be logged in. Enter the new email address you wish to use, then enter the validation code sent to the new email address.",
	}, 1, 1))

	self.lblChangeEmailEmail = add(recoverChildren, NewLabel({
		x = pad, y = 510, width = 170, height = formh,
		autosize = false,
		valign = "center",
		caption = "New email address:",
	}, 1))

	self.ebChangeEmailEmail = add(recoverChildren, NewEditBox({
		x = 190, y = 510, width = 210, height = formh,
		text = "",
		tooltip = 'Make sure you enter your new email address',
	}, 1, 1))

	self.lblChangeEmailVerification = add(recoverChildren, NewLabel({
		x = pad, y = 540, width = 170, height = formh,
		autosize = false,
		valign = "center",
		caption = "Verification Code:",
	}, 1))

	self.ebChangeEmailVerification = add(recoverChildren, NewEditBox({
		x = 190, y = 540, width = 210, height = formh,
		text = "",
		tooltip = 'You will recieve this code via email after submitting your email in the above box',
	}, 1, 1))

	self.btnChangeEmail = add(recoverChildren, NewButton({
		x = 405, y = 510, width = 155, height = formh,
		caption = i18n("submit_email"),
		classname = "negative_button",
		OnClick = {
			function()
				self:tryChangeEmail()
			end
		},
	}, 1))

	self.btnChangeEmailVerification = add(recoverChildren, NewButton({
		x = 405, y = 540, width = 155, height = formh,
		caption = i18n("submit_verification"),
		classname = "negative_button",
		OnClick = {
			function()
				self:tryChangeEmailVerification()
			end
		},
	}, 1))

	self.txtErrorChangeEmail = add(recoverChildren, NewTextBox({
		x = pad, y = 570, width = 560, height = formh,
		text = "If this doesnt work contact us on Discord",
	}, 1, 1))

	local function LogoutFunc()
		if lobby:GetConnectionStatus() ~= "offline" then
			Spring.Echo("Logout")
			WG.Chobby.interfaceRoot.CleanMultiplayerState()
			lobby:Disconnect()
		else
			Spring.Echo("Logout pressed, but already offline")
		end
	end

	self.btnLogOut = add(recoverChildren, NewButton({
		right = 140, width = 130, y = windowHeight - 143, height = 70,
		caption = "Logout",
		classname = "negative_button",
		OnClick = {LogoutFunc},
	}))

	local width = math.min(620, math.max(580, ww - 20))

	self.window = Window:New {
		x = math.floor(math.max(0, (ww - width) / 2)),
		y = math.floor(math.max(0, (wh - windowHeight) / 2)),
		width = width,
		height = windowHeight,
		caption = "",
		noFont = true,
		resizable = false,
		draggable = false,
		classname = windowClassname,
		children = {},
		parent = WG.Chobby.lobbyInterfaceHolder,
		OnDispose = {
			function()
				self:RemoveListeners()
			end
		},
		OnFocusUpdate = {
			function(obj)
				obj:BringToFront()
			end
		}
	}

	local tabFont = Font(2)
	self.tabPanel = Chili.DetachableTabPanel:New {
		x = 0,
		right = 0,
		y = 0,
		minTabWidth = width / 3 - 20,
		bottom = 0,
		padding = {0, 0, 0, 0},
		tabs = {
			{name = "login", caption = i18n("login"), children = loginChildren, objectOverrideFont = tabFont},
			{name = "register", caption = i18n("register_verb"), children = registerChildren, objectOverrideFont = tabFont},
			{name = "reset", caption = "Recover/Change", children = recoverChildren, objectOverrideFont = tabFont},
		},
	}

	self.tabBarHolder = Control:New {
		name = "tabBarHolder",
		x = 9,
		y = 0,
		right = 0,
		height = 30,
		resizable = false,
		draggable = false,
		padding = {0, 2, 0, 0},
		children = {
			self.tabPanel.tabBar
		}
	}

	if Configuration.firstLoginEver then
		self.tabPanel.tabBar:Select("register")
	end

	self.contentsPanel = ScrollPanel:New {
		x = 5,
		right = 5,
		y = 30,
		bottom = 4,
		horizontalScrollbar = false,
		verticalScrollbar = false,
		children = {
			self.tabPanel,
			self.btnCancel
		}
	}

	self.window:AddChild(self.tabBarHolder)
	self.window:AddChild(self.contentsPanel)
	self.window:BringToFront()

	local function IsRegisterInfoVisible()
		return self.tabPanel.tabBar.selected == 2
	end

	if self.emailRequired then
		createTabGroup({self.ebUsername, self.ebPassword, self.ebConfirmPassword, self.ebEmail}, {false, false, IsRegisterInfoVisible, IsRegisterInfoVisible})
	else
		createTabGroup({self.ebUsername, self.ebPassword, self.ebConfirmPassword}, {false, false, IsRegisterInfoVisible})
	end
	screen0:FocusControl(self.ebUsername)
	self.loginAttempts = 0
end

local REMOVABLE_LISTENERS = {
	{"onAgreementEnd", "OnAgreementEnd"},
	{"onAgreement", "OnAgreement"},
	{"onConnect", "OnConnect"},
	{"onConnectRegister", "OnConnect"},
	{"onDisconnected", "OnDisconnected"},
	{"onRedirect", "OnRedirect"},
	{"onRegistrationDenied", "OnRegistrationDenied"},
	{"onChangeEmailRequestDenied", "OnChangeEmailRequestDenied"},
	{"onChangeEmailRequestAccepted", "OnChangeEmailRequestAccepted"},
	{"onChangeEmailDenied", "OnChangeEmailDenied"},
	{"onChangeEmailAccepted", "OnChangeEmailAccepted"},
}

function LoginWindow:RemoveListeners()
	self:ClearRenameListeners()
	for i = 1, #REMOVABLE_LISTENERS do
		local field, event = REMOVABLE_LISTENERS[i][1], REMOVABLE_LISTENERS[i][2]
		local listener = self[field]
		if listener then
			lobby:RemoveListener(event, listener)
			self[field] = nil
		end
	end
end

function LoginWindow:ClearRenameListeners()
	self.pendingRenameUserName = nil
	if self.onRenameServerMSG then
		lobby:RemoveListener("OnServerMSG", self.onRenameServerMSG)
		self.onRenameServerMSG = nil
	end
	if self.onRenameDenied then
		lobby:RemoveListener("OnDenied", self.onRenameDenied)
		self.onRenameDenied = nil
	end
	if self.onRenameDisconnected then
		lobby:RemoveListener("OnDisconnected", self.onRenameDisconnected)
		self.onRenameDisconnected = nil
	end
end

function LoginWindow:MayBeDisconnectBeforeTryLogin()
	if lobby:GetConnectionStatus() ~= "connected" then
		self:tryLogin()
		return
	end

	local function callTryLogin()
		self:tryLogin()
	end
	self.onDisconnected = function()
		lobby:RemoveListener("OnDisconnected", self.onDisconnected)
		WG.Delay(callTryLogin, 3)
	end
	lobby:AddListener("OnDisconnected", self.onDisconnected)

	WG.Chobby.interfaceRoot.CleanMultiplayerState()
	lobby:Disconnect()
end

function LoginWindow:tryLogin()
	self.txtError:SetText("")

	local username = self.ebUsername.text
	local password = (self.ebPassword.visible and self.ebPassword.text) or nil
	if username == '' then
		return
	end
	Configuration.userName = username
	Configuration.password = password

	if lobby:GetConnectionStatus() ~= "connected" or self.loginAttempts >= 3 then
		self.loginAttempts = 0
		self:RemoveListeners()

		self.onConnect = function(listener)
			lobby:RemoveListener("OnConnect", self.onConnect)
			self:OnConnected(listener)
		end
		lobby:AddListener("OnConnect", self.onConnect)

		self.onDisconnected = function()
			lobby:RemoveListener("OnDisconnected", self.onDisconnected)
			self.txtError:SetText(Configuration:GetErrorColor() .. "Cannot reach server:\n" .. tostring(Configuration:GetServerAddress()) .. ":" .. tostring(Configuration:GetServerPort()))
		end
		lobby:AddListener("OnDisconnected", self.onDisconnected)

		local function Connect()
			lobby:Connect(Configuration:GetServerAddress(), Configuration:GetServerPort(), username, password, 3, nil, GetLobbyName())
		end

		self.onRedirect = function(listener, newaddress)
			lobby:Disconnect()
			Configuration:SetConfigValue("serverAddress", newaddress)
			WG.Delay(Connect, 3)
		end
		lobby:AddListener("OnRedirect", self.onRedirect)

		Connect()
	else
		lobby:Login(username, password, 3, nil, GetLobbyName())
	end

	self.loginAttempts = self.loginAttempts + 1
end

function isInValidEmail(email)
	if not email or email == '' then
		return false
	end

	local domain = string.match(email, "@(.+)$")
	if not domain then
		return false
	end

	local correct = EMAIL_TYPOS[string.lower(domain)]
	if correct then
		return "Did you mean " .. correct .. "? (Common typo detected)"
	end
	return false
end

function LoginWindow:tryRegister()
	local errorColor = Configuration:GetErrorColor()
	local username = self.ebUsernameRegister.text

	if username == '' then
		self.txtErrorRegister:SetText(errorColor .. "No username provided.")
		return
	end

	if self.ebPasswordRegister.text ~= self.ebConfirmPassword.text then
		self.txtErrorRegister:SetText(errorColor .. "Passwords do not match.")
		return
	end

	if self.emailRequired then
		if self.ebEmail.text ~= self.ebConfirmEmail.text then
			self.txtErrorRegister:SetText(errorColor .. "Emails do not match.")
			return
		end
		local invalidEmail = isInValidEmail(self.ebEmail.text)
		if invalidEmail then
			self.txtErrorRegister:SetText(errorColor .. invalidEmail)
			return
		end
	end

	self.txtErrorRegister:SetText("")

	local password = (self.ebPasswordRegister.visible and self.ebPasswordRegister.text) or nil
	local email = (self.emailRequired and self.ebEmail.visible and self.ebEmail.text) or nil

	if password == '' then
		self.txtErrorRegister:SetText(errorColor .. "No password provided.")
		return
	end

	if email == '' then
		self.txtErrorRegister:SetText(errorColor .. "No email provided.")
		return
	end

	self.onRegistrationDenied = function(listener, err)
		self.txtErrorRegister:SetText(Configuration:GetErrorColor() .. "Registration error:" .. err)
		lobby:RemoveListener("OnRegistrationDenied", self.onRegistrationDenied)
	end
	lobby:AddListener("OnRegistrationDenied", self.onRegistrationDenied)

	if lobby:GetConnectionStatus() ~= "connected" or self.loginAttempts >= 3 then
		self.loginAttempts = 0
		self:RemoveListeners()

		self.onConnectRegister = function(listener)
			lobby:RemoveListener("OnConnect", self.onConnectRegister)
			self:OnConnected(listener)
		end
		WG.LoginWindowHandler.QueueRegister(username, password, email)
		lobby:AddListener("OnConnect", self.onConnectRegister)

		lobby:Connect(Configuration:GetServerAddress(), Configuration:GetServerPort(), username, password, 3, email, GetLobbyName())
	else
		lobby:Register(username, password, email)
		if self.loginAfterRegister then
			lobby:Login(username, password, 3, nil, GetLobbyName())
		end
	end

	self.loginAttempts = self.loginAttempts + 1
end

function LoginWindow:tryChangeUserName()
	self:ClearRenameListeners()
	local newusername = self.ebChangeUserName.text
	if lobby:GetConnectionStatus() ~= "connected" then
		self.txtErrorChangeUserName:SetText(Configuration:GetErrorColor() .. "Must be logged in to change user name!")
		return
	end

	local function SetRenameButtonEnabled(enabled)
		if self.btnChangeUserName then
			self.btnChangeUserName:SetEnabled(enabled)
		end
	end

	local function FinishRenameRequest(message, color)
		self.pendingRenameUserName = nil
		SetRenameButtonEnabled(true)
		if self.txtErrorChangeUserName then
			self.txtErrorChangeUserName:SetText((color or "") .. message)
		end
		self:ClearRenameListeners()
	end

	local function GetRenameResponseColor(message)
		local lowerMessage = string.lower(tostring(message or ""))
		if lowerMessage:find("success", 1, true) or lowerMessage:find("renamed", 1, true) then
			return Configuration:GetSuccessColor()
		end
		if ContainsAny(lowerMessage, RENAME_ERROR_WORDS) then
			return Configuration:GetErrorColor()
		end
		return Configuration:GetWarningColor()
	end

	self.pendingRenameUserName = newusername
	SetRenameButtonEnabled(false)
	self.txtErrorChangeUserName:SetText(Configuration:GetWarningColor() .. "Sending rename request for: " .. newusername)

	self.onRenameServerMSG = function(listener, message)
		FinishRenameRequest(tostring(message or "No message"), GetRenameResponseColor(message))
	end
	lobby:AddListener("OnServerMSG", self.onRenameServerMSG)

	self.onRenameDenied = function(listener, reason)
		FinishRenameRequest("Rename denied: " .. tostring(reason or "No reason provided"), Configuration:GetErrorColor())
	end
	lobby:AddListener("OnDenied", self.onRenameDenied)

	self.onRenameDisconnected = function()
		FinishRenameRequest("Disconnected after rename request. This usually means success; log in as: " .. newusername, Configuration:GetWarningColor())
	end
	lobby:AddListener("OnDisconnected", self.onRenameDisconnected)

	WG.Delay(function()
		if self.pendingRenameUserName == newusername then
			FinishRenameRequest("No reply yet. Check whether you are still connected, then try again if needed.", Configuration:GetWarningColor())
		end
	end, 30)

	lobby:RenameAccount(newusername)
end

function LoginWindow:tryChangeEmail()
	local errorColor = Configuration:GetErrorColor()
	local newemail = self.ebChangeEmailEmail.text
	if string.len(newemail) < 5 then
		self.txtErrorChangeEmail:SetText(errorColor .. "Enter a valid email address, not " .. newemail)
		return false
	end

	local invalidEmail = isInValidEmail(newemail)
	if invalidEmail then
		self.txtErrorChangeEmail:SetText(errorColor .. invalidEmail)
		return false
	end

	if lobby:GetConnectionStatus() ~= "connected" then
		self.txtErrorChangeEmail:SetText(errorColor .. "Must be logged in to change email address")
		return false
	end

	self.txtErrorChangeEmail:SetText(Configuration:GetWarningColor() .. "Sending Request for: " .. newemail)

	self.onChangeEmailRequestDenied = function(listener, errorMsg)
		lobby:RemoveListener("OnChangeEmailRequestDenied", self.onChangeEmailRequestDenied)
		self.txtErrorChangeEmail:SetText(Configuration:GetErrorColor() .. "Change Email Request Denied: " .. errorMsg)
	end

	self.onChangeEmailRequestAccepted = function()
		lobby:RemoveListener("OnChangeEmailRequestAccepted", self.onChangeEmailRequestAccepted)
		self.txtErrorChangeEmail:SetText(Configuration:GetSuccessColor() .. "Request Accepted, enter verification code recieved via email")
	end

	lobby:AddListener("OnChangeEmailRequestDenied", self.onChangeEmailRequestDenied)
	lobby:AddListener("OnChangeEmailRequestAccepted", self.onChangeEmailRequestAccepted)
	lobby:ChangeEmailRequest(newemail)
end

function LoginWindow:tryChangeEmailVerification()
	local errorColor = Configuration:GetErrorColor()
	if lobby:GetConnectionStatus() ~= "connected" then
		self.txtErrorChangeEmail:SetText(errorColor .. "Must be logged in to verify change email address")
		return false
	end

	local newemail = self.ebChangeEmailEmail.text
	if string.len(newemail) < 5 then
		self.txtErrorChangeEmail:SetText(errorColor .. "Enter a valid email address, not " .. newemail)
		return false
	end

	local verificationCode = self.ebChangeEmailVerification.text
	if string.len(verificationCode) < 3 then
		self.txtErrorChangeEmail:SetText(errorColor .. "Verification code too short: " .. verificationCode)
		return false
	end

	self.txtErrorChangeEmail:SetText(Configuration:GetWarningColor() .. "Sending Verification Code: " .. verificationCode .. " for " .. newemail)

	self.onChangeEmailDenied = function(listener, errorMsg)
		lobby:RemoveListener("OnChangeEmailDenied", self.onChangeEmailDenied)
		self.txtErrorChangeEmail:SetText(Configuration:GetErrorColor() .. "Change Email Denied: " .. errorMsg)
	end

	self.onChangeEmailAccepted = function()
		lobby:RemoveListener("OnChangeEmailAccepted", self.onChangeEmailAccepted)
		self.txtErrorChangeEmail:SetText(Configuration:GetSuccessColor() .. "Email changed successfully to " .. self.ebChangeEmailEmail.text)
	end

	lobby:AddListener("OnChangeEmailDenied", self.onChangeEmailDenied)
	lobby:AddListener("OnChangeEmailAccepted", self.onChangeEmailAccepted)
	lobby:ChangeEmail(newemail, verificationCode)
end

function LoginWindow:OnConnected()
	Spring.Echo("OnConnected")

	self.onAgreement = function(listener, line)
		self.agreementText = ((self.agreementText and (self.agreementText .. " \n")) or "") .. line
	end
	lobby:AddListener("OnAgreement", self.onAgreement)

	self.onAgreementEnd = function()
		self:createAgreementWindow()
		lobby:RemoveListener("OnAgreementEnd", self.onAgreementEnd)
		lobby:RemoveListener("OnAgreement", self.onAgreement)
	end
	lobby:AddListener("OnAgreementEnd", self.onAgreementEnd)
end

function LoginWindow:createAgreementWindow()
	self.agreementWindow = Window:New {
		classname = "main_window",
		x = "33.3%",
		y = "15%",
		right = "33.3%",
		bottom = "15%",
		caption = "\nUser agreement",
		captionColor = {1.0, 1.0, 1.0, 1.0},
		objectOverrideFont = Font(3),
		OnClick = self.BringToFront,
		resizable = false,
		draggable = false,
		parent = WG.Chobby.lobbyInterfaceHolder,
	}

	self.tbAgreement = NewTextBox({
		x = "2%", right = "2%", y = "3%",
		text = self.agreementText,
	}, 2, 2)

	ScrollPanel:New {
		x = "2%",
		right = "2%",
		y = 48,
		bottom = 270,
		children = {self.tbAgreement},
		parent = self.agreementWindow,
	}

	if self.emailRequired then
		self.txtVerif = NewTextBox({
			x = "2%", width = 200, bottom = 100, height = 35,
			text = i18n("email_verification_code") .. ":",
			parent = self.agreementWindow,
		}, 2, 2)
		self.ebVerif = NewEditBox({
			x = 200, right = "3%", bottom = 96, height = 35,
			text = "",
			parent = self.agreementWindow,
		}, 2, 2)
	end

	self.btnYes = NewButton({
		x = "2%", width = 135, bottom = "1%", height = 70,
		caption = i18n("accept"),
		classname = "action_button",
		OnClick = {
			function()
				self:acceptAgreement(self.emailRequired and self.ebVerif.text or "")
			end
		},
		parent = self.agreementWindow,
	})
	self.btnNo = NewButton({
		right = "2%", width = 135, bottom = "1%", height = 70,
		caption = i18n("decline"),
		classname = "negative_button",
		OnClick = {
			function()
				self:declineAgreement()
			end
		},
		parent = self.agreementWindow,
	})
end

function LoginWindow:acceptAgreement(verificationCode)
	lobby:ConfirmAgreement(verificationCode)
	self.agreementWindow:Dispose()
end

function LoginWindow:declineAgreement()
	lobby:Disconnect()
	self.agreementWindow:Dispose()
end
