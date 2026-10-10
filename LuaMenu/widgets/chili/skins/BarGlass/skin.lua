local Glass = VFS.Include(SKINDIR .. "glass.lua")

local skin = {
  info = {
    name    = "BarGlass",
    version = "1.0",
    author  = "vexalous",
    depend  = {"Armada Blues"},
  },
}

local C = {}

C.accent        = {0.247, 0.550, 0.850, 1.00}
C.accentGlow    = {0.340, 0.663, 0.850, 0.55}

C.windowTop     = {0.072, 0.085, 0.115, 0.759}
C.windowBottom  = {0.034, 0.041, 0.058, 0.805}
C.rim           = {0.850, 0.850, 0.850, 0.161}
C.rimLight      = {0.850, 0.850, 0.850, 0.345}

C.panel         = {0.060, 0.070, 0.094, 0.667}
C.panelHover    = {0.085, 0.102, 0.136, 0.713}

C.field         = {0.017, 0.022, 0.032, 0.667}
C.fieldFocus    = {0.026, 0.034, 0.049, 0.713}

C.progressTrack = {0.000, 0.000, 0.000, 0.518}
C.thumb         = {0.136, 0.170, 0.221, 0.920}

C.pressTint     = {0.017, 0.020, 0.029, 1.00}
C.hoverTint     = {0.187, 0.281, 0.400, 1.00}

C.text          = {0.850, 0.850, 0.850, 0.92}
C.textDim       = {0.850, 0.850, 0.850, 0.55}
C.danger        = {0.850, 0.323, 0.357, 1.00}
C.success       = {0.357, 0.765, 0.442, 1.00}
C.warn          = {0.850, 0.663, 0.272, 1.00}

C.smooth        = Glass.DEFAULT_SMOOTH

C.radius        = 8
C.radiusScale   = 0.42
C.radiusMin     = 5
C.radiusMax     = 24
C.windowScale   = 0.055
C.windowMin     = 10
C.windowMax     = 28

C.seg           = nil

local function ControlRadius(w, h)
  return Glass.ScaleRadius(w, h, C.radiusScale, C.radiusMin, C.radiusMax)
end

local function WindowRadius(w, h)
  return Glass.ScaleRadius(w, h, C.windowScale, C.windowMin, C.windowMax)
end

local function ControlFont(obj)
	local state = obj.state
	if (not state) or state.enabled or not obj.hasDisabledFont then
		return obj.font
	end
	return obj.disabledFont
end

local function IsEnabled(obj)
	local state = obj.state
	return (not state) or state.enabled
end

local function IsHovered(obj)
	local state = obj.state
	return state and (state.hovered or state.focused)
end

local function Lift(c, t)
	return {c[1] + (1 - c[1]) * t, c[2] + (1 - c[2]) * t, c[3] + (1 - c[3]) * t, c[4]}
end

local function ReactiveFill(base, obj)
	if not IsEnabled(obj) then
		return Glass.WithAlpha(base, base[4] * 0.40)
	end
	local state = obj.state
	if state.pressed then
		return Glass.Mix(base, C.pressTint, 0.55)
	end
	if state.hovered or state.focused then
		return Glass.Mix(base, C.hoverTint, 0.32)
	end
	if state.selected then
		return Glass.Mix(base, C.accent, 0.30)
	end
	return base
end

local function ReactiveRim(obj, resting)
	if not IsEnabled(obj) then
		return Glass.WithAlpha(resting, resting[4] * 0.35)
	end
	local state = obj.state
	if state.pressed then
		return Glass.WithAlpha(resting, resting[4] * 0.5)
	end
	if state.selected then
		return Glass.WithAlpha(C.accentGlow, C.accentGlow[4])
	end
	if state.hovered then
		return Glass.WithAlpha(resting, resting[4] * 2.0)
	end
	return resting
end

local function PrintCaption(obj, x, y, hAlign, vAlign)
	if (not obj.caption) or obj.caption == "" or obj.noFont then
		return
	end
	local font = ControlFont(obj)
	if not font then
		return
	end
	font:Print(obj.caption, x, y, hAlign or "center", vAlign)
end

