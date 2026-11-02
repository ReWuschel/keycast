.pragma library

// Pure helpers for Keycast: key labels, settings normalisation, the stream
// history reducer and the gamer board layouts. No QML types in here, so
// tests/model.test.mjs can run it under node.

// ---- key labels (evdev codes) ----

var LABELS_US = {
  1: "Esc", 2: "1", 3: "2", 4: "3", 5: "4", 6: "5", 7: "6", 8: "7", 9: "8", 10: "9", 11: "0",
  12: "-", 13: "=", 14: "⌫", 15: "Tab",
  16: "Q", 17: "W", 18: "E", 19: "R", 20: "T", 21: "Y", 22: "U", 23: "I", 24: "O", 25: "P",
  26: "[", 27: "]", 28: "Enter", 29: "Ctrl",
  30: "A", 31: "S", 32: "D", 33: "F", 34: "G", 35: "H", 36: "J", 37: "K", 38: "L",
  39: ";", 40: "'", 41: "`", 42: "Shift", 43: "\\",
  44: "Z", 45: "X", 46: "C", 47: "V", 48: "B", 49: "N", 50: "M",
  51: ",", 52: ".", 53: "/", 54: "Shift", 55: "Num *", 56: "Alt", 57: "Space", 58: "Caps",
  59: "F1", 60: "F2", 61: "F3", 62: "F4", 63: "F5", 64: "F6", 65: "F7", 66: "F8", 67: "F9", 68: "F10",
  69: "Num", 70: "Scroll", 71: "Num 7", 72: "Num 8", 73: "Num 9", 74: "Num -",
  75: "Num 4", 76: "Num 5", 77: "Num 6", 78: "Num +", 79: "Num 1", 80: "Num 2", 81: "Num 3",
  82: "Num 0", 83: "Num .", 86: "<", 87: "F11", 88: "F12",
  96: "Num Enter", 97: "Ctrl", 98: "Num /", 99: "Print", 100: "AltGr",
  102: "Home", 103: "↑", 104: "PgUp", 105: "←", 106: "→", 107: "End",
  108: "↓", 109: "PgDn", 110: "Ins", 111: "Del",
  113: "Mute", 114: "Vol -", 115: "Vol +", 119: "Pause",
  125: "Super", 126: "Super", 127: "Menu",
  163: "Next", 164: "Play", 165: "Prev", 166: "Stop",
  183: "F13", 184: "F14", 185: "F15", 186: "F16", 187: "F17", 188: "F18",
  189: "F19", 190: "F20", 191: "F21", 192: "F22", 193: "F23", 194: "F24",
  224: "Bright -", 225: "Bright +",
  272: "LMB", 273: "RMB", 274: "MMB", 275: "M4", 276: "M5", 277: "M6", 278: "M7", 279: "M8"
}

var SHIFTED_US = {
  2: "!", 3: "@", 4: "#", 5: "$", 6: "%", 7: "^", 8: "&", 9: "*", 10: "(", 11: ")",
  12: "_", 13: "+", 26: "{", 27: "}", 39: ":", 40: "\"", 41: "~", 43: "|",
  51: "<", 52: ">", 53: "?", 86: ">"
}

var CTRL = [29, 97]
var SHIFT = [42, 54]
var ALT = [56]
var ALTGR = [100]
var SUPER = [125, 126]
var MOUSE_FIRST = 272
var MOUSE_LAST = 279

// Typed characters on the built-in US table: digits, letters, punctuation and
// space. Everything else (arrows, F keys, Enter, ...) shows as its own keycap.
var PRINTABLE = {}
;[2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13,
  16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27,
  30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 43,
  44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 57, 86].forEach(function (c) { PRINTABLE[c] = true })

// ---- system keymap ----
//
// `km` is the key table of the active layout from bin/keycast-keymap:
// { "<evdev code>": [plain, shift, altgr, keysym name] }. Without one (null,
// or the "us" setting) the built-in US tables above are used.

