local TWO32 = 4294967296

local function bxor(a, b)
	a = a % TWO32
	b = b % TWO32
	local res, bitval = 0, 1
	while a > 0 or b > 0 do
		local abit = a % 2
		local bbit = b % 2
		if abit ~= bbit then
			res = res + bitval
		end
		a = (a - abit) / 2
		b = (b - bbit) / 2
		bitval = bitval * 2
	end
	return res % TWO32
end

local function band(a, b)
	a = a % TWO32
	b = b % TWO32
	local res, bitval = 0, 1
	while a > 0 or b > 0 do
		local abit = a % 2
		local bbit = b % 2
		if abit == 1 and bbit == 1 then
			res = res + bitval
		end
		a = (a - abit) / 2
		b = (b - bbit) / 2
		bitval = bitval * 2
	end
	return res % TWO32
end

local function rshift32(x, by)
	return math.floor((x % TWO32) / (2 ^ by))
end

local function rotr32(x, by)
	x = x % TWO32
	return rshift32(x, by) + (x % (2 ^ by)) * (2 ^ (32 - by))
end

local SHA256_K = {
	0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1,
	0x923f82a4, 0xab1c5ed5, 0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
	0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174, 0xe49b69c1, 0xefbe4786,
	0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
	0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147,
	0x06ca6351, 0x14292967, 0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
	0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85, 0xa2bfe8a1, 0xa81a664b,
	0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
	0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a,
	0x5b9cca4f, 0x682e6ff3, 0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
	0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
}

local HEX_DIGITS = "0123456789abcdef"
local function Hex32(n)
	n = n % TWO32
	local out = {}
	for i = 8, 1, -1 do
		local digit = n % 16
		out[i] = string.sub(HEX_DIGITS, digit + 1, digit + 1)
		n = math.floor(n / 16)
	end
	return table.concat(out)
end

local function Sha256Hex(msg)
	local h1, h2, h3, h4 = 0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a
	local h5, h6, h7, h8 = 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19

	local msgLen = #msg
	local padLen = (56 - (msgLen + 1) % 64) % 64
	local bitLen = msgLen * 8
	local lenByte = {}
	for i = 8, 1, -1 do
		lenByte[i] = bitLen % 256
		bitLen = math.floor(bitLen / 256)
	end
	msg = msg .. string.char(0x80) .. string.rep("\0", padLen)
		.. string.char(lenByte[1], lenByte[2], lenByte[3], lenByte[4])
		.. string.char(lenByte[5], lenByte[6], lenByte[7], lenByte[8])

	local w = {}
	for chunk = 1, #msg, 64 do
		local base = chunk - 1
		for i = 1, 16 do
			local p = base + (i - 1) * 4
			local b1, b2, b3, b4 = string.byte(msg, p + 1, p + 4)
			w[i] = b1 * 16777216 + b2 * 65536 + b3 * 256 + b4
		end
		for i = 17, 64 do
			local x, y = w[i - 15], w[i - 2]
			local s0 = bxor(bxor(rotr32(x, 7), rotr32(x, 18)), rshift32(x, 3))
			local s1 = bxor(bxor(rotr32(y, 17), rotr32(y, 19)), rshift32(y, 10))
			w[i] = (w[i - 16] + s0 + w[i - 7] + s1) % TWO32
		end

		local a, b, c, d = h1, h2, h3, h4
		local e, f, g, h = h5, h6, h7, h8
		for i = 1, 64 do
			local S1 = bxor(bxor(rotr32(e, 6), rotr32(e, 11)), rotr32(e, 25))
			local ch = bxor(band(e, f), band(4294967295 - e, g))
			local temp1 = (h + S1 + ch + SHA256_K[i] + w[i]) % TWO32
			local S0 = bxor(bxor(rotr32(a, 2), rotr32(a, 13)), rotr32(a, 22))
			local maj = bxor(bxor(band(a, b), band(a, c)), band(b, c))
			local temp2 = (S0 + maj) % TWO32

			h = g
			g = f
			f = e
			e = (d + temp1) % TWO32
			d = c
			c = b
			b = a
			a = (temp1 + temp2) % TWO32
		end

		h1 = (h1 + a) % TWO32
		h2 = (h2 + b) % TWO32
		h3 = (h3 + c) % TWO32
		h4 = (h4 + d) % TWO32
		h5 = (h5 + e) % TWO32
		h6 = (h6 + f) % TWO32
		h7 = (h7 + g) % TWO32
		h8 = (h8 + h) % TWO32
	end

	return Hex32(h1) .. Hex32(h2) .. Hex32(h3) .. Hex32(h4)
		.. Hex32(h5) .. Hex32(h6) .. Hex32(h7) .. Hex32(h8)
end

local SEED_HEX_LENGTH = 64

local MISS = {
	NO_CONNECTOR = "no_connector",
	NO_METHOD = "no_method",
	ERROR = "error",
	NO_SEED = "no_seed",
	MALFORMED = "malformed",
}

local function GetConnector()
	local conn = WG and WG.Connector
	if type(conn) ~= "table" then
		return nil
	end
	return conn
end

local function ReadLauncherSeedHex()
	local connector = GetConnector()
	if not connector then
		return nil, MISS.NO_CONNECTOR
	end
	if type(connector.GetRandomSeed) ~= "function" then
		return nil, MISS.NO_METHOD
	end
	local ok, seed = pcall(connector.GetRandomSeed, connector)
	if not ok then
		return nil, MISS.ERROR, tostring(seed)
	end
	if seed == nil or seed == false or seed == "" then
		return nil, MISS.NO_SEED
	end
	if type(seed) ~= "string" or #seed ~= SEED_HEX_LENGTH or not seed:match("^%x+$") then
		local len = type(seed) == "string" and #seed or "n/a"
		return nil, MISS.MALFORMED, string.format("type=%s,len=%s", type(seed), tostring(len))
	end
	return seed
end

local function LogMiss(reason, err)
	local msg = string.format("lobby agent hash: no launcher seed (%s)",
		tostring(reason))
	if err then
		local serr = tostring(err):gsub("%s+", " "):match("^%s*(.-)%s*$")
		msg = msg .. " | err=" .. serr
	end
	Spring.Log("liblobby", LOG.NOTICE, msg)
end

local function Guard(label, f, ...)
	local ok, res = pcall(f, ...)
	if not ok then
		Spring.Log("liblobby", LOG.ERROR, "lobby agent hash: " .. label .. " failed: " .. tostring(res))
	end
	return ok, res
end

local NO_SECRET = "0000000000000000 0000000000000000"

local agentSeed
local agentCounter = 0
local agentSeedWarned = false

local function EnsureAgentSeed()
	if agentSeed then
		return agentSeed
	end
	local hex, reason, err = ReadLauncherSeedHex()
	if hex then
		agentSeed = hex
		Spring.Log("liblobby", LOG.NOTICE, "lobby agent hash seeded from launcher")
		return agentSeed
	end
	if not agentSeedWarned then
		agentSeedWarned = true
		Guard("warning report", NoSeedWarning.Report)
		Guard("LogMiss", LogMiss, reason, err)
	end
	return NO_SECRET
end

function RetryNoSeedWarning()
	NoSeedWarning.Retry()
end

function NewLobbyAgentHash()
	local seed = EnsureAgentSeed()
	if seed == NO_SECRET then
		return seed
	end
	agentCounter = agentCounter + 1
	local digest = Sha256Hex(seed .. "|" .. agentCounter .. "|" .. tostring(os.time()))
	return digest:sub(1, 16) .. " " .. digest:sub(17, 32)
end