local function PrintButtonCaption(obj, w, h)
	if (not obj.caption) or obj.caption == "" or obj.noFont then
		return
	end
	local font = ControlFont(obj)
	if not font then
		return
	end
	local y = math.floor(h * 0.5 - font.size * 0.35) + (obj.captionAlign or 0)
	font:Print(obj.caption, w * 0.5 + (obj.captionHorAlign or 0), y, "center", "linecenter")
end

local function DrawGlassWindow(obj, w, h, opts)
	opts = opts or {}
	Glass.Surface(w, h, {
	  radius    = opts.radius or WindowRadius(w, h),
	  rimWidth  = opts.rimWidth or 1,
	  seg       = C.seg,
	  smooth    = C.smooth,
	  rim       = ReactiveRim(obj, C.rim),
	  fillTop   = opts.fillTop or C.windowTop,
	  fillBottom= opts.fillBottom or C.windowBottom,
	})
	PrintCaption(obj, w * 0.5, opts.captionY or 9, "center")
end

local function DrawGlassButton(obj, base, radius, rimWidth)
	local w, h = obj.width, obj.height
	Glass.Surface(w, h, {
	  radius   = radius or ControlRadius(w, h),
	  rimWidth = rimWidth or 1,
	  seg      = C.seg,
	  smooth   = C.smooth,
	  rim      = ReactiveRim(obj, C.rim),
	  fillTop    = Lift(ReactiveFill(base or obj.backgroundColor or C.panel, obj), 0.12),
	  fillBottom = ReactiveFill(base or obj.backgroundColor or C.panel, obj),
	})
	PrintButtonCaption(obj, w, h)
end

local function DrawGlassPanel(obj)
	local w, h = obj.width, obj.height
	local base = ReactiveFill(obj.backgroundColor or C.panel, obj)
	Glass.Surface(w, h, {
	  radius    = obj.radius or ControlRadius(w, h),
	  rimWidth  = 1,
	  seg       = C.seg,
	  smooth    = C.smooth,
	  rim       = C.rim,
	  fillTop   = Lift(base, 0.08),
	  fillBottom= base,
	})
end

local function DrawGlassCheckbox(obj)
	local size = obj.boxsize or 13
	local state = obj.state
	local checked = state and state.checked
	local left = (obj.boxalign == "left")
	local x = left and 0 or (obj.width - size)
	local y = math.floor(obj.height * 0.5 - size * 0.5)

	gl.PushMatrix()
	gl.Translate(x, y, 0)
	Glass.Surface(size, size, {
		radius = ControlRadius(size, size), rimWidth = 1, seg = C.seg,
		smooth = C.smooth,
		rim  = ReactiveRim(obj, C.rim),
		fill = checked and Glass.Mix(C.accent, {0, 0, 0, 0}, 0.15) or C.field,
	})
	gl.PopMatrix()

	if obj.caption and not obj.noFont then
		local font = ControlFont(obj)
		local tx = left and (size + 6) or 0
		local tw = left and (obj.width - size - 6) or (obj.width - size)
		if font then
			font:DrawInBox(obj.caption, tx, 0, tw, obj.height, "left", "center")
		end
	end
end

local function DrawGlassProgressbar(obj)
	local w, h = obj.width, obj.height
	local span = (obj.max or 1) - (obj.min or 0)
	local percent = span ~= 0 and ((obj.value or 0) - (obj.min or 0)) / span or 0
	if percent < 0 then percent = 0 end
	if percent > 1 then percent = 1 end

	Glass.RRect(0, math.floor(h * 0.5 - 2), w, 4, 2, C.progressTrack, 3, Glass.CIRCLE_SMOOTH)
	if percent > 0 then
		Glass.RRect(0, math.floor(h * 0.5 - 2), w * percent, 4, 2,
			Glass.WithAlpha(obj.color or C.accent, 1), 3, Glass.CIRCLE_SMOOTH)
	end
end

