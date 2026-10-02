NoSeedWarning = {}

local NO_SECRET_MESSAGE = "BARPLUS COULD NOT GENERATE A SECURE RANDOM NUMBER. YOU WILL "
	.. "APPEAR AS A GENERIC CLIENT. PLEASE REPORT THIS."

local NO_SECRET_HEADLINE = "CRITICAL ERROR"

local NO_SECRET_BODY = "BARPLUS COULD NOT GENERATE A SECURE RANDOM NUMBER.\n"
	.. "YOU WILL APPEAR TO THE SERVER AS A GENERIC CLIENT.\n"
	.. "NOTHING SENSITIVE IS EVER SENT,\n"
	.. "BUT THE SERVER CAN TELL YOU'RE USING BARPLUS.\n"
	.. "PLEASE REPORT THIS."

local LOG_SECTION = "liblobby"

local WINDOW_WIDTH = 600
local WINDOW_HEIGHT = 320
local BUTTON_WIDTH = 200
local BUTTON_HEIGHT = 74
local BUTTON_GUTTER = 48

local LIGHT_INSET = 6
local LIGHT_SPEED = 380
local LIGHT_STEP = 4
local LIGHT_FALLOFF = 3.4

local LIGHT_HALF_WIDTH_HEAD = 3.2
local LIGHT_HALF_WIDTH_TAIL = 1.0
local LIGHT_CORE_RGB = {{1.00, 0.90, 0.86}, {0.58, 0.05, 0.04}}
local LIGHT_EDGE_RGB = {{1.00, 0.24, 0.18}, {0.45, 0.02, 0.02}}
local LIGHT_CORE_ALPHA = {0.95, 0.05}

local pending = false
local shown = false
local diagLogged = false
local urgentPopupClass

local function ChobbyGlobal(name)
	return (WG and WG.Chobby and WG.Chobby[name]) or _G[name]
end

local function CornerRadius(w, h)
	local m = w < h and w or h
	local r = m * 0.055
	if r < 10 then r = 10 end
	if r > 28 then r = 28 end
	if r > w * 0.5 then r = w * 0.5 end
	if r > h * 0.5 then r = h * 0.5 end
	return r
end

local function BorderMetrics(win, inset)
	local bw, bh = win.width - 2 * inset, win.height - 2 * inset
	local r = CornerRadius(win.width, win.height)
	if r > bw * 0.5 then r = bw * 0.5 end
	if r > bh * 0.5 then r = bh * 0.5 end
	local sw, sh = bw - 2 * r, bh - 2 * r
	return r, sw, sh, r * math.pi * 0.5
end

local function PerimeterFromMetrics(sw, sh, arc)
	return 2 * sw + 2 * sh + 4 * arc
end

local function BorderPerimeter(win, inset)
	local _, sw, sh, arc = BorderMetrics(win, inset)
	return PerimeterFromMetrics(sw, sh, arc)
end

local function PointOnBorder(win, dist, inset)
	local x0, y0 = inset, inset
	local x1, y1 = win.width - inset, win.height - inset
	local r, sw, sh, arc = BorderMetrics(win, inset)
	local d = dist % PerimeterFromMetrics(sw, sh, arc)

	if d < sw then
		return x0 + r + d, y0
	end
	d = d - sw
	if d < arc then
		local a = -math.pi * 0.5 + d / r
		return x1 - r + r * math.cos(a), y0 + r + r * math.sin(a)
	end
	d = d - arc
	if d < sh then
		return x1, y0 + r + d
	end
	d = d - sh
	if d < arc then
		local a = d / r
		return x1 - r + r * math.cos(a), y1 - r + r * math.sin(a)
	end
	d = d - arc
	if d < sw then
		return x1 - r - d, y1
	end
	d = d - sw
	if d < arc then
		local a = math.pi * 0.5 + d / r
		return x0 + r + r * math.cos(a), y1 - r + r * math.sin(a)
	end
	d = d - arc
	if d < sh then
		return x0, y1 - r - d
	end
	d = d - sh
	local a = math.pi + d / r
	return x0 + r + r * math.cos(a), y0 + r + r * math.sin(a)
end

local function SegmentsFor(win, inset, step)
	return math.max(24, math.ceil(BorderPerimeter(win, inset) / step))
end

local function Interp(from, to, t)
	return from[1] + (to[1] - from[1]) * t,
		from[2] + (to[2] - from[2]) * t,
		from[3] + (to[3] - from[3]) * t
end

