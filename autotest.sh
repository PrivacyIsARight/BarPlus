#!/bin/bash

FAILING=

fail() {
  echo "$@"
  FAILING="y"
}

while read f; do
  diff /dev/null "$f" | tail -1 | grep -q '^\\ No newline at end of file' > /dev/null && fail "Warning: $f: No trailing newline";
  if grep -q $'[^ \t][ \t]\+$' "$f"; then
    # Everybody hates trailing whitespace after content
    fail "Warning: $f: Trailing whitespace after content";
  else
    # Most hate full line trailing whitespace; separated out to be disabled if desired
    # grep -q $'[ \t]$' "$f" && fail "Warning: $f: Full line trailing whitespace";
    :;
  fi
  file -i "$f" | cut -f2 -d: | grep -q -e 'us-ascii' -e 'utf-8' || fail "Warning: $f: Unusual file encoding";
  grep -q $'\r' "$f" && fail "Warning: $f: Carriage return characters detected";
done < <(git ls-files '*.lua' '*.tdf' '*.h' '*.glsl' '*.fs' '*.json' '*.txt' '*.css') 1>&2
if command -v python3 >/dev/null 2>&1; then
  computed=$(python3 - <<'PYEOF'
P      = 16777619
TWO16  = 65536
TWO32  = 4294967296

def bxor(a, b):
    r, t = 0, 1
    while (a > 0) or (b > 0):
        aa = a % 2
        bb = b % 2
        if aa != bb:
            r += t
        a = (a - aa) / 2
        b = (b - bb) / 2
        t = t * 2
    return r

def step(h, byte):
    h = (h - h % 256) + bxor(h % 256, byte)
    hi = h // TWO16
    lo = h % TWO16
    return (lo * P + (hi * P % TWO16) * TWO16) % TWO32

def fnv(data):
    h = 2166136261
    for b in data:
        h = step(h, b)
    h1 = h
    h = P
    for b in data:
        h = step(h, b)
    return "%08x%08x" % (h1, h)

import sys
data = open("LuaMenu/widgets/gui_settings_window.lua", "rb").read()
sys.stdout.write(fnv(data))
PYEOF
)
  pinned=$(sed -n 's/.*CLIENT_DIGEST[[:space:]]*=[[:space:]]*"\([0-9a-f]\{16\}\)".*/\1/p' LuaHandler/handler.lua | head -1)
  [ "x${computed}" == "x${pinned}" ] || fail "Warning: LuaMenu/widgets/gui_settings_window.lua: client digest mismatch (re-pin CLIENT_DIGEST in LuaHandler/handler.lua)"
fi

[ "x${FAILING}" == "x" ]