local function DrawGlassTrackbar(obj)
	local w, h = obj.width, obj.height
	local midY = math.floor(h * 0.5)
	local percent = obj._GetPercent and obj:_GetPercent() or 0

	Glass.RRect(0, midY - 2, w, 4, 2, C.progressTrack, 3, Glass.CIRCLE_SMOOTH)
	if percent > 0 then
		Glass.RRect(0, midY - 2, w * percent, 4, 2, Glass.WithAlpha(C.accent, 1), 3, Glass.CIRCLE_SMOOTH)
	end

	Glass.Circle(w * percent, midY, 7, ReactiveFill(C.thumb, obj), 6)
end

local function DrawGlassLine(obj)
	local w, h = obj.width, obj.height
	local style = obj.style or "h"
	local color = obj.borderColor or C.rim

	gl.Color(color[1], color[2], color[3], color[4])
	if style:find("^v") then
		gl.Rect(math.floor(w * 0.5) - 1, 0, math.floor(w * 0.5) + 1, h)
	else
		gl.Rect(0, math.floor(h * 0.5) - 1, w, math.floor(h * 0.5) + 1)
	end
end

skin.general = {
  focusColor  = C.accent,
  borderColor = C.rim,

  font = {
    color        = C.text,
    outlineColor = {0.0, 0.0, 0.0, 0.75},
    outline      = false,
    shadow       = true,
  },
}

skin.control = skin.general

skin.window = {
  DrawControl = function(obj)
    DrawGlassWindow(obj, obj.width, obj.height)
  end,
  captionColor = C.textDim,
  backgroundColor = C.windowBottom,
}

skin.main_window = {
  DrawControl = function(obj)
    DrawGlassWindow(obj, obj.width, obj.height)
  end,
  captionColor = C.textDim,
  backgroundColor = C.windowBottom,
}

skin.main_window_small = {
  DrawControl = function(obj)
    DrawGlassWindow(obj, obj.width, obj.height)
  end,
  captionColor = C.textDim,
  backgroundColor = C.windowBottom,
}

skin.PartyWindow = {
  clone = "main_window",
}

skin.overlay_window = {
  DrawControl = function(obj)
    DrawGlassWindow(obj, obj.width, obj.height)
  end,
  captionColor = C.textDim,
  backgroundColor = C.windowBottom,
}

skin.combobox_window = {
  clone = "main_window_small",
}

skin.startbox_window = {
  DrawControl = function(obj)
    DrawGlassWindow(obj, obj.width, obj.height)
  end,
  captionColor = C.text,
  backgroundColor = {0.06, 0.07, 0.10, 0.345},
}

skin.panel = {
  DrawControl = DrawGlassPanel,
  backgroundColor = C.panel,
}

skin.panel_light = {
  DrawControl = function(obj)
    local w, h = obj.width, obj.height
    Glass.Surface(w, h, {
      radius = ControlRadius(w, h), rimWidth = 1, seg = C.seg, smooth = C.smooth,
      rim = C.rimLight,
      fill = C.panelHover,
    })
  end,
  backgroundColor = C.panelHover,
}

skin.overlay_panel = {
  DrawControl = function(obj)
    local w, h = obj.width, obj.height
    Glass.Surface(w, h, {
      radius = ControlRadius(w, h), rimWidth = 1, seg = C.seg, smooth = C.smooth,
      rim = C.rim,
      fill = {0.04, 0.05, 0.07, 0.759},
    })
  end,
  backgroundColor = {0.04, 0.05, 0.07, 0.759},
}

skin.party_wrapper = {
  DrawControl = function(obj)
    local w, h = obj.width, obj.height
    Glass.Surface(w, h, {
      radius = ControlRadius(w, h), rimWidth = 1, seg = C.seg, smooth = C.smooth,
      rim = C.rim,
      fill = C.panel,
    })
  end,
  backgroundColor = C.panel,
}

skin.button = {
  DrawControl = function(obj)
    DrawGlassButton(obj, {0.105, 0.122, 0.158, 0.69})
  end,
  backgroundColor = {0.105, 0.122, 0.158, 0.69},
  focusColor = C.accentGlow,
}

skin.button_small = {
  DrawControl = function(obj)
    DrawGlassButton(obj, {0.105, 0.122, 0.158, 0.633})
  end,
  backgroundColor = {0.105, 0.122, 0.158, 0.633},
  focusColor = C.accentGlow,
}