// Keysym names of keys that type nothing, for remapped keys (caps:escape
// makes Caps an "Esc" cap) and layouts that move them.
var SYM_LABELS = {
  Escape: "Esc", Return: "Enter", KP_Enter: "Num Enter", BackSpace: "⌫", Tab: "Tab", ISO_Left_Tab: "Tab",
  Caps_Lock: "Caps", Multi_key: "Compose", Num_Lock: "Num", Scroll_Lock: "Scroll",
  Control_L: "Ctrl", Control_R: "Ctrl", Shift_L: "Shift", Shift_R: "Shift",
  Alt_L: "Alt", Alt_R: "Alt", Meta_L: "Alt", Meta_R: "Alt",
  Super_L: "Super", Super_R: "Super", Hyper_L: "Hyper", Hyper_R: "Hyper",
  ISO_Level3_Shift: "AltGr", Mode_switch: "AltGr", ISO_Level5_Shift: "Level5",
  Up: "↑", Down: "↓", Left: "←", Right: "→", Home: "Home", End: "End", Prior: "PgUp", Next: "PgDn",
  Insert: "Ins", Delete: "Del", Print: "Print", Pause: "Pause", Menu: "Menu",
  XF86AudioMute: "Mute", XF86AudioLowerVolume: "Vol -", XF86AudioRaiseVolume: "Vol +",
  XF86AudioPlay: "Play", XF86AudioNext: "Next", XF86AudioPrev: "Prev", XF86AudioStop: "Stop",
  XF86MonBrightnessDown: "Bright -", XF86MonBrightnessUp: "Bright +"
}

var SYM_MODS = {
  Control_L: "ctrl", Control_R: "ctrl", Shift_L: "shift", Shift_R: "shift",
  Alt_L: "alt", Alt_R: "alt", Meta_L: "alt", Meta_R: "alt",
  Super_L: "super", Super_R: "super", Hyper_L: "super", Hyper_R: "super",
  ISO_Level3_Shift: "altgr", Mode_switch: "altgr"
}

function keyOf(code, km) {
  if (!km || typeof km !== "object") return null
  var k = km[code]
  return Array.isArray(k) && k.length >= 4 ? k : null
}

// "ctrl", "shift", "alt", "altgr", "super", or "" for any other key.
function modClass(code, km) {
  var k = keyOf(code, km)
  if (k) return SYM_MODS[k[3]] || ""
  if (CTRL.indexOf(code) >= 0) return "ctrl"
  if (SHIFT.indexOf(code) >= 0) return "shift"
  if (ALT.indexOf(code) >= 0) return "alt"
  if (ALTGR.indexOf(code) >= 0) return "altgr"
  if (SUPER.indexOf(code) >= 0) return "super"
  return ""
}

function isModifier(code, km) {
  return modClass(code, km) !== ""
}

function isMouse(code) {
  return code >= MOUSE_FIRST && code <= MOUSE_LAST
}

function label(code, km) {
  var k = keyOf(code, km)
  if (k) {
    if (k[3] === "space") return "Space"
    if (k[0] !== "") {
      var up = k[0].toUpperCase()
      return up.length === 1 ? up : k[0]
    }
    if (SYM_LABELS[k[3]] !== undefined) return SYM_LABELS[k[3]]
  }
  var l = LABELS_US[code]
  if (l !== undefined) return l
  if (k) return k[3].replace(/^XF86/, "")
  return "#" + code
}

// The text a key types with the held modifiers, or "" when it types nothing
// (then it shows as a keycap of its own).
function typedChar(code, mods, km) {
  if (code === 57) return "␣"
  var k = keyOf(code, km)
  if (k) {
    var ch = (mods.altgr && k[2]) || (mods.shift && k[1]) || k[0]
    return ch === " " ? "␣" : ch
  }
  if (!PRINTABLE[code]) return ""
  var base = label(code, null)
  if (!mods.shift) return base.length === 1 ? base.toLowerCase() : base
  if (SHIFTED_US[code] !== undefined) return SHIFTED_US[code]
  return base.toUpperCase()
}

