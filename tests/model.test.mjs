// Run: node tests/model.test.mjs
import { readFileSync } from "node:fs"
import { fileURLToPath } from "node:url"
import vm from "node:vm"
import assert from "node:assert/strict"

const src = readFileSync(fileURLToPath(new URL("../Model.js", import.meta.url)), "utf8")
  .replace(/^\.pragma library\s*$/m, "")
const sandbox = { module: { exports: {} } }
vm.runInNewContext(src, sandbox)
const M = sandbox.module.exports

const opts = (extra = {}) => ({
  filter: "all", linger: 2000, maxItems: 5, mergeTyping: true, loneMods: true,
  streamMouse: true, streamScroll: true, keymap: "us", ...extra
})
const held = (...codes) => Object.fromEntries(codes.map(c => [c, true]))
let failures = 0
function test(name, fn) {
  try { fn(); console.log("ok   " + name) } catch (e) { failures++; console.log("FAIL " + name + "\n     " + e.message) }
}

test("typing merges into one text entry", () => {
  let h = []
  h = M.pressed(h, 35, held(35), 0, opts())   // h
  h = M.pressed(h, 23, held(23), 100, opts())  // i
  assert.equal(h.length, 1)
  assert.equal(h[0].kind, "text")
  assert.equal(h[0].text, "hi")
})

test("shift uppercases and maps symbols", () => {
  let h = M.pressed([], 30, held(42, 30), 0, opts())
  h = M.pressed(h, 2, held(42, 2), 10, opts())
  assert.equal(h[0].text, "A!")
})

// A slice of `bin/keycast-keymap "" "" de "" caps:escape` output.
const DE = {
  12: ["ß", "?", "\\", "ssharp"], 16: ["q", "Q", "@", "q"], 21: ["z", "Z", "←", "z"],
  44: ["y", "Y", "»", "y"], 30: ["a", "A", "æ", "a"], 13: ["´", "`", "¸", "dead_acute"],
  57: [" ", " ", " ", "space"], 58: ["", "", "", "Escape"], 29: ["", "", "", "Control_L"],
  42: ["", "", "", "Shift_L"], 100: ["", "", "", "ISO_Level3_Shift"], 1: ["", "", "", "Escape"]
}

test("system keymap labels follow the layout", () => {
  assert.equal(M.label(21, DE), "Z")
  assert.equal(M.label(44, DE), "Y")
  assert.equal(M.label(12, DE), "ß")
  assert.equal(M.label(58, DE), "Esc")   // caps:escape
  assert.equal(M.label(57, DE), "Space")
  assert.equal(M.label(103, DE), "↑")    // not in the table: built-in label
})

test("system keymap types shift and altgr levels", () => {
  const de = opts({ keymap: DE })
  let h = M.pressed([], 12, held(12), 0, de)
  h = M.pressed(h, 12, held(42, 12), 10, de)
  h = M.pressed(h, 16, held(100, 16), 20, de)
  h = M.pressed(h, 13, held(13), 30, de)
  assert.equal(h.length, 1)
  assert.equal(h[0].text, "ß?@´")
  assert.equal(M.modClass(100, DE), "altgr")
  assert.equal(M.loneModifier([], 100, 0, de)[0].text, "AltGr")
})

test("altgr is not a shortcut, ctrl is", () => {
  const de = opts({ keymap: DE })
  assert.equal(M.pressed([], 16, held(100, 16), 0, de)[0].kind, "text")
  assert.equal(M.pressed([], 16, held(29, 16), 0, de)[0].text, "Ctrl + Q")
})

test("chord shows modifiers in order and counts repeats", () => {
  let h = M.pressed([], 20, held(29, 42, 20), 0, opts())
  h = M.pressed(h, 20, held(29, 42, 20), 300, opts())
  assert.equal(h.length, 1)
  assert.deepEqual([...h[0].parts], ["Ctrl", "Shift", "T"])
  assert.equal(h[0].count, 2)
})

test("shortcuts filter drops plain typing but keeps chords", () => {
  let h = M.pressed([], 30, held(30), 0, opts({ filter: "shortcuts" }))
  assert.equal(h.length, 0)
  h = M.pressed(h, 46, held(29, 46), 10, opts({ filter: "shortcuts" }))
  assert.equal(h.length, 1)
  h = M.pressed(h, 28, held(28), 20, opts({ filter: "shortcuts" }))
  assert.equal(h.length, 2)
})

test("maxItems keeps the newest", () => {
  let h = []
  for (let i = 0; i < 8; i++) h = M.pressed(h, 59 + i, held(59 + i), i * 10, opts({ maxItems: 3 }))
  assert.equal(h.length, 3)
  assert.equal(h[2].parts[0], "F8")
})

test("expire drops entries past linger", () => {
  let h = M.pressed([], 1, held(1), 0, opts())
  assert.equal(M.expire(h, 1000, 2000).length, 1)
  assert.equal(M.expire(h, 2500, 2000).length, 0)
})

test("modifier alone is not an entry until released alone", () => {
  let h = M.pressed([], 125, held(125), 0, opts())
  assert.equal(h.length, 0)
  h = M.loneModifier(h, 125, 50, opts())
  assert.deepEqual([...h[0].parts], ["Super"])
  assert.equal(M.loneModifier([], 125, 50, opts({ loneMods: false })).length, 0)
})

test("mouse clicks and wheel respect their switches", () => {
  assert.equal(M.pressed([], 272, held(272), 0, opts()).length, 1)
  assert.equal(M.pressed([], 272, held(272), 0, opts({ streamMouse: false })).length, 0)
  assert.equal(M.wheel([], 1, {}, 0, opts({ streamScroll: false })).length, 0)
  const w = M.wheel(M.wheel([], 1, {}, 0, opts()), 1, {}, 10, opts())
  assert.equal(w[0].count, 2)
})

test("normalize rejects junk and keeps defaults", () => {
  const s = M.normalize({ layout: "<img src=x>", scale: "huge", opacity: 7, denylist: ["KeePassXC", "bad id!", "x".repeat(200)] })
  assert.equal(s.layout, "stream")
  assert.equal(s.scale, 1)
  assert.equal(s.opacity, 1)
  assert.deepEqual([...s.denylist], ["keepassxc"])
  assert.equal(M.parseConfig("{not json").enabled, true)
  assert.equal(M.parseConfig("x".repeat(70000)).layout, "stream")
})

test("markup-shaped labels never come from input", () => {
  // Labels only come from fixed tables; unknown codes render as "#<n>".
  assert.equal(M.label(999, "us"), "#999")
})

test("boards only reference known keys", () => {
  for (const p of ["compact", "wasd", "full"]) {
    for (const row of M.board(p)) for (const [code] of row) {
      if (code !== 0) assert.ok(!M.label(code, "us").startsWith("#"), p + " has unknown code " + code)
    }
  }
})

test("rates count kps and apm windows", () => {
  const r = M.rates([0, 30000, 59500, 59900], 60000)
  assert.equal(r.kps, 2)
  assert.equal(r.apm, 3)
  assert.equal(M.trimStamps([0, 1, 30000], 60001).length, 1)
})

if (failures) { console.log(failures + " failed"); process.exit(1) }
console.log("all passed")