skin.button_bulb = {
  DrawControl = function(obj)
    DrawGlassButton(obj, {0.125, 0.145, 0.185, 0.748})
  end,
  backgroundColor = {0.125, 0.145, 0.185, 0.748},
  focusColor = C.accentGlow,
}

skin.button_slimbulb = {
  DrawControl = function(obj)
    DrawGlassButton(obj, {0.100, 0.118, 0.150, 0.69})
  end,
  backgroundColor = {0.100, 0.118, 0.150, 0.69},
  focusColor = C.accentGlow,
}

skin.action_button = {
  DrawControl = function(obj)
    DrawGlassButton(obj, {0.130, 0.290, 0.470, 0.713})
  end,
  backgroundColor = {0.130, 0.290, 0.470, 0.713},
  focusColor = C.accentGlow,
}

skin.option_button = {
  DrawControl = function(obj)
    DrawGlassButton(obj, {0.115, 0.135, 0.175, 0.69})
  end,
  backgroundColor = {0.115, 0.135, 0.175, 0.69},
  focusColor = C.accentGlow,
}

skin.playing_button = {
  clone = "option_button",
}

skin.negative_button = {
  DrawControl = function(obj)
    DrawGlassButton(obj, {0.400, 0.110, 0.140, 0.713})
  end,
  backgroundColor = {0.400, 0.110, 0.140, 0.713},
  focusColor = {1.0, 0.45, 0.45, 0.60},
}

skin.positive_button = {
  DrawControl = function(obj)
    DrawGlassButton(obj, {0.110, 0.320, 0.160, 0.713})
  end,
  backgroundColor = {0.110, 0.320, 0.160, 0.713},
  focusColor = {0.40, 0.90, 0.55, 0.60},
}

skin.link_button = {
  DrawControl = function(obj)
    DrawGlassButton(obj, {0.085, 0.135, 0.185, 0.633})
  end,
  backgroundColor = {0.085, 0.135, 0.185, 0.633},
  focusColor = C.accentGlow,
}

skin.button_simple = {
  DrawControl = function(obj)
    DrawGlassButton(obj, {0.090, 0.105, 0.135, 0.633})
  end,
  backgroundColor = {0.090, 0.105, 0.135, 0.633},
  focusColor = C.accentGlow,
}

skin.battle_default_button = {
  DrawControl = function(obj)
    DrawGlassButton(obj, {0.090, 0.130, 0.190, 0.69})
  end,
  backgroundColor = {0.090, 0.130, 0.190, 0.69},
  focusColor = C.accentGlow,
}

skin.ready_button = {
  DrawControl = function(obj)
    DrawGlassButton(obj, obj.backgroundColor)
  end,
  backgroundColor = {0.090, 0.300, 0.170, 0.69},
  focusColor = {0.40, 0.90, 0.55, 0.60},
  StyleReady = function(self)
    self.backgroundColor = {0.090, 0.300, 0.170, 0.69}
    self.focusColor = {0.40, 0.90, 0.55, 0.60}
    self:Invalidate()
  end,
  StyleUnready = function(self)
    self.backgroundColor = {0.300, 0.250, 0.110, 0.69}
    self.focusColor = {1.00, 0.85, 0.35, 0.60}
    self:Invalidate()
  end,
  StyleOff = function(self)
    self.backgroundColor = {0.100, 0.110, 0.130, 0.633}
    self.focusColor = C.accentGlow
    self:Invalidate()
  end,
}

skin.combobox_item = {
  DrawControl = function(obj)
    DrawGlassButton(obj, {0.070, 0.082, 0.110, 0.759})
  end,
  backgroundColor = {0.070, 0.082, 0.110, 0.759},
  focusColor = C.accentGlow,
}

skin.editbox = {
  DrawControl = DrawEditBox,
  backgroundColor = C.field,
  focusColor = C.accent,
  borderColor = C.rim,
  cursorColor = C.accent,
  hintFont = {color = C.textDim},
}

skin.emojitextbox = {
  clone = "editbox",
}

skin.textbox = {
  DrawControl = DrawEditBox,
  TileImageBK = ":cl:empty.png",
  TileImageFG = ":cl:empty.png",
  backgroundColor = {0, 0, 0, 0},
  borderColor = {0, 0, 0, 0},
  focusColor = {0, 0, 0, 0},
  hintFont = {color = C.textDim},
}

