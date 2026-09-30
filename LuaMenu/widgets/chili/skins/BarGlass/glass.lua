local Glass = {}

local cos, sin, pi = math.cos, math.sin, math.pi

local atan2 = math.atan2 or function(y, x) return math.atan(y, x) end

local SEG_STEPS = { {8, 8}, {14, 12}, {22, 16}, {34, 24}, {54, 32} }
local SEG_TOP = 48
local MAX_HALF_SEG = 48

local CIRCLE_SMOOTH = 0.5522847498
local DEFAULT_SMOOTH = 0.75
local MIN_SMOOTH, MAX_SMOOTH = CIRCLE_SMOOTH, 0.92

local outlineX, outlineY, innerX, innerY
do
	local n = (MAX_HALF_SEG + 2) * 4
	outlineX, outlineY, innerX, innerY = {}, {}, {}, {}
	for i = 1, n do
		outlineX[i], outlineY[i] = 0, 0
		innerX[i], innerY[i] = 0, 0
	end
end

local nverts = 0
local fanW, fanH = 0, 0

local gcr, gcg, gcb, gca, gdr, gdg, gdb, gda

local turnT = {}
local turnK, turnSeg = nil, nil

local smoothK = DEFAULT_SMOOTH

local function ClampRadius(w, h, r)
	if r < 0 then return 0 end
	local hw, hh = w * 0.5, h * 0.5
	if r > hw then r = hw end
	if r > hh then r = hh end
	return r
end

local function ArcSegment(seg)
	if seg < 1 then seg = 1 end
	if seg > MAX_HALF_SEG then seg = MAX_HALF_SEG end
	return seg
end

local function CornerSegment(r)
	if r <= 0 then return 1 end
	for i = 1, #SEG_STEPS do
		if r <= SEG_STEPS[i][1] then return SEG_STEPS[i][2] end
	end
	return SEG_TOP
end

local function SetSmooth(k)
	if k == nil then k = DEFAULT_SMOOTH end
	if k < MIN_SMOOTH then k = MIN_SMOOTH end
	if k > MAX_SMOOTH then k = MAX_SMOOTH end
	smoothK = k
	return k
end

local function TurnTable(seg)
	if turnSeg == seg and turnK == smoothK then return turnT end

	local a = 1 - smoothK
	local function angleAt(t)
		local mt = 1 - t
		local dx = 3 * (2 * mt * t * a + t * t * smoothK)
		local dy = 3 * (-mt * mt * smoothK - 2 * mt * t * a)
		return atan2(dy, dx) * 57.29577951308232 + 90
	end

	for i = 0, seg do
		local target = (i / seg) * 90
		local lo, hi = 0, 1
		for _ = 1, 26 do
			local mid = (lo + hi) * 0.5
			if angleAt(mid) < target then lo = mid else hi = mid end
		end
		turnT[i] = (lo + hi) * 0.5
	end
	turnT[0], turnT[seg] = 0, 1
	turnSeg, turnK = seg, smoothK
	return turnT
end

local function CornerInto(outX, outY, n, ox, oy, ax, ay, bx, by, r, seg)
	local t = TurnTable(seg)
	local kr = r * smoothK

	local sx, sy = ox + r * ax, oy + r * ay
	local ex, ey = ox + r * bx, oy + r * by
	local p1x, p1y = sx - kr * ax, sy - kr * ay
	local p2x, p2y = ex - kr * bx, ey - kr * by

	for i = 0, seg do
		local tt = t[i]
		local mt = 1 - tt
		local w0 = mt * mt * mt
		local w1 = 3 * mt * mt * tt
		local w2 = 3 * mt * tt * tt
		local w3 = tt * tt * tt
		n = n + 1
		outX[n] = w0 * sx + w1 * p1x + w2 * p2x + w3 * ex
		outY[n] = w0 * sy + w1 * p1y + w2 * p2y + w3 * ey
	end
	return n
end

local function BuildOutline(w, h, r, seg)
	local n = CornerInto(outlineX, outlineY, 0, 0, 0, 0, 1, 1, 0, r, seg)
	n = CornerInto(outlineX, outlineY, n, w, 0, -1, 0, 0, 1, r, seg)
	n = CornerInto(outlineX, outlineY, n, w, h, 0, -1, -1, 0, r, seg)
	n = CornerInto(outlineX, outlineY, n, 0, h, 1, 0, 0, -1, r, seg)

	nverts = n
	fanW, fanH = w, h
end

local function EmitFan()
	gl.Vertex(fanW * 0.5, fanH * 0.5, 0)
	for i = 1, nverts do
		gl.Vertex(outlineX[i], outlineY[i], 0)
	end
	gl.Vertex(outlineX[1], outlineY[1], 0)
end

local function EmitFanGrad()
	gl.Color(gcr + gdr * 0.5, gcg + gdg * 0.5, gcb + gdb * 0.5, gca + gda * 0.5)
	gl.Vertex(fanW * 0.5, fanH * 0.5, 0)
	for i = 1, nverts do
		local t = outlineY[i] / fanH
		gl.Color(gcr + gdr * t, gcg + gdg * t, gcb + gdb * t, gca + gda * t)
		gl.Vertex(outlineX[i], outlineY[i], 0)
	end
	local t = outlineY[1] / fanH
	gl.Color(gcr + gdr * t, gcg + gdg * t, gcb + gdb * t, gca + gda * t)
	gl.Vertex(outlineX[1], outlineY[1], 0)
end