// ---- settings ----

var POSITIONS = ["top-left", "top", "top-right", "left", "center", "right", "bottom-left", "bottom", "bottom-right"]
var LAYOUTS = ["stream", "gamer", "both"]
var PRESETS = ["compact", "wasd", "full"]
var KEY_STYLES = ["3d", "flat", "outline"]
var FILTERS = ["all", "shortcuts"]
var KEYMAPS = ["auto", "us"]
var SOURCES = ["hyprland", "devices"]
var MONITORS = ["focused", "all"]

var DEFAULTS = {
  enabled: true,
  source: "hyprland",
  layout: "stream",
  position: "bottom",
  monitor: "focused",
  scale: 1.0,
  opacity: 0.85,
  margin: 48,
  keyStyle: "3d",
  keymap: "auto",
  filter: "all",
  linger: 2000,
  maxItems: 5,
  mergeTyping: true,
  loneMods: true,
  streamMouse: true,
  streamScroll: true,
  preset: "wasd",
  gamerMouse: true,
  stats: true,
  denylist: ["org.keepassxc.keepassxc", "keepassxc", "1password", "bitwarden", "pinentry-qt", "gcr-prompter"]
}

function pick(list, value, fallback) {
  return list.indexOf(value) >= 0 ? value : fallback
}

function clamp(value, lo, hi, fallback) {
  var n = Number(value)
  if (!isFinite(n)) return fallback
  return Math.max(lo, Math.min(hi, n))
}

function bool(value, fallback) {
  return typeof value === "boolean" ? value : fallback
}

function cleanDenylist(value) {
  var list = Array.isArray(value) ? value : String(value || "").split(/[\s,]+/)
  var out = []
  for (var i = 0; i < list.length && out.length < 64; i++) {
    var id = String(list[i] || "").trim().toLowerCase()
    if (id === "" || id.length > 128 || out.indexOf(id) >= 0) continue
    if (!/^[a-z0-9._-]+$/.test(id)) continue
    out.push(id)
  }
  return out
}

// Anything missing or malformed takes its default, so a hand-edited or
// truncated config can never switch on something the user did not choose.
function normalize(raw) {
  var d = DEFAULTS
  var s = raw && typeof raw === "object" && !Array.isArray(raw) ? raw : {}
  return {
    enabled: bool(s.enabled, d.enabled),
    source: pick(SOURCES, s.source, d.source),
    layout: pick(LAYOUTS, s.layout, d.layout),
    position: pick(POSITIONS, s.position, d.position),
    monitor: pick(MONITORS, s.monitor, d.monitor),
    scale: Math.round(clamp(s.scale, 0.6, 2.5, d.scale) * 20) / 20,
    opacity: Math.round(clamp(s.opacity, 0, 1, d.opacity) * 100) / 100,
    margin: Math.round(clamp(s.margin, 0, 400, d.margin)),
    keyStyle: pick(KEY_STYLES, s.keyStyle, d.keyStyle),
    keymap: pick(KEYMAPS, s.keymap, d.keymap),
    filter: pick(FILTERS, s.filter, d.filter),
    linger: Math.round(clamp(s.linger, 500, 10000, d.linger)),
    maxItems: Math.round(clamp(s.maxItems, 1, 10, d.maxItems)),
    mergeTyping: bool(s.mergeTyping, d.mergeTyping),
    loneMods: bool(s.loneMods, d.loneMods),
    streamMouse: bool(s.streamMouse, d.streamMouse),
    streamScroll: bool(s.streamScroll, d.streamScroll),
    preset: pick(PRESETS, s.preset, d.preset),
    gamerMouse: bool(s.gamerMouse, d.gamerMouse),
    stats: bool(s.stats, d.stats),
    denylist: s.denylist === undefined ? d.denylist.slice() : cleanDenylist(s.denylist)
  }
}

function parseConfig(text) {
  if (typeof text !== "string" || text.length > 65536) return normalize({})
  try { return normalize(JSON.parse(text)) } catch (e) { return normalize({}) }
}