local function EmitLoop(win, head, n)
	local perim = BorderPerimeter(win, LIGHT_INSET)
	local k = LIGHT_FALLOFF
	local lap = math.exp(-k)
	local ax, ay = PointOnBorder(win, head, LIGHT_INSET)
	local av = 1.0
	for i = 1, n do
		local s = i / n
		local v = (math.exp(-k * s) - lap) / (1 - lap)
		local bx, by = PointOnBorder(win, head - perim * s, LIGHT_INSET)
		local dx, dy = bx - ax, by - ay
		local len = math.sqrt(dx * dx + dy * dy)
		if len > 1e-4 then
			local nx, ny = -dy / len, dx / len
			local wa = LIGHT_HALF_WIDTH_TAIL + (LIGHT_HALF_WIDTH_HEAD - LIGHT_HALF_WIDTH_TAIL) * av
			local wb = LIGHT_HALF_WIDTH_TAIL + (LIGHT_HALF_WIDTH_HEAD - LIGHT_HALF_WIDTH_TAIL) * v
			local crA, cgA, cbA = Interp(LIGHT_CORE_RGB[2], LIGHT_CORE_RGB[1], av)
			local crB, cgB, cbB = Interp(LIGHT_CORE_RGB[2], LIGHT_CORE_RGB[1], v)
			local erA, egA, ebA = Interp(LIGHT_EDGE_RGB[2], LIGHT_EDGE_RGB[1], av)
			local erB, egB, ebB = Interp(LIGHT_EDGE_RGB[2], LIGHT_EDGE_RGB[1], v)
			local aaA = LIGHT_CORE_ALPHA[2] + (LIGHT_CORE_ALPHA[1] - LIGHT_CORE_ALPHA[2]) * av
			local aaB = LIGHT_CORE_ALPHA[2] + (LIGHT_CORE_ALPHA[1] - LIGHT_CORE_ALPHA[2]) * v
			gl.Color(erA, egA, ebA, 0)
			gl.Vertex(ax - nx * wa, ay - ny * wa)
			gl.Color(crA, cgA, cbA, aaA)
			gl.Vertex(ax, ay)
			gl.Color(crB, cgB, cbB, aaB)
			gl.Vertex(bx, by)
			gl.Color(erB, egB, ebB, 0)
			gl.Vertex(bx - nx * wb, by - ny * wb)
			gl.Color(crA, cgA, cbA, aaA)
			gl.Vertex(ax, ay)
			gl.Color(erA, egA, ebA, 0)
			gl.Vertex(ax + nx * wa, ay + ny * wa)
			gl.Color(erB, egB, ebB, 0)
			gl.Vertex(bx + nx * wb, by + ny * wb)
			gl.Color(crB, cgB, cbB, aaB)
			gl.Vertex(bx, by)
		end
		ax, ay, av = bx, by, v
	end
end

local function DrawTravellingLight(self)
	local head = (os.clock() * LIGHT_SPEED) % BorderPerimeter(self, LIGHT_INSET)

	gl.BlendFunc(GL.SRC_ALPHA, GL.ONE)
	gl.BeginEnd(GL.QUADS, function()
		EmitLoop(self, head, SegmentsFor(self, LIGHT_INSET, LIGHT_STEP))
	end)
	gl.BlendFunc(GL.ONE, GL.ZERO)
	gl.Color(1, 1, 1, 1)
	self:InvalidateSelf()
end

local function ShowUrgentPopup(self)
	local holder = WG.Chobby.lobbyInterfaceHolder
	local config = ChobbyGlobal("Configuration")
	local Window = ChobbyGlobal("Window")
	local Label = ChobbyGlobal("Label")
	local Button = ChobbyGlobal("Button")
	local function Dismiss()
		self:ClosePopup()
	end

	local window = Window:New{
		name = "barplus_no_random_seed",
		classname = "main_window",
		caption = "",
		width = WINDOW_WIDTH,
		height = WINDOW_HEIGHT,
		resizable = false,
		draggable = false,
		parent = holder,
		objectOverrideFont = config:GetFont(3),
		DrawControlPostChildren = DrawTravellingLight,
	}

	Label:New{
		caption = NO_SECRET_HEADLINE,
		x = 24,
		y = 20,
		right = 24,
		height = 34,
		autosize = false,
		align = "center",
		valign = "top",
		objectOverrideFont = config:GetFont(2, "barplus_alert", {
			color = {1.0, 0.42, 0.42, 1},
			outline = true,
			outlineWidth = 2,
		}),
		parent = window,
	}

	Label:New{
		caption = NO_SECRET_BODY,
		x = 24,
		y = 62,
		right = 24,
		bottom = 84,
		autosize = false,
		align = "center",
		valign = "top",
		objectOverrideFont = config:GetFont(1),
		parent = window,
	}

	Button:New{
		caption = "I understand",
		x = (WINDOW_WIDTH - BUTTON_WIDTH - BUTTON_GUTTER) / 2,
		bottom = 1,
		width = BUTTON_WIDTH,
		height = BUTTON_HEIGHT,
		objectOverrideFont = config:GetFont(3),
		parent = window,
		classname = "negative_button",
		OnClick = {
			Dismiss,
		},
	}

	self:super("init", window, nil, Dismiss, nil, nil, true)
end

local function TryShow()
	if shown then
		return
	end
	if not (WG and WG.Chobby and WG.Chobby.lobbyInterfaceHolder) then
		return
	end

	local errorPopup = ChobbyGlobal("ErrorPopup")
	if not errorPopup then
		if not diagLogged then
			diagLogged = true
			Spring.Log(LOG_SECTION, LOG.NOTICE, "no-seed popup: waiting on Chobby.ErrorPopup")
		end
		return
	end

	local missing = {}
	for _, name in ipairs({"PriorityPopup", "Configuration", "Window", "Label", "Button"}) do
		if not ChobbyGlobal(name) then
			missing[#missing + 1] = name
		end
	end
	if #missing == 0 then
		if not urgentPopupClass then
			urgentPopupClass = ChobbyGlobal("PriorityPopup"):extends()
			urgentPopupClass.init = ShowUrgentPopup
		end
		local ok, err = pcall(function() urgentPopupClass() end)
		if ok then
			shown = true
			return
		end
		missing[#missing + 1] = "construction: " .. tostring(err)
	end
	if not diagLogged then
		diagLogged = true
		Spring.Log(LOG_SECTION, LOG.NOTICE, "no-seed popup: falling back to Chobby.ErrorPopup; "
			.. "unavailable: " .. table.concat(missing, ", "))
	end

	errorPopup(NO_SECRET_MESSAGE)
	shown = true
end

function NoSeedWarning.Report()
	Spring.Log(LOG_SECTION, LOG.ERROR, "NO SECURE RANDOM SOURCE: " .. NO_SECRET_BODY)
	pending = true
	TryShow()
end

function NoSeedWarning.Retry()
	if pending then
		TryShow()
	end
end
