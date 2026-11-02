import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons
import "Model.js" as Model
import "Registry.js" as Registry

// Keycast service: owns the key sources (Hyprland's key events, or the
// keycastd reader), the settings and the overlay.
// Lives for the shell's lifetime (manifest keepLoaded: true). The bar widget
// and panel only read these properties and call the set* functions.
Item {
  id: root

  // Injected by omarchy-shell.
  property var shell: null
  property var manifest: null

  readonly property string pluginId: "io.github.rewuschel.keycast"
  readonly property string pluginDir: Qt.resolvedUrl(".").toString().replace(/^file:\/\//, "")
  readonly property string configHome: Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")
  readonly property string configPath: configHome + "/omarchy/keycast.json"

  Commons.Translations { id: catalog; directory: Qt.resolvedUrl("i18n") }
  readonly property alias strings: catalog

  // ---- settings (persisted in keycast.json) ----
  property var settings: Model.normalize({})
  property bool configLoaded: false

  // ---- live state ----
  property bool connected: false
  property bool inputDenied: false
  property int deviceCount: 0
  property var held: ({})
  property var history: []
  property var stamps: []
  property int kps: 0
  property int apm: 0
  property int wheelFlash: 0
  property double now: Date.now()
  property int loneCandidate: 0
  // Set by the panel while it is open, so the overlay shows even with nothing
  // pressed and every settings change is visible as it is made.
  property bool previewing: false
  // Key tables of the system keymap, one per layout (bin/keycast-keymap).
  property var keyLayouts: []
  property var layoutCodes: []
  property int layoutIndex: 0
  property string keymapNames: ""
  readonly property var keyTable: settings.keymap === "auto" && keyLayouts.length
    ? keyLayouts[Math.min(layoutIndex, keyLayouts.length - 1)].keys : null
  readonly property string layoutCode: layoutCodes[layoutIndex] || "us"

  readonly property bool streamOn: settings.layout !== "gamer"
  readonly property bool gamerOn: settings.layout !== "stream"
  readonly property bool wantMouse: (streamOn && (settings.streamMouse || settings.streamScroll)) || (gamerOn && settings.gamerMouse)

  // ---- privacy ----
  // Nothing is drawn or kept while the session is locked, a polkit password
  // prompt is up, or a denylisted app (password managers by default) has focus.
  readonly property var lockService: shell && typeof shell.serviceFor === "function" ? shell.serviceFor("omarchy.lock") : null
  readonly property var polkitService: shell && typeof shell.serviceFor === "function" ? shell.serviceFor("omarchy.polkit") : null
  readonly property bool locked: !!(lockService && lockService.locked)
  readonly property bool polkitOpen: !!(polkitService && polkitService.dialogVisible)
  readonly property var activeToplevel: ToplevelManager.activeToplevel
  readonly property string activeApp: activeToplevel && activeToplevel.appId ? String(activeToplevel.appId).toLowerCase() : ""
  readonly property bool appHidden: activeApp !== "" && settings.denylist.indexOf(activeApp) >= 0
  readonly property bool suppressed: locked || polkitOpen || appHidden

  onSuppressedChanged: if (suppressed) clearStream()

  readonly property bool fromHyprland: settings.source === "hyprland"
  readonly property bool keysReady: fromHyprland ? hyprlandReady : connected
  // In Hyprland mode the reader only serves the mouse, so a denied reader
  // costs mouse features, not keys.
  readonly property bool keysDenied: !fromHyprland && inputDenied
  readonly property bool mouseDenied: fromHyprland && wantMouse && inputDenied

  readonly property string statusKey: !configLoaded ? "status.starting"
    : !settings.enabled ? "status.off"
    : keysDenied ? "status.denied"
    : fromHyprland && hyprlandError !== "" ? "status.nohyprland"
    : locked ? "status.locked"
    : polkitOpen ? "status.polkit"
    : appHidden ? "status.app"
    : !keysReady ? "status.starting"
    : "status.on"

  // ---- setters ----
  function update(patch) {
    var next = {}
    for (var k in settings) next[k] = settings[k]
    for (var p in patch) next[p] = patch[p]
    settings = Model.normalize(next)
    if (patch.linger !== undefined || patch.maxItems !== undefined || patch.filter !== undefined) clearStream()
    save()
  }
  function setEnabled(v) { update({ enabled: !!v }) }
  function toggle() { setEnabled(!settings.enabled) }
  function setLayout(v) { update({ layout: v }) }
  function cycleLayout() {
    var order = ["stream", "gamer", "both"]
    setLayout(order[(order.indexOf(settings.layout) + 1) % order.length])
  }
  function setDenylistText(text) { update({ denylist: Model.cleanDenylist(text) }) }
  function denylistText() { return settings.denylist.join(", ") }

  // ---- config file ----
  FileView {
    id: configFile
    path: root.configPath
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      root.settings = Model.parseConfig(text())
      root.configLoaded = true
    }
    onLoadFailed: {
      root.configLoaded = true
      root.save()
    }
  }

  function save() { if (configLoaded) saveDebounce.restart() }
  Timer {
    id: saveDebounce
    interval: 300
    onTriggered: configFile.setText(JSON.stringify(root.settings, null, 2) + "\n")
  }

  // ---- keys from Hyprland ----
  // Default source. A one-line Lua handler, registered through `hyprctl repl`,
  // re-emits each key as a socket2 custom event (custom>>keycast,<xkb
  // keycode>,<state>) that arrives here as Hyprland.rawEvent. It needs no
  // /dev/input access. It is removed whenever Keycast is off or paused (locked,
  // password prompt, denylisted app), so no key leaves the compositor then.
  // Hyprland >= 0.56 with the Lua config is required.
  readonly property bool hyprlandWanted: configLoaded && settings.enabled && fromHyprland && !suppressed
  property bool hyprlandReady: false
  property string hyprlandError: ""
  property var replQueue: []

  readonly property string registerLua: 'if KEYCAST_SUB then KEYCAST_SUB:remove() end '
    + 'KEYCAST_SUB = hl.on("input.keyboard.key", function(kc, t, state) '
    + 'hl.dispatch(hl.dsp.event("keycast," .. kc .. "," .. state)) end) return "keycast-ok"'
  readonly property string unregisterLua: 'if KEYCAST_SUB then KEYCAST_SUB:remove() KEYCAST_SUB = nil end return "keycast-ok"'

  onHyprlandWantedChanged: syncHyprland()

  function syncHyprland() {
    if (!hyprlandWanted) {
      hyprlandReady = false
      forgetHeld(true, false)
    }
    runRepl(hyprlandWanted ? registerLua : unregisterLua)
  }

  // One repl call at a time; only the newest pending one matters.
  function runRepl(lua) {
    if (repl.running) { replQueue = [lua]; return }
    repl.reply = ""
    repl.command = ["hyprctl", "repl", lua]
    repl.running = true
  }

  Process {
    id: repl
    property string reply: ""
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: repl.reply = text.slice(0, 400).trim()
    }
    onExited: function (code, status) {
      var ok = code === 0 && repl.reply.indexOf("keycast-ok") >= 0
      if (repl.command[2] === root.registerLua) {
        root.hyprlandReady = ok
        root.hyprlandError = ok ? "" : (repl.reply || ("hyprctl exited " + code))
      }
      if (root.replQueue.length) {
        var next = root.replQueue[0]
        root.replQueue = []
        root.runRepl(next)
      }
    }
  }

  // "keycast,<xkb keycode>,<state>"; xkb keycodes are evdev codes + 8.
  function onHyprlandKey(data) {
    var parts = String(data).split(",")
    if (parts.length !== 3 || parts[0] !== "keycast") return
    var kc = parseInt(parts[1], 10)
    if (!(kc > 8 && kc < 0x100 + 8) || (parts[2] !== "0" && parts[2] !== "1")) return
    onKey(kc - 8, parts[2] === "1")
  }

  // ---- reader process ----
  // keycastd reads /dev/input: every key in "Input devices" mode, and mouse
  // buttons and the wheel whenever a mouse feature is on. stdin stays open
  // for its lifetime; it exits when the pipe closes, so it can never outlive
  // the shell. Restarted when its arguments change.
  property bool restarting: false
  readonly property bool daemonWanted: configLoaded && settings.enabled && !restarting && (!fromHyprland || wantMouse)
  readonly property var readerArgs: (wantMouse ? ["--mouse"] : []).concat(fromHyprland ? ["--no-keyboards"] : [])
  onReaderArgsChanged: if (reader.running) { restarting = true; Qt.callLater(function () { root.restarting = false }) }

  Process {
    id: reader
    command: [root.pluginDir + "bin/keycastd"].concat(root.readerArgs)
    stdinEnabled: true
    running: root.daemonWanted
    stdout: SplitParser {
      splitMarker: "\n"
      onRead: function (line) { root.handleLine(line) }
    }
    onRunningChanged: {
      if (!running) {
        root.connected = false
        root.inputDenied = false
        root.forgetHeld(!root.fromHyprland, true)
        if (!root.fromHyprland) root.clearStream()
      }
    }
    onExited: function (code, status) {
      if (root.daemonWanted) restartTimer.restart()
    }
  }

  Timer {
    id: restartTimer
    interval: 2000
    onTriggered: if (root.daemonWanted && !reader.running) reader.running = true
  }

  function handleLine(line) {
    if (line.length > 4096) return
    var msg
    try { msg = JSON.parse(line) } catch (e) { return }
    if (!msg || typeof msg !== "object") return
    if (typeof msg.k === "number") { onKey(msg.k | 0, msg.v === 1); return }
    if (typeof msg.w === "number") { onWheel(msg.w > 0 ? 1 : -1); return }
    if (msg.hello) {
      connected = true
      deviceCount = Number(msg.devices) || 0
      inputDenied = deviceCount === 0
      forgetHeld(!fromHyprland, true)
    }
    if (msg.denied === true) inputDenied = true
    if (Array.isArray(msg.held)) reconcileHeld(msg.held)
  }

  // Neither source repeats keys, so every down is a real press. A down
  // for a key already in `held` still counts: the release before it may have
  // been missed, and ignoring the press then swallowed letters. Only the same
  // key reported by two interfaces of one keyboard within 25 ms is merged.
  property var lastDown: ({})
  readonly property int duplicateMs: 25

  function onKey(code, down) {
    if (code <= 0 || code > 0x2ff) return
    var t = Date.now()
    if (down) {
      if (held[code] && t - (lastDown[code] || 0) < duplicateMs) return
      lastDown[code] = t
    } else if (!held[code]) {
      return
    }
    var next = {}
    for (var c in held) next[c] = true
    if (down) next[code] = true
    else delete next[code]
    held = next

    if (suppressed) { loneCandidate = 0; return }

    if (down) {
      countPress(t)
      if (Model.isModifier(code, keyTable)) {
        loneCandidate = code
      } else {
        loneCandidate = 0
        if (streamOn) setHistory(Model.pressed(history, code, held, t, streamOpts()))
      }
    } else if (Model.isModifier(code, keyTable) && loneCandidate === code) {
      loneCandidate = 0
      if (streamOn) setHistory(Model.loneModifier(history, code, t, streamOpts()))
    }
  }

  // Drop keys the kernel no longer reports as down (a release that was
  // missed, e.g. on a device that went away). Never adds keys, and only
  // touches the codes the reader is reading.
  function reconcileHeld(kernelHeld) {
    var real = {}
    for (var i = 0; i < kernelHeld.length && i < 256; i++) real[kernelHeld[i]] = true
    var next = {}, changed = false
    for (var c in held) {
      if (real[c] || (fromHyprland && Number(c) < 0x110)) next[c] = true
      else changed = true
    }
    if (changed) held = next
  }

  // Forget held keyboard keys and/or mouse buttons, when their source stops.
  function forgetHeld(keyboard, mouse) {
    var next = {}, changed = false
    for (var c in held) {
      var button = Number(c) >= 0x110
      if (button ? mouse : keyboard) changed = true
      else next[c] = true
    }
    if (changed) held = next
  }

  function onWheel(direction) {
    if (suppressed) return
    wheelFlash = direction
    wheelTimer.restart()
    if (streamOn) setHistory(Model.wheel(history, direction, held, Date.now(), streamOpts()))
  }

  Timer { id: wheelTimer; interval: 140; onTriggered: root.wheelFlash = 0 }

  function streamOpts() {
    return {
      filter: settings.filter, linger: settings.linger, maxItems: settings.maxItems,
      mergeTyping: settings.mergeTyping, loneMods: settings.loneMods,
      streamMouse: settings.streamMouse, streamScroll: settings.streamScroll, keymap: keyTable
    }
  }

  function countPress(t) {
    if (!gamerOn || !settings.stats) return
    var next = Model.trimStamps(stamps, t).slice()
    next.push(t)
    if (next.length > 2000) next = next.slice(next.length - 2000)
    stamps = next
    var r = Model.rates(stamps, t)
    kps = r.kps
    apm = r.apm
  }

  // ---- stream model ----
  // A ListModel rather than a JS array, so entries that stay keep their
  // delegates (and their entrance animation does not replay on every key).
  ListModel { id: streamList }
  readonly property alias streamModel: streamList

  function setHistory(next) {
    if (next === history) return
    history = next
    now = Date.now()
    syncModel()
  }

  function clearStream() {
    history = []
    streamList.clear()
  }

  function syncModel() {
    var keep = {}
    for (var i = 0; i < history.length; i++) keep[history[i].id] = true
    while (streamList.count > 0 && !keep[streamList.get(0).eid]) streamList.remove(0)
    for (var j = 0; j < history.length; j++) {
      var e = history[j]
      var row = { eid: e.id, kind: e.kind, text: e.text, parts: e.parts.join("\u0001"), count: e.count, t: e.t }
      if (j < streamList.count) {
        var cur = streamList.get(j)
        if (cur.eid !== e.id) { rebuildModel(); return }
        // Not just t: keys delivered in one batch share a millisecond, and a
        // t-only check dropped every letter after the first from the screen.
        if (cur.t !== e.t || cur.text !== e.text || cur.count !== e.count) streamList.set(j, row)
      } else {
        streamList.append(row)
      }
    }
  }

  function rebuildModel() {
    streamList.clear()
    for (var i = 0; i < history.length; i++) {
      var e = history[i]
      streamList.append({ eid: e.id, kind: e.kind, text: e.text, parts: e.parts.join("\u0001"), count: e.count, t: e.t })
    }
  }

  // Ticks only while something is on screen that ages: stream entries
  // fading out, or the stats readout winding down.
  Timer {
    interval: 50
    repeat: true
    running: root.history.length > 0 || root.kps > 0 || root.apm > 0
    onTriggered: {
      var t = Date.now()
      root.now = t
      if (root.history.length) root.setHistory(Model.expire(root.history, t, root.settings.linger))
      if (root.stamps.length) {
        root.stamps = Model.trimStamps(root.stamps, t)
        var r = Model.rates(root.stamps, t)
        root.kps = r.kps
        root.apm = r.apm
      }
    }
  }

  // ---- keymap ----
  // Labels come from the real xkb keymap of the main keyboard, so every
  // layout, variant and option (caps:escape, compose:caps) shows as typed.
  Process {
    id: devices
    command: ["hyprctl", "-j", "devices"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (text.length > 1048576) return
        try {
          var kbs = JSON.parse(text).keyboards || []
          for (var i = 0; i < kbs.length; i++) {
            if (kbs[i].main) { root.useKeyboard(kbs[i]); return }
          }
        } catch (e) {}
      }
    }
  }

  function useKeyboard(kb) {
    var names = [kb.rules, kb.model, kb.layout, kb.variant, kb.options].map(function (v) { return String(v || "").slice(0, 512) })
    layoutCodes = names[2].split(",").map(function (c) { return c.trim() })
    layoutIndex = Math.max(0, Number(kb.active_layout_index) || 0)
    if (names.join("\n") === keymapNames) return
    keymapNames = names.join("\n")
    keymapReader.command = [root.pluginDir + "bin/keycast-keymap"].concat(names)
    keymapReader.running = true
  }

  Process {
    id: keymapReader
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (text.length > 4194304) return
        try {
          var layouts = JSON.parse(text).layouts
          if (Array.isArray(layouts)) root.keyLayouts = layouts
        } catch (e) {}
      }
    }
  }

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (!event) return
      if (event.name === "custom") {
        if (root.hyprlandWanted) root.onHyprlandKey(event.data)
      } else if (event.name === "activelayout") {
        var data = String(event.data || "")
        var name = data.slice(data.indexOf(",") + 1)
        for (var i = 0; i < root.keyLayouts.length; i++) {
          if (root.keyLayouts[i].name === name) { root.layoutIndex = i; return }
        }
        devices.running = true
      } else if (event.name === "configreloaded") {
        // A reload resets Hyprland's Lua state, handler included, and may
        // change the keymap.
        root.forgetHeld(root.fromHyprland, false)
        if (root.hyprlandWanted) root.syncHyprland()
        devices.running = true
      }
    }
  }

  Component.onCompleted: {
    Registry.service = root
    devices.running = true
    if (hyprlandWanted) syncHyprland()
  }

  // ---- IPC: omarchy-shell io.github.rewuschel.keycast <fn> ----
  ShellIpc {
    target: "io.github.rewuschel.keycast"

    function toggle(): string { root.toggle(); return root.settings.enabled ? "on" : "off" }
    function on(): string { root.setEnabled(true); return "on" }
    function off(): string { root.setEnabled(false); return "off" }
    function layout(value: string): string {
      if (value === "next") root.cycleLayout()
      else root.setLayout(value)
      return root.settings.layout
    }
    // Press and release a chord of evdev codes, e.g. "29+20" for Ctrl+T.
    // For demos and testing without a keyboard.
    function tap(codes: string): string {
      var list = String(codes).split("+").map(function (c) { return parseInt(c, 10) })
        .filter(function (c) { return c > 0 && c <= 0x2ff }).slice(0, 8)
      for (var i = 0; i < list.length; i++) root.onKey(list[i], true)
      for (var j = list.length - 1; j >= 0; j--) root.onKey(list[j], false)
      return String(list.length)
    }
    function status(): string {
      return JSON.stringify({
        enabled: root.settings.enabled, layout: root.settings.layout, source: root.settings.source,
        ready: root.keysReady, hyprlandError: root.hyprlandError, reader: reader.running,
        devices: root.deviceCount, denied: root.inputDenied, held: Object.keys(root.held),
        suppressed: root.suppressed, keymap: root.settings.keymap === "auto" ? root.layoutCode : "us"
      })
    }
  }

  // ---- overlay ----
  readonly property bool overlayContent: (streamOn && (streamList.count > 0 || previewing)) || gamerOn
  // The layer surface stays mapped while Keycast is on, even with nothing to
  // show: Hyprland animates every layer map/unmap (fadeLayersIn/Out), and a
  // key pressed just as the stream emptied, or the first key after idle, then
  // landed inside that animation and showed late, dim or not at all. An empty
  // stream only hides the card; the surface is transparent and click-through.
  readonly property bool overlayVisible: settings.enabled && !suppressed
  readonly property string focusedScreen: Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
  readonly property string vEdge: settings.position.indexOf("top") === 0 ? "top"
    : settings.position.indexOf("bottom") === 0 ? "bottom" : "middle"
  readonly property string hEdge: settings.position.indexOf("left") >= 0 ? "left"
    : settings.position.indexOf("right") >= 0 ? "right" : "center"

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: window

      required property var modelData

      screen: window.modelData
      visible: root.overlayVisible
      readonly property bool shows: root.settings.monitor === "all" || window.modelData.name === root.focusedScreen
      color: "transparent"
      WlrLayershell.namespace: "keycast"
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
      exclusionMode: ExclusionMode.Ignore
      // Click-through: a caption, not a UI.
      mask: Region {}

      // Fullscreen, transparent and click-through, with the card placed
      // inside. A surface sized to the card has to be resized by the
      // compositor on every key, and until it acks the new size the card is
      // drawn clipped or not at all.
      anchors {
        top: true
        bottom: true
        left: true
        right: true
      }

      readonly property real unit: Math.round(Style.space(40) * root.settings.scale)
      readonly property real pad: Math.round(unit * 0.32)

      Rectangle {
        id: card
        visible: root.overlayContent && window.shows
        readonly property real margin: root.settings.margin
        x: Math.round(root.hEdge === "left" ? margin
          : root.hEdge === "right" ? window.width - width - margin
          : (window.width - width) / 2)
        y: Math.round(root.vEdge === "top" ? margin
          : root.vEdge === "bottom" ? window.height - height - margin
          : (window.height - height) / 2)
        width: stack.implicitWidth + window.pad * 2
        height: stack.implicitHeight + window.pad * 2
        radius: Math.round(window.unit * 0.3)
        color: Util.alpha(Color.background, root.settings.opacity)
        border.width: root.settings.opacity > 0.05 ? 1 : 0
        border.color: Util.alpha(Color.foreground, 0.12 * root.settings.opacity)

        Column {
          id: stack
          x: window.pad
          y: window.pad
          spacing: Math.round(window.unit * 0.35)

          // The board sits on the edge side, the stream on the screen side.
          Loader {
            active: root.gamerOn && root.vEdge === "top"
            visible: active
            sourceComponent: gamerComponent
          }
          Loader {
            active: root.streamOn
            visible: active && item && item.implicitWidth > 0
            x: !item ? 0 : root.hEdge === "right" ? stack.width - item.implicitWidth
              : root.hEdge === "center" ? (stack.width - item.implicitWidth) / 2 : 0
            sourceComponent: streamComponent
          }
          Loader {
            active: root.gamerOn && root.vEdge !== "top"
            visible: active
            sourceComponent: gamerComponent
          }
        }
      }

      Component {
        id: streamComponent
        StreamView {
          service: root
          unit: window.unit
          vertical: root.vEdge === "middle" && root.hEdge !== "center"
          alignEnd: root.hEdge === "right"
          keyStyle: root.settings.keyStyle
          fontFamily: Style.font.family
        }
      }

      Component {
        id: gamerComponent
        GamerView {
          service: root
          unit: window.unit
          keyStyle: root.settings.keyStyle
          fontFamily: Style.font.family
        }
      }
    }
  }

  Component.onDestruction: {
    if (Registry.service === root) Registry.service = null
    if (saveDebounce.running) configFile.setText(JSON.stringify(root.settings, null, 2) + "\n")
    reader.running = false
    // Leave no key handler behind in the compositor when the shell goes away.
    Quickshell.execDetached(["hyprctl", "repl", root.unregisterLua])
  }
}