skin.combobox = {
  DrawControl = function(obj)
    local w, h = obj.width, obj.height
    local base = ReactiveFill({0.105, 0.122, 0.158, 0.713}, obj)
    Glass.Surface(w, h, {
      radius = ControlRadius(w, h), rimWidth = 1, seg = C.seg, smooth = C.smooth,
      rim = ReactiveRim(obj, C.rim),
      fillTop = Lift(base, 0.12), fillBottom = base,
    })
    PrintCaption(obj, 10, math.floor(h * 0.5), "left", "center")

    local caret = (obj.state and obj.state.pressed) and C.accent or C.textDim
    local cw = math.min(obj.padding[3] - 6, 9)
    local cx = w - obj.padding[3] + 3
    local cy = math.floor(h * 0.5)
    Glass.RRect(cx, cy - 0.75, cw, 1.5, 0.75, Glass.WithAlpha(caret, 0.85), 2, Glass.CIRCLE_SMOOTH)
  end,
  backgroundColor = {0.105, 0.122, 0.158, 0.713},
  focusColor = C.accentGlow,
}

skin.checkbox = {
  DrawControl = DrawGlassCheckbox,
  boxsize = 14,
}

skin.favourite_check = {
  DrawControl = function(obj)
    local s = obj.boxsize or 24
    local on = obj.state and obj.state.checked
    Glass.Circle(s * 0.5, s * 0.5, s * 0.42,
      on and C.accent or Glass.WithAlpha(C.rim, C.rim[4]), 8)
  end,
  boxsize = 24,
}

skin.tabbar = {}

skin.tabbaritem = {
  DrawControl = function(obj)
    local w, h = obj.width, obj.height
    local state = obj.state
    local selected = state and state.selected

    local base = selected and {0.150, 0.230, 0.330, 0.782}
      or {0.070, 0.082, 0.110, 0.633}
    base = ReactiveFill(base, obj)

    Glass.Surface(w, h, {
      radius = ControlRadius(w, h), rimWidth = 1, seg = C.seg, smooth = C.smooth,
      rim = selected and C.accentGlow or ReactiveRim(obj, C.rim),
      fillTop = Lift(base, 0.10), fillBottom = base,
    })
    if obj.caption and obj.caption ~= "" and not obj.noFont then
      local font = ControlFont(obj)
      local cx, cy, cw, ch = obj.clientArea[1], obj.clientArea[2], obj.clientArea[3], obj.clientArea[4]
      if font then
        font:DrawInBox(obj.caption, cx, cy, cw, ch, "center", "center")
      end
    end
  end,
  backgroundColor = {0.070, 0.082, 0.110, 0.633},
  focusColor = C.accentGlow,
  borderColor = {0, 0, 0, 0},
}

skin.line = {
  DrawControl = DrawGlassLine,
  borderColor = C.rim,
}

skin.lineStandOut = {
  DrawControl = DrawGlassLine,
  borderColor = C.danger,
}

skin.line_solid = {
  DrawControl = DrawGlassLine,
  borderColor = C.rim,
}

skin.progressbar = {
  DrawControl = DrawGlassProgressbar,
  color = C.accent,
  backgroundColor = {0, 0, 0, 0.518},
}

skin.trackbar = {
  DrawControl = DrawGlassTrackbar,
}

skin.scrollpanel = {
  BackgroundTileImage = ":cl:empty.png",
  backgroundColor = {0, 0, 0, 0},
  DrawControl = DrawScrollPanel,
  DrawControlPostChildren = function() end,
}

skin.scrollpanel_borderless = {
  BackgroundTileImage = ":cl:empty.png",
  backgroundColor = {0, 0, 0, 0},
  DrawControl = DrawScrollPanel,
  DrawControlPostChildren = function() end,
}

skin.combobox_scrollpanel = {
  clone = "scrollpanel_borderless",
}

skin.imagelistview = {
  colorBK          = {1, 1, 1, 0.069},
  colorBK_selected = Glass.WithAlpha(C.accent, 0.518),
}

skin.treeview = {
  treeColor = C.textDim,
}

return skin