function Glass.RRect(x, y, w, h, r, color, seg, smooth)
	if w <= 0 or h <= 0 then return end
	smooth = SetSmooth(smooth)
	r = ClampRadius(w, h, r)
	BuildOutline(w, h, r, ArcSegment(seg or CornerSegment(r)))
	gl.Color(color[1], color[2], color[3], color[4])
	gl.PushMatrix()
	gl.Translate(x, y, 0)
	gl.BeginEnd(GL.TRIANGLE_FAN, EmitFan)
	gl.PopMatrix()
end

function Glass.Ring(x, y, w, h, r, width, color, seg, smooth)
	if w <= 0 or h <= 0 then return end
	if width <= 0 then return end

	smooth = SetSmooth(smooth)
	r = ClampRadius(w, h, r)
	seg = ArcSegment(seg or CornerSegment(r))

	local iw, ih = w - width * 2, h - width * 2
	if iw <= 0 or ih <= 0 then
		return Glass.RRect(x, y, w, h, r, color, seg, smooth)
	end

	local ir = ClampRadius(iw, ih, r - width)
	if ir < 0 then ir = 0 end

	if 2 * ir >= iw or 2 * ir >= ih then
		return Glass.RRect(x, y, w, h, r, color, seg, smooth)
	end

	BuildOutline(w, h, r, seg)

	local n = CornerInto(innerX, innerY, 0, width, width, 0, 1, 1, 0, ir, seg)
	n = CornerInto(innerX, innerY, n, width + iw, width, -1, 0, 0, 1, ir, seg)
	n = CornerInto(innerX, innerY, n, width + iw, width + ih, 0, -1, -1, 0, ir, seg)
	n = CornerInto(innerX, innerY, n, width, width + ih, 1, 0, 0, -1, ir, seg)

	gl.Color(color[1], color[2], color[3], color[4])
	gl.PushMatrix()
	gl.Translate(x, y, 0)
	gl.BeginEnd(GL.TRIANGLE_STRIP, function()
		for i = 1, n do
			gl.Vertex(outlineX[i], outlineY[i], 0)
			gl.Vertex(innerX[i], innerY[i], 0)
		end
		gl.Vertex(outlineX[1], outlineY[1], 0)
		gl.Vertex(innerX[1], innerY[1], 0)
	end)
	gl.PopMatrix()
end

function Glass.Circle(cx, cy, radius, color, seg)
	if radius <= 0 then return end
	seg = ArcSegment(seg or MAX_HALF_SEG)
	local n = 0
	for i = 0, seg * 4 - 1 do
		local a = (i / (seg * 4)) * pi * 2
		n = n + 1
		outlineX[n] = radius * cos(a)
		outlineY[n] = radius * sin(a)
	end
	nverts = n
	fanW, fanH = 0, 0
	gl.Color(color[1], color[2], color[3], color[4])
	gl.PushMatrix()
	gl.Translate(cx, cy, 0)
	gl.BeginEnd(GL.TRIANGLE_FAN, EmitFan)
	gl.PopMatrix()
end

function Glass.VGradRRect(x, y, w, h, r, cTop, cBottom, steps, seg, smooth)
	if w <= 0 or h <= 0 then return end
	SetSmooth(smooth)
	r = ClampRadius(w, h, r)
	seg = ArcSegment(seg or CornerSegment(r))
	BuildOutline(w, h, r, seg)

	gcr, gcg, gcb, gca = cTop[1], cTop[2], cTop[3], cTop[4]
	gdr, gdg, gdb, gda = cBottom[1] - gcr, cBottom[2] - gcg,
		cBottom[3] - gcb, cBottom[4] - gca

	gl.PushMatrix()
	gl.Translate(x, y, 0)
	gl.BeginEnd(GL.TRIANGLE_FAN, EmitFanGrad)
	gl.PopMatrix()
end

function Glass.Surface(w, h, o)
	local r = o.radius or 8
	local rw = o.rimWidth or 1
	if rw < 0 then rw = 0 end
	local smooth = o.smooth

	r = ClampRadius(w, h, r)

	local iw, ih = w - rw * 2, h - rw * 2

	if iw <= 0 or ih <= 0 then
		local f = o.fill
		if not f and o.fillTop and o.fillBottom then
			f = Glass.Mix(o.fillTop, o.fillBottom, 0.5)
		end
		if f then
			Glass.RRect(0, 0, w, h, r, f, o.seg, smooth)
		end
		return
	end

	local fr = ClampRadius(iw, ih, r - rw)
	if fr < 0 then fr = 0 end

	if o.fillTop and o.fillBottom then
		Glass.VGradRRect(rw, rw, iw, ih, fr, o.fillTop, o.fillBottom, o.steps, o.seg, smooth)
	else
		local f = o.fill or o.fillTop
		if f then
			Glass.RRect(rw, rw, iw, ih, fr, f, o.seg, smooth)
		end
	end

	if o.rim then
		Glass.Ring(0, 0, w, h, r, rw, o.rim, o.seg, smooth)
	end
end

function Glass.ScaleRadius(w, h, scale, minR, maxR)
	scale = scale or 0.30
	if minR == nil then minR = 3 end
	if maxR == nil then maxR = 12 end
	local m = (w < h) and w or h
	local r = m * scale
	if r < minR then r = minR end
	if r > maxR then r = maxR end
	return r
end

Glass.DEFAULT_SMOOTH = DEFAULT_SMOOTH
Glass.CIRCLE_SMOOTH = CIRCLE_SMOOTH

function Glass.Mix(a, b, t)
	return {
		a[1] + (b[1] - a[1]) * t,
		a[2] + (b[2] - a[2]) * t,
		a[3] + (b[3] - a[3]) * t,
		a[4] + (b[4] - a[4]) * t,
	}
end

function Glass.WithAlpha(c, a)
	return {c[1], c[2], c[3], a}
end

return Glass