// ---- held keys ----

function modState(held, km) {
  var mods = { ctrl: false, shift: false, alt: false, altgr: false, superKey: false }
  for (var c in held) {
    var m = modClass(Number(c), km)
    if (m === "super") mods.superKey = true
    else if (m !== "") mods[m] = true
  }
  return mods
}

function modParts(mods, includeShift) {
  var parts = []
  if (mods.superKey) parts.push("Super")
  if (mods.ctrl) parts.push("Ctrl")
  if (mods.alt) parts.push("Alt")
  if (mods.altgr) parts.push("AltGr")
  if (includeShift && mods.shift) parts.push("Shift")
  return parts
}

// ---- stream history ----
//
// Each entry is { id, kind, parts, text, count, t }:
//   kind "text"  - merged run of typed characters, shown as one wide cap
//   kind "combo" - one keycap per part, joined with "+"
// `t` is the last time the entry changed; entries expire `linger` ms after it.

var MAX_TEXT = 32
var nextId = 1

function entry(kind, parts, text, now) {
  return { id: nextId++, kind: kind, parts: parts, text: text, count: 1, t: now }
}

function sameParts(a, b) {
  if (!a || !b || a.length !== b.length) return false
  for (var i = 0; i < a.length; i++) if (a[i] !== b[i]) return false
  return true
}

function withEntry(history, item, opts) {
  var next = history.concat([item])
  return next.length > opts.maxItems ? next.slice(next.length - opts.maxItems) : next
}

function bumpOrPush(history, kind, parts, now, opts) {
  var last = history.length ? history[history.length - 1] : null
  if (last && last.kind === kind && sameParts(last.parts, parts) && now - last.t < opts.linger) {
    var bumped = history.slice(0, -1)
    bumped.push({ id: last.id, kind: last.kind, parts: last.parts, text: last.text, count: last.count + 1, t: now })
    return bumped
  }
  return withEntry(history, entry(kind, parts, parts.join(" + "), now), opts)
}

// A key or button went down. `held` already includes it. Returns the new
// history (or the same array when nothing is shown).
function pressed(history, code, held, now, opts) {
  var km = opts.keymap
  if (isModifier(code, km)) return history
  var mods = modState(held, km)
  var chord = mods.ctrl || mods.alt || mods.superKey

  if (isMouse(code)) {
    if (!opts.streamMouse) return history
    return bumpOrPush(history, "combo", modParts(mods, true).concat([label(code, km)]), now, opts)
  }

  var ch = chord ? "" : typedChar(code, mods, km)
  if (ch !== "") {
    if (opts.filter === "shortcuts") return history
    var last = history.length ? history[history.length - 1] : null
    if (opts.mergeTyping && last && last.kind === "text" && now - last.t < opts.linger) {
      var text = last.text + ch
      if (text.length > MAX_TEXT) text = "…" + text.slice(text.length - MAX_TEXT + 1)
      var merged = history.slice(0, -1)
      merged.push({ id: last.id, kind: "text", parts: [], text: text, count: 1, t: now })
      return merged
    }
    return withEntry(history, entry("text", [], ch, now), opts)
  }

  // Shift alone with a non-text key (Shift+Tab, Shift+arrows) is a chord too.
  return bumpOrPush(history, "combo", modParts(mods, true).concat([label(code, km)]), now, opts)
}

// A modifier tapped and released with nothing pressed in between.
function loneModifier(history, code, now, opts) {
  if (!opts.loneMods) return history
  var names = { ctrl: "Ctrl", shift: "Shift", alt: "Alt", altgr: "AltGr", "super": "Super" }
  var name = names[modClass(code, opts.keymap)]
  if (!name) return history
  return bumpOrPush(history, "combo", [name], now, opts)
}

function wheel(history, direction, held, now, opts) {
  if (!opts.streamScroll) return history
  var parts = modParts(modState(held, opts.keymap), true).concat([direction > 0 ? "Scroll ↑" : "Scroll ↓"])
  return bumpOrPush(history, "combo", parts, now, opts)
}

function expire(history, now, linger) {
  var kept = history.filter(function (e) { return now - e.t < linger })
  return kept.length === history.length ? history : kept
}

// ---- gamer boards ----
//
// A board is a list of rows; a row is a list of [code, widthUnits] cells.
// code 0 is a gap of that width.

var BOARDS = {
  compact: [
    [[0, 1.25], [16, 1], [17, 1], [18, 1], [19, 1]],
    [[42, 1.25], [30, 1], [31, 1], [32, 1], [33, 1]],
    [[29, 1.25], [0, 0.25], [57, 3.75]]
  ],
  wasd: [
    [[1, 1], [2, 1], [3, 1], [4, 1], [5, 1], [6, 1]],
    [[15, 1.5], [16, 1], [17, 1], [18, 1], [19, 1], [20, 1]],
    [[58, 1.75], [30, 1], [31, 1], [32, 1], [33, 1], [34, 1]],
    [[42, 2.25], [44, 1], [45, 1], [46, 1], [47, 1], [48, 1]],
    [[29, 1.5], [125, 1.25], [56, 1.25], [57, 3.25]]
  ],
  full: [
    [[1, 1], [0, 0.5], [59, 1], [60, 1], [61, 1], [62, 1], [0, 0.5], [63, 1], [64, 1], [65, 1], [66, 1],
      [0, 0.5], [67, 1], [68, 1], [87, 1], [88, 1], [0, 0.25], [99, 1], [70, 1], [119, 1]],
    [[41, 1], [2, 1], [3, 1], [4, 1], [5, 1], [6, 1], [7, 1], [8, 1], [9, 1], [10, 1], [11, 1], [12, 1], [13, 1], [14, 2],
      [0, 0.25], [110, 1], [102, 1], [104, 1]],
    [[15, 1.5], [16, 1], [17, 1], [18, 1], [19, 1], [20, 1], [21, 1], [22, 1], [23, 1], [24, 1], [25, 1], [26, 1], [27, 1], [43, 1.5],
      [0, 0.25], [111, 1], [107, 1], [109, 1]],
    [[58, 1.75], [30, 1], [31, 1], [32, 1], [33, 1], [34, 1], [35, 1], [36, 1], [37, 1], [38, 1], [39, 1], [40, 1], [28, 2.25]],
    [[42, 2.25], [44, 1], [45, 1], [46, 1], [47, 1], [48, 1], [49, 1], [50, 1], [51, 1], [52, 1], [53, 1], [54, 2.75],
      [0, 1.25], [103, 1]],
    [[29, 1.25], [125, 1.25], [56, 1.25], [57, 6.25], [100, 1.25], [126, 1.25], [127, 1.25], [97, 1.25],
      [0, 0.25], [105, 1], [108, 1], [106, 1]]
  ]
}

function board(preset) {
  return BOARDS[pick(PRESETS, preset, "wasd")]
}

// Keys per second over the last second, and actions per minute over the last
// minute, from a list of press timestamps (oldest first).
function rates(stamps, now) {
  var kps = 0, apm = 0
  for (var i = stamps.length - 1; i >= 0; i--) {
    var age = now - stamps[i]
    if (age >= 60000) break
    apm++
    if (age < 1000) kps++
  }
  return { kps: kps, apm: apm }
}

function trimStamps(stamps, now) {
  var i = 0
  while (i < stamps.length && now - stamps[i] >= 60000) i++
  return i === 0 ? stamps : stamps.slice(i)
}

if (typeof module !== "undefined") {
  module.exports = {
    label: label, typedChar: typedChar, modClass: modClass,
    normalize: normalize, parseConfig: parseConfig, cleanDenylist: cleanDenylist,
    pressed: pressed, loneModifier: loneModifier, wheel: wheel, expire: expire,
    board: board, rates: rates, trimStamps: trimStamps, isModifier: isModifier, isMouse: isMouse,
    DEFAULTS: DEFAULTS, POSITIONS: POSITIONS
  }
}
